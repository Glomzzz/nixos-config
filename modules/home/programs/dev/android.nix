{
  config,
  lib,
  pkgs,
  ...
}: {
  home.activation.androidEmulatorVulkan = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    android_dir="$HOME/.android"
    features_file="$android_dir/advancedFeatures.ini"
    temp_file="$(mktemp)"

    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$android_dir"

    if [ -f "$features_file" ]; then
      ${pkgs.gnugrep}/bin/grep -Ev '^(Vulkan|GLDirectMem)[[:space:]]*=' "$features_file" > "$temp_file" || true
    else
      : > "$temp_file"
    fi

    cat <<'EOF' >> "$temp_file"
    Vulkan = on
    GLDirectMem = on
    EOF

    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 "$temp_file" "$features_file"
    rm -f "$temp_file"
  '';
}
