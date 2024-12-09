 
{pkgs,...}:
{
  imports = [
    ./nvidia.nix
    ./intel.nix
  ];

  
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
      vulkan-headers
      vulkan-cts
      mesa
      qt5Full
    ];
  };
}

