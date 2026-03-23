{pkgs, ...}: {
  home.packages = with pkgs; [
    clamtk
  ];
}
