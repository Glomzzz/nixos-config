{
  pkgs,
  config,
  lib,
  ...
}: {
  services.xserver.videoDrivers = ["nvidia"];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      vulkan-loader
      vulkan-extension-layer
      mesa
    ];
  };

  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.latest;

    nvidiaSettings = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    dynamicBoost.enable = false;

    prime = {
      /*
         offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      */
      # sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  boot = {
    kernelParams = [
      # Required for Wayland on NVIDIA
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
    ];

    extraModprobeConfig =
      "options nvidia "
      + lib.concatStringsSep " " [
        # nvidia assume that by default your CPU does not support PAT,
        # but this is effectively never the case in 2023
        "NVreg_UsePageAttributeTable=1"
        # This is sometimes needed for ddc/ci support, see
        # https://www.ddcutil.com/nvidia/
        #
        # Current monitor does not support it, but this is useful for
        # the future
        "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
      ];
  };

  environment.variables = {
    GBM_BACKEND = "nvidia-drm";
    # Apparently, without this nouveau may attempt to be used instead
    # (despite it being blacklisted)
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # VA-API Backend as NVIDIA
    LIBVA_DRIVER_NAME = "nvidia";

    # --- Wayland ---
    # Prefer Wayland, but allow X11 fallback for SDK-bundled Qt apps such as
    # the Android emulator, which does not ship the Wayland platform plugin.
    QT_QPA_PLATFORM = "wayland;xcb";
    # Ensure SDL2 applications use Wayland
    SDL_VIDEODRIVER = "wayland";
    # Force Firefox to use Wayland
    MOZ_ENABLE_WAYLAND = "1";
    # Ozone platform for Chromium/Electron apps
    NIXOS_OZONE_WL = "1";
  };

  # WLR_NO_HARDWARE_CURSORS is deliberately absent: it is a wlroots variable,
  # and niri is built on Smithay, so it has no effect here. niri's equivalent
  # knob is `debug.disable-cursor-plane` in programs.niri.settings, which is
  # only needed if the cursor actually misbehaves on this GPU.
}
