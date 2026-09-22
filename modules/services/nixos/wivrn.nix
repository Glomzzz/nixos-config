{pkgs, ...}: {
  services.wivrn = {
    enable = true;
    package = pkgs.wivrn;
    # WiVRn is the selected Quest streaming runtime (replaces ALVR/Steam
    # Link): it runs its own OpenXR stack, so SteamVR is not involved in the
    # stream. Start the server with the desktop session.
    autoStart = true;
    # Grants cap_sys_nice to the server via a security wrapper so WiVRn's
    # async reprojection can run at realtime priority (together with the
    # rtprio=99 PAM limit in programs/vr.nix); keeps head-tracked motion
    # smooth instead of letting it fall back to normal scheduling.
    highPriority = true;
    openFirewall = true;

    steam = {
      enable = true;
      # Lets Steam's pressure-vessel import the WiVRn OpenXR runtime
      # (PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES), so OpenXR games launched
      # from Steam stream through WiVRn instead of SteamVR.
      importOXRRuntimes = true;
    };

    config = {
      enable = true;
      json = {
        # WiVRn only auto-detects OpenVR->OpenXR translation layers in
        # standard paths (/opt/xrizer etc.), never Nix store paths. Point it
        # at xrizer so OpenVR-only games launched from Steam also run through
        # the WiVRn runtime. Everything else (NVENC encoder, codec, bitrate,
        # refresh rate) is auto-selected or tuned in the headset/dashboard
        # (http://localhost:9757) at runtime.
        openvr-compat-path = "${pkgs.xrizer}/lib/xrizer";
      };
    };
  };

  environment.systemPackages = [pkgs.xrizer];
}
