 
{
  pkgs,
  flake-inputs,
  config,
  lib,
  ...
}:
{

  services.xserver.videoDrivers = ["nvidia"];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
    ];
  };

  # 575.57.08-6.12.32
  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.beta;

    nvidiaSettings = true;
    modesetting.enable = true;
    # Power management is required to get nvidia GPUs to behave on
    # suspend, due to firmware bugs. Aren't nvidia great?
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    dynamicBoost.enable = false;
  };

  programs.sway.package = pkgs.sway.override {
    inherit (flake-inputs.nixpkgs-wayland.packages.${pkgs.system}) sway-unwrapped;
  };

  boot = {
    kernelParams = [ "nvidia-drm.fbdev=1" "nvidia-drm.modeset=1" ];

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
    # Hardware cursors are currently broken on nvidia
    # TEST
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}

