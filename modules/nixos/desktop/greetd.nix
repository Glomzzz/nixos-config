{pkgs, ...}: {
  # greetd + tuigreet replaces SDDM. tuigreet is a TTY greeter, so there is no
  # second Wayland session running just to draw a login box.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = builtins.concatStringsSep " " [
          "${pkgs.tuigreet}/bin/tuigreet"
          "--time"
          "--remember"
          "--remember-user-session"
          "--asterisks"
          "--theme 'border=magenta;text=cyan;prompt=green;time=cyan;action=blue;button=yellow;container=black;input=red'"
          "--cmd ${pkgs.niri}/bin/niri-session"
        ];
      };
    };
  };

  # tuigreet draws on the VT; without this its output fights kernel messages.
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  # Unlock the login keyring with the password typed into tuigreet. Without
  # this, gnome-keyring stays locked and every app that stores secrets prompts
  # again after login.
  security.pam.services.greetd.enableGnomeKeyring = true;
}
