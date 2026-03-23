{pkgs, ...}: {
  home.packages = with pkgs; [
    vulkan-tools
    vulkan-validation-layers
    vulkan-headers
  ];
}
