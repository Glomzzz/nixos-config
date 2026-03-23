{pkgs, ...}: {
  programs.xwayland.enable = true;

  environment.sessionVariables = {
    # Tell the Vulkan loader to use NVIDIA's ICD file directly.
    VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
  };

  environment.systemPackages = with pkgs; [
    virtualglLib
    egl-wayland
    libglvnd
    vulkan-loader
    mesa
  ];
}
