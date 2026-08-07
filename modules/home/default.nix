{
  username,
  lib,
  ...
}: {
  imports = [
    ./desktop
    ./programs
    ./shell
    ../services/home
  ];

  home = {
    inherit username;
    homeDirectory = lib.mkForce "/home/${username}";
  };

  programs.home-manager.enable = true;
}
