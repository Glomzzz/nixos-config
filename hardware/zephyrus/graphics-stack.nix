{pkgs, ...}: {
  programs.xwayland.enable = true;

  environment.systemPackages = with pkgs; [
    virtualglLib
    egl-wayland
    libglvnd
  ];
}
