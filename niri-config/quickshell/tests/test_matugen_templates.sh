#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator="$repo_dir/scripts/theme/generate_matugen_colors.sh"
test_dir="$(mktemp -d /tmp/clavis-matugen-test.XXXXXX)"

cleanup() {
    rm -rf -- "$test_dir"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

command -v matugen >/dev/null 2>&1 || fail "matugen is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

expected_hooks=(
    'post_hook = "cp \"$HOME/.config/kitty/themes/Matugen.conf\" \"$HOME/.config/kitty/current-theme.conf\" && (pkill -USR1 -x kitty >/dev/null 2>&1 || true)"'
    'post_hook = "busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 ReloadAddonConfig s classicui >/dev/null 2>&1 || true"'
    'post_hook = "niri msg action load-config-file >/dev/null 2>&1 || true"'
)
for expected_hook in "${expected_hooks[@]}"; do
    grep -Fqx "$expected_hook" "$repo_dir/matugen/config.toml" \
        || fail "missing official hot-reload hook: $expected_hook"
done
test_home="$test_dir/home"
mkdir -p "$test_home"

if HOME="$test_home" "$generator" >/dev/null 2>&1; then
    fail "generator unexpectedly accepted a missing source"
fi
if HOME="$test_home" "$generator" \
    --color "#6750a4" \
    --image "$repo_dir/assets/images/dino.png" \
    >/dev/null 2>&1; then
    fail "generator unexpectedly accepted image and color together"
fi
if HOME="$test_home" "$generator" \
    --color "#6750a4" \
    --mode sepia \
    >/dev/null 2>&1; then
    fail "generator unexpectedly accepted an invalid mode"
fi
if HOME="$test_home" "$generator" \
    --color "#6750a4" \
    --templates "kitty,unknown" \
    >/dev/null 2>&1; then
    fail "generator unexpectedly accepted an unknown template"
fi

# Exercise the production config without creating outputs or running hooks.
HOME="$test_home" "$generator" \
    --color "#6750a4" \
    --mode dark \
    --scheme scheme-tonal-spot \
    --dry-run

filtered_home="$test_dir/filtered-home"
HOME="$filtered_home" "$generator" \
    --color "#6750a4" \
    --mode dark \
    --scheme scheme-tonal-spot \
    --templates "btop,niri"

filtered_outputs=(
    "$filtered_home/.cache/quickshell-dev-colorscheme/colors.json"
    "$filtered_home/.config/btop/themes/matugen.theme"
    "$filtered_home/.config/niri/colors.kdl"
)
for output in "${filtered_outputs[@]}"; do
    [[ -s "$output" ]] || fail "missing filtered output: $output"
done

disabled_outputs=(
    "$filtered_home/.config/kitty/themes/Matugen.conf"
    "$filtered_home/.local/share/fcitx5/themes/Matugen/theme.conf"
)
for output in "${disabled_outputs[@]}"; do
    [[ ! -e "$output" ]] || fail "disabled template generated output: $output"
done

kitty_home="$test_dir/kitty-home"
hook_bin="$test_dir/hook-bin"
mkdir -p "$hook_bin"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$hook_bin/pkill"
chmod +x "$hook_bin/pkill"
HOME="$kitty_home" PATH="$hook_bin:$PATH" "$generator" \
    --color "#6750a4" \
    --mode dark \
    --scheme scheme-tonal-spot \
    --templates "kitty"
cmp -s \
    "$kitty_home/.config/kitty/themes/Matugen.conf" \
    "$kitty_home/.config/kitty/current-theme.conf" \
    || fail "Kitty current-theme.conf was not synchronized"

quickshell_only_home="$test_dir/quickshell-only-home"
HOME="$quickshell_only_home" "$generator" \
    --color "#6750a4" \
    --mode dark \
    --scheme scheme-tonal-spot \
    --templates ""
[[ -s "$quickshell_only_home/.cache/quickshell-dev-colorscheme/colors.json" ]] \
    || fail "Quickshell output is missing when all external templates are disabled"
[[ ! -e "$quickshell_only_home/.config" ]] \
    || fail "external template directories were created for an empty selection"

mock_bin="$test_dir/bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/matugen" <<'EOF'
#!/usr/bin/env sh
exit 42
EOF
chmod +x "$mock_bin/matugen"
if HOME="$test_home" PATH="$mock_bin:$PATH" "$generator" \
    --color "#6750a4" \
    --dry-run \
    >/dev/null 2>&1; then
    fail "generator swallowed a matugen failure"
fi

for render_mode in dark light; do
    output_dir="$test_dir/$render_mode"
    render_config="$output_dir/render.toml"
    mkdir -p "$output_dir"

    cat > "$render_config" <<EOF
[config]
version_check = false

[templates.quickshell]
input_path = "$repo_dir/matugen/templates/quickshell-colors.json"
output_path = "$output_dir/colors.json"

[templates.btop]
input_path = "$repo_dir/matugen/templates/btop.theme"
output_path = "$output_dir/btop.theme"

[templates.kitty]
input_path = "$repo_dir/matugen/templates/kitty-colors.conf"
output_path = "$output_dir/kitty.conf"

[templates.fcitx5]
input_path = "$repo_dir/matugen/templates/fcitx5-theme.conf"
output_path = "$output_dir/fcitx5.conf"

[templates.niri]
input_path = "$repo_dir/matugen/templates/niri-colors.kdl"
output_path = "$output_dir/niri-colors.kdl"

EOF

    matugen color hex "#6750a4" \
        --mode "$render_mode" \
        --type scheme-tonal-spot \
        --config "$render_config" \
        --quiet

    outputs=(
        "$output_dir/colors.json"
        "$output_dir/btop.theme"
        "$output_dir/kitty.conf"
        "$output_dir/fcitx5.conf"
        "$output_dir/niri-colors.kdl"
    )
    for output in "${outputs[@]}"; do
        [[ -s "$output" ]] || fail "missing rendered output: $output"
        if grep -Fq '{{' "$output" || grep -Fq '<*' "$output"; then
            fail "unrendered template expression in $output"
        fi
    done

    python3 -m json.tool "$output_dir/colors.json" >/dev/null

    grep -Fq '"primary": "#' "$output_dir/colors.json" \
        || fail "Quickshell primary color is missing"
    grep -Fq 'theme[main_bg]=""' "$output_dir/btop.theme" \
        || fail "btop transparency was not preserved"
    grep -Fq "active_tab_background" "$output_dir/kitty.conf" \
        || fail "Kitty UI colors are missing"
    grep -Fq "Name=Matugen" "$output_dir/fcitx5.conf" \
        || fail "Fcitx5 metadata is missing"
    grep -Fq "active-gradient" "$output_dir/niri-colors.kdl" \
        || fail "Niri focus gradient is missing"
    if grep -Fq "background-color" "$output_dir/niri-colors.kdl" \
        || grep -Fq "backdrop-color" "$output_dir/niri-colors.kdl"; then
        fail "Niri generated colors must not make wallpaper surfaces opaque"
    fi
    if command -v niri >/dev/null 2>&1; then
        printf 'include "%s"\n' "$output_dir/niri-colors.kdl" \
            > "$output_dir/niri-test.kdl"
        niri validate -c "$output_dir/niri-test.kdl" >/dev/null
    fi
done

printf '%s\n' "matugen template tests passed"
