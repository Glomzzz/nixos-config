{
  username,
  lib,
  ...
}: {
  imports = [
    ./desktop
    ./dotfiles
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
