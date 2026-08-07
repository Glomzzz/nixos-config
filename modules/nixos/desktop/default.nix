{
  username,
  pkgs,
  ...
}: {
  services = {
    xserver.enable = true;

    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };

      autoLogin = {
        enable = true;
        user = username;
      };
    };

    desktopManager.plasma6.enable = true;
  };

  environment.plasma6.excludePackages = [
    pkgs.kdePackages.kate
  ];
}
