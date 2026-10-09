{
  config,
  lib,
  pkgs,
  ...
}: let
  niri = lib.getExe config.programs.niri.package;
  greeterSession = pkgs.writeShellScript "regreet-session" ''
    ${lib.getExe config.services.displayManager.regreet.package}
    ${niri} msg action quit --skip-confirmation
  '';
  greeterConfig = pkgs.writeText "greeter-niri.kdl" ''
    // Run a separate compositor as greeter, never the user's niri-session.
    spawn-at-startup "${greeterSession}"
    hotkey-overlay { skip-at-startup; }
    input {
      keyboard {
        xkb {
          layout ${builtins.toJSON config.services.xserver.xkb.layout}
          options ${builtins.toJSON config.services.xserver.xkb.options}
        }
      }
      touchpad {
        tap
        natural-scroll
      }
    }
    output "eDP-1" {
      scale 1.5
      focus-at-startup
    }
    cursor {
      xcursor-theme "breeze_cursors"
      xcursor-size 24
    }
    // Niri retains its built-in Ctrl+Alt+Fn VT switching for recovery.
  '';
in {
  # ReGreet owns tty1; other VTs remain password-based recovery consoles.
  # greetd's PAM stack includes login, which passes the password to Keyring.
  security.pam.services.login = {
    allowNullPassword = lib.mkForce false;
    enableGnomeKeyring = true;
  };

  services = {
    getty.autologinUser = null;
    displayManager = {
      autoLogin.enable = false;
      regreet = {
        enable = true;
        theme = {
          name = "adw-gtk3-dark";
          package = pkgs.adw-gtk3;
        };
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        cursorTheme = {
          name = "breeze_cursors";
          package = pkgs.kdePackages.breeze;
        };
        font = {
          name = "Noto Sans CJK SC";
          package = pkgs.noto-fonts-cjk-sans;
          size = 11;
        };
        settings = {
          background = {
            path = "${../../../assets/e022.jpg}";
            fit = "Cover";
          };
          GTK.application_prefer_dark_theme = true;
          appearance.greeting_msg = "Welcome back, Glom";
          widget.clock = {
            format = "%A, %d %B  ·  %H:%M";
            resolution = "1s";
          };
        };
        extraCss = ./regreet.css;
      };
    };

    # Use the same NVIDIA-compatible compositor as the desktop rather than the
    # module's default Cage. Do not use --session: greeter's private environment
    # must not be imported into the user's systemd or D-Bus session.
    greetd.settings.default_session.command = "${pkgs.dbus}/bin/dbus-run-session ${niri} --config ${greeterConfig}";
  };
  environment.etc."greetd/niri.kdl".source = greeterConfig;

  # No Fish tty1 auto-launch: ReGreet starts the packaged Niri desktop entry,
  # whose niri-session script handles the login shell and session lifecycle.
  # See docs/authentication.md for keyring setup and safe activation.
}
