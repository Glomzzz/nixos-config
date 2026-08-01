{
  config,
  lib,
  pkgs,
  ...
}: {
  home.sessionVariables = {
    # Android Studio is storing AVDs under XDG config on this host. Export the
    # paths so direct emulator CLI invocations resolve the same AVD location.
    ANDROID_EMULATOR_HOME = "${config.xdg.configHome}/.android";
    ANDROID_AVD_HOME = "${config.xdg.configHome}/.android/avd";
  };

  home.activation.androidEmulatorFeatures = lib.hm.dag.entryAfter ["writeBoundary"] ''
        android_dir="$HOME/.android"
        features_file="$android_dir/advancedFeatures.ini"
        temp_file="$(mktemp)"
        emulator_lib64="$HOME/Android/Sdk/emulator/lib64"

        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$android_dir"

        if [ -f "$features_file" ]; then
          ${pkgs.gnugrep}/bin/grep -Ev '^(Vulkan|GLDirectMem|ForceSwiftshader|ForceGpuSoftware)[[:space:]]*=' "$features_file" > "$temp_file" || true
        else
          : > "$temp_file"
        fi

        cat <<'EOF' >> "$temp_file"
    ForceSwiftshader = on
    EOF

        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 "$temp_file" "$features_file"
        rm -f "$temp_file"

        # Android Studio currently creates AVDs under XDG config. Force existing
        # AVDs onto the software renderer so they stop picking the crashing
        # host/gfxstream Vulkan path on startup.
        for avd_root in "$HOME/.config/.android/avd" "$HOME/.android/avd"; do
          [ -d "$avd_root" ] || continue

          ${pkgs.findutils}/bin/find "$avd_root" -maxdepth 2 -type f -name config.ini | while read -r avd_config; do
            avd_temp_file="$(mktemp)"
            ${pkgs.gnugrep}/bin/grep -Ev '^hw\.gpu\.mode=' "$avd_config" > "$avd_temp_file" || true
            printf '%s\n' 'hw.gpu.mode=software' >> "$avd_temp_file"
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 "$avd_temp_file" "$avd_config"
            rm -f "$avd_temp_file"
          done
        done

        # Recent emulator builds expect a few host libraries to be available from
        # their own $ORIGIN/lib64 search path. Link them into the SDK tree so both
        # Android Studio launches and direct CLI launches resolve the same way.
        if [ -d "$emulator_lib64" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -sfn \
            ${pkgs.libpng.out}/lib/libpng16.so.16 \
            "$emulator_lib64/libpng16.so.16"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -sfn \
            ${pkgs.libxkbfile.out}/lib/libxkbfile.so.1 \
            "$emulator_lib64/libxkbfile.so.1"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -sfn \
            ${pkgs.libbsd.out}/lib/libbsd.so.0 \
            "$emulator_lib64/libbsd.so.0"
        fi
  '';
}
