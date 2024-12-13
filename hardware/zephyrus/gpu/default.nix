 
{pkgs,...}:
{
  imports = [
    ./nvidia.nix
    # ./intel
  ];

  # boot.blacklistedKernelModules = [ "nouveau" "nvidia_drm" "nvidia_modeset" "nvidia"  ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
      vulkan-headers
      # vulkan-cts
      mesa
      qt5Full
    ];
  };
}

