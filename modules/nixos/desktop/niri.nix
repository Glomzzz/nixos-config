{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.niri.nixosModules.niri
  ];

  # niri-flake's NixOS module replaces the nixpkgs `programs.niri` module and
  # pulls in the pieces a bare compositor does not provide on its own:
  # xdg portals (screencast), polkit, gnome-keyring, dconf and the session
  # entry for the session. It also injects `programs.niri.settings` into
  # Home Manager automatically, so the user-level config lives under
  # modules/home/desktop/niri.
  # nixpkgs' own niri (26.04) is used rather than niri-flake's niri-stable:
  # the flake pins niri 25.08, which still builds against libdisplay-info_0_2,
  # and that package was removed from nixpkgs. nixpkgs' niri ships
  # niri-session, the systemd user units, the wayland session entry and the
  # portal config, which is everything this module wires up.
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  # X11 applications (Steam, Discord, JetBrains) talk to niri through
  # xwayland-satellite. niri spawns it on demand when it is on PATH.
  environment.systemPackages = [
    pkgs.xwayland-satellite
  ];

  # Screen sharing and file pickers need a portal implementation that is not
  # tied to a full desktop environment.
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Access" = ["gtk"];
      "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
      "org.freedesktop.impl.portal.Notification" = ["gtk"];
      "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
    };
  };
}
