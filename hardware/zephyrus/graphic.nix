{pkgs, ...} : {
    environment.systemPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
      vulkan-headers
      vulkan-cts
      mesa
      qt5Full
  ];
}