{pkgs, ...}: let
  # swaylock-effects is a drop-in fork that still installs its binary as
  # `swaylock`. Plain swaylock does NOT understand screenshots/effect-blur/
  # clock/indicator, so those settings below require this package.
  swaylockPackage = pkgs.swaylock-effects;
  locker = "${swaylockPackage}/bin/swaylock";
in {
  # swaylock draws the lock screen; swayidle decides when to show it.
  # The NixOS-side PAM service for swaylock is provided by niri-flake's module
  # (security.pam.services.swaylock), without which unlocking always fails.
  programs.swaylock = {
    enable = true;
    package = swaylockPackage;

    settings = {
      # Blur the current screen rather than showing a flat colour, so it is
      # obvious which machine is locked.
      screenshots = true;
      effect-blur = "9x5";
      effect-vignette = "0.5:0.5";
      clock = true;
      timestr = "%H:%M";
      datestr = "%Y-%m-%d";

      indicator = true;
      indicator-radius = 110;
      indicator-thickness = 8;

      # Catppuccin Mocha.
      ring-color = "89b4fa";
      ring-ver-color = "a6e3a1";
      ring-wrong-color = "f38ba8";
      key-hl-color = "f5c2e7";
      bs-hl-color = "fab387";
      inside-color = "1e1e2e";
      inside-ver-color = "1e1e2e";
      inside-wrong-color = "1e1e2e";
      text-color = "cdd6f4";
      text-ver-color = "cdd6f4";
      text-wrong-color = "f38ba8";
      separator-color = "00000000";
      line-color = "00000000";
      line-ver-color = "00000000";
      line-wrong-color = "00000000";

      fade-in = 0.2;
      ignore-empty-password = true;
    };
  };

  services.swayidle = {
    enable = true;

    timeouts = [
      # Dim first as a warning, restore on activity.
      {
        timeout = 240;
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10%";
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      {
        timeout = 300;
        command = "${locker} -f";
      }
      # Blank the outputs after locking rather than suspending outright; the
      # laptop lid handles suspend.
      {
        timeout = 360;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
      }
    ];

    events = {
      # Lock before the machine sleeps, so resuming never shows the desktop.
      before-sleep = "${locker} -f";
      # `loginctl lock-session` (bound to the lid switch in settings.nix)
      # arrives here.
      lock = "${locker} -f";
    };
  };
}
