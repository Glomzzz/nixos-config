{pkgs, ...}: {
  # Thunar is the native drag source and FileManager1 provider used by Firefox
  # and other desktop applications.  Dirvish remains the interactive file
  # manager launched by the user.
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  services = {
    gvfs.enable = true;
    tumbler.enable = true;
  };
}
