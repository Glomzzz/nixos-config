#!/usr/bin/env bash

set -u

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd -- "$script_dir/../.." && pwd)
asset_dir="$shell_dir/assets/wlogout"
color_file="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-dev-colorscheme/colors.json"
personalization_file="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/personalization.json"
style=${1:-grid}

if ! command -v wlogout >/dev/null 2>&1; then
    printf 'Clavis power menu: wlogout is not installed.\n' >&2
    exit 127
fi

if ! command -v envsubst >/dev/null 2>&1; then
    printf 'Clavis power menu: envsubst is required.\n' >&2
    exit 127
fi

read_color() {
    local key=$1
    local fallback=$2
    local value=""

    if [[ -r "$color_file" ]]; then
        value=$(sed -n \
            "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\(#[0-9A-Fa-f]\\{6\\}\\)\".*/\\1/p" \
            "$color_file" | head -n 1)
    fi

    printf '%s' "${value:-$fallback}"
}

read_opacity() {
    local value=""

    if [[ -r "$personalization_file" ]]; then
        value=$(sed -n \
            's/.*"shellBackgroundOpacity"[[:space:]]*:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' \
            "$personalization_file" | head -n 1)
    fi

    if [[ ! "$value" =~ ^(0([.][0-9]+)?|1([.]0+)?)$ ]]; then
        value=0.82
    fi
    printf '%s' "$value"
}

logical_size=$(niri msg focused-output 2>/dev/null \
    | sed -n 's/^[[:space:]]*Logical size: \([0-9][0-9]*\)x\([0-9][0-9]*\)$/\1 \2/p' \
    | head -n 1)
read -r screen_width screen_height <<< "${logical_size:-1920 1080}"

case "$style" in
    row)
        layout="$asset_dir/layout_1"
        template="$asset_dir/style_1.css"
        columns=6
        export margin=$((screen_height * 28 / 100))
        export hoverMargin=$((screen_height * 23 / 100))
        ;;
    *)
        layout="$asset_dir/layout_2"
        template="$asset_dir/style_2.css"
        columns=2
        export marginX=$((screen_width * 35 / 100))
        export marginY=$((screen_height * 25 / 100))
        export hoverX=$((screen_width * 32 / 100))
        export hoverY=$((screen_height * 20 / 100))
        ;;
esac

export fntSize=$((screen_height * 2 / 100))
export activeRad=50
export buttonRad=80
export assetDir="$asset_dir"
export Surface
export OnSurface
export PrimaryContainer
export OnPrimaryContainer
export LockContainer
export OnLockContainer
export ButtonOpacity
Surface=$(read_color surface_container_lowest '#090f0e')
OnSurface=$(read_color on_surface '#dee4e0')
PrimaryContainer=$(read_color primary_container '#005144')
OnPrimaryContainer=$(read_color on_primary_container '#a0f2de')
LockContainer=$(read_color tertiary_container '#2a4a5f')
OnLockContainer=$(read_color on_tertiary_container '#c8e6ff')
ButtonOpacity=$(read_opacity)

case "$(read_color background '#0e1513')" in
    '#f'*|'#e'*|'#d'*|'#c'*|'#b'*|'#a'*|'#F'*|'#E'*|'#D'*|'#C'*|'#B'*|'#A'*)
        export iconTone=black
        ;;
    *)
        export iconTone=white
        ;;
esac

runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
generated_css=$(mktemp "$runtime_dir/clavis-wlogout.XXXXXX.css")
trap 'rm -f -- "$generated_css"' EXIT

envsubst < "$template" > "$generated_css"
wlogout \
    --buttons-per-row "$columns" \
    --column-spacing 0 \
    --row-spacing 0 \
    --margin 0 \
    --layout "$layout" \
    --css "$generated_css" \
    --protocol layer-shell
