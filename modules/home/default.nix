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

    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
