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
    # flake.nix) to a fixed multiple of niri's logical coordinate space, the
    # same multiple on every output regardless of that output's own scale.
    #
    # That uniformity is what makes X11 apps scale per monitor. Without this
    # build satellite publishes a single X-wide scale taken as the minimum
    # across outputs, and positions each XRandR output at its logical
    # coordinate while sizing it in native pixels. With eDP-1 (2560px, scale
    # 1.5) beside HDMI-A-1 (1920px, scale 1.0) those rectangles become 0..2560
    # and 1707..3627, overlapping by 853px, and a toolkit resolves a window's
    # screen by dividing its X position by the window's own scale factor and
    # testing the result against each rectangle - 1707/1.5 is 1138, still
    # inside eDP-1, so a window moved to the external monitor was never seen to
    # leave the laptop and kept the laptop's scale.
    #
    # 1.5, matching the panel scale, so that one X pixel is one *physical*
    # pixel on eDP-1: a 1.5x-scaled window is then composited 1:1 instead of
    # being stretched. At 1.0 the X buffer only ever holds logical pixels, so
    # niri had to upscale every X11 surface by 1.5 on the panel, which was
    # visibly soft - measured on a screenshot of the same Qt app rendered
    # through both, Laplacian edge energy was 405 at 1.0 against 2437 at 1.5
    # for the same apparent text size (~22px glyph rows in both).
    #
    # Leaving it unset is not the same thing: the build then tracks
    # max(output scales), which changes as monitors come and go, so the X
    # coordinate space silently rescales mid-session.
    #
    # Apps that read the DPI satellite advertises (144 here) need nothing
    # further. An app that ignores it lays out in raw X pixels and so comes out
    # 1/1.5 of the intended size; because the multiple is uniform, one flat
    # scale factor - QT_SCALE_FACTOR for Qt, GDK_SCALE for GTK - fixes such an
    # app on both monitors at once, which is why no such variable is set
    # anywhere here yet: none of the X11 clients in this config has needed one.
    #
    # It has to live here, in the *system* environment, rather than in niri's
    # `environment` block: niri constructs the satellite's command itself and
    # never applies that block to it, but does pass on its own environment, and
    # niri-session re-execs as a login shell so /etc/profile reaches it.
    XWAYLAND_SATELLITE_BASE_SCALE = "1.5";
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
