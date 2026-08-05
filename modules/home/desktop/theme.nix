{pkgs, ...}: {
  gtk = {
    enable = true;
    colorScheme = "dark";
  };

  home.pointerCursor = {
    enable = true;
    package = pkgs.kdePackages.breeze;
    name = "breeze_cursors";
    size = 24;
    gtk.enable = true;
  };
}
