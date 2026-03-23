{pkgs, ...}: {
  home.packages = with pkgs; [
    lsfg-vk
    lsfg-vk-ui
  ];
}
