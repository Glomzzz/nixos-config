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
    # Force Firefox to use Wayland
    MOZ_ENABLE_WAYLAND = "1";
    # Ozone platform for Chromium/Electron apps
    NIXOS_OZONE_WL = "1";

    # Pins the X11 render grid of the PR #452 xwayland-satellite (pinned in
    # flake.nix) to niri's *logical* coordinate space, so one X pixel is one
    # logical pixel on every output regardless of that output's scale.
    #
    # This is what makes X11 apps scale per monitor. Without it satellite
    # publishes a single X-wide scale taken as the minimum across outputs, and
    # positions each XRandR output at its logical coordinate while sizing it in
    # native pixels. With eDP-1 (2560px, scale 1.5) beside HDMI-A-1 (1920px,
    # scale 1.0) those rectangles become 0..2560 and 1707..3627, overlapping by
    # 853px, and Qt resolves a window's screen by dividing its X position by its
    # own scale factor and testing the result against each rectangle - 1707/1.5
    # is 1138, still inside eDP-1, so a window moved to the external monitor was
    # never seen to leave the laptop and kept the laptop's scale.
    #
    # 1.0 rather than leaving it unset: unset, this build renders at
    # max(output scales) - here 2 - and advertises 192 DPI over XSETTINGS, which
    # is sharper on the panel because niri downsamples, but only apps that read
    # that DPI come out the right size. Anything DPI-blind, which includes
    # WeChat's statically linked Qt 5 and Steam's CEF client, then renders at
    # half size. At 1.0 every X11 app is correctly sized on both monitors with
    # no per-app variable at all; the cost is that niri upscales the 1x buffer
    # on the 1.5x panel, so X11 text is slightly softer than native.
    #
    # It has to live here, in the *system* environment, rather than in niri's
    # `environment` block: niri constructs the satellite's command itself and
    # never applies that block to it, but does pass on its own environment, and
    # niri-session re-execs as a login shell so /etc/profile reaches it.
    XWAYLAND_SATELLITE_BASE_SCALE = "1.0";
  };

  # SDL_VIDEODRIVER is deliberately absent. Setting it globally to "wayland"
  # breaks native Linux games that bundle an old SDL2: steam.sh rewrites that
  # exact value to the list form "wayland,x11", and SDL2 only learned to parse a
  # comma-separated driver list in 2.24. Older bundled copies treat the whole
  # string as one driver name, match nothing, and initialize no video backend,
  # so the game logs "Desktop is 0 x 0 @ 0 Hz" and never maps a window (seen
  # with Overcooked! 2, Unity 2017.4).
  # Modern SDL2/SDL3 already prefer Wayland on their own when a compositor is
  # present, so nothing needs this variable to get Wayland. Per-app overrides
  # belong in that app's launch options, not in the global environment.

  # WLR_NO_HARDWARE_CURSORS is deliberately absent: it is a wlroots variable,
  # and niri is built on Smithay, so it has no effect here. niri's equivalent
  # knob is `debug.disable-cursor-plane` in programs.niri.settings, which is
  # only needed if the cursor actually misbehaves on this GPU.
}
