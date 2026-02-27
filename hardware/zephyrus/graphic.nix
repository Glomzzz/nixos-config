{pkgs, ...}: {
  programs.xwayland.enable = true;
  environment.sessionVariables = {
    # 告诉Vulkan加载器只使用NVIDIA的ICD文件，避免它去尝试NVK (nouveau)
    VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
  };

  environment.systemPackages = with pkgs; [
    virtualglLib
    egl-wayland
    libglvnd # GL Vendor-Neutral Dispatch库，确保正确的GL分派
    vulkan-loader
    vulkan-tools
    vulkan-validation-layers
    vulkan-headers
    # vulkan-cts
    mesa
  ];
}
