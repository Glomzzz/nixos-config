{
  username,
  lib,
  ...
}: {
  imports = [
    ./programs
    ./shell
    ./desktop
    ../services/home
  ];

  home = {
    inherit username;
    homeDirectory = lib.mkForce "/home/${username}";

    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
}
