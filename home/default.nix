{username,lib, ...}: {
  imports = [
    ./fcitx5
    ./programs
    ./shell
    ./plasma
    ./nixvim
  ];
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    inherit username;
    homeDirectory = lib.mkForce "/home/${username}";

    stateVersion = "25.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

}
