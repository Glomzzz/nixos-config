#!/bin/sh

set -eu

mode=${1:-}
main_config=${2:-}
snippet_path=${3:-}
xray_value=${4:-true}
niri_command=${5:-niri}
blur_enabled=${6:-false}

if [ "$mode" != "write" ] && [ "$mode" != "configure" ]; then
    echo "usage: manage-niri-effects.sh <write|configure> <main-config> <snippet> <xray> [niri] [blur]" >&2
    exit 2
fi

if [ "$xray_value" != "true" ] && [ "$xray_value" != "false" ]; then
    echo "invalid xray value: $xray_value" >&2
    exit 2
fi

if [ "$blur_enabled" != "true" ] && [ "$blur_enabled" != "false" ]; then
    echo "invalid blur value: $blur_enabled" >&2
    exit 2
fi

snippet_dir=$(dirname -- "$snippet_path")
mkdir -p -- "$snippet_dir"
snippet_tmp=$(mktemp "$snippet_dir/.clavis-effects.kdl.XXXXXX")
main_tmp=

cleanup() {
    rm -f -- "$snippet_tmp"
    if [ -n "$main_tmp" ]; then
        rm -f -- "$main_tmp"
    fi
}
trap cleanup EXIT HUP INT TERM

{
    echo "// Managed by Clavis. Manual edits will be replaced."
    if [ "$xray_value" = "true" ]; then
        echo "// X-Ray is niri's default for client-requested effects."
        echo "// No rule override is required."
    else
        echo "layer-rule {"
        echo "    match namespace=\"^clavis-shell-\""
        echo
        echo "    background-effect {"
        echo "        xray false"
        echo "    }"
        echo "}"
        echo
        echo "window-rule {"
        echo "    match title=\"^(clavis-control-center|clavis-file-picker)$\""
        echo
        echo "    background-effect {"
        echo "        xray false"
        echo "    }"
        echo "}"
    fi
    if [ "$blur_enabled" = "true" ]; then
        echo
        echo "// wlogout does not request ext-background-effect itself."
        echo "layer-rule {"
        echo "    match namespace=\"^logout_dialog$\""
        echo
        echo "    background-effect {"
        echo "        xray $xray_value"
        echo "        blur true"
        echo "    }"
        echo "}"
    fi
} > "$snippet_tmp"

"$niri_command" validate -c "$snippet_tmp" >/dev/null
chmod 600 "$snippet_tmp"
mv -f -- "$snippet_tmp" "$snippet_path"

if [ "$mode" = "write" ]; then
    trap - EXIT HUP INT TERM
    echo "ready"
    exit 0
fi

if [ ! -f "$main_config" ]; then
    echo "niri config not found: $main_config" >&2
    exit 3
fi

if grep -Eq '^[[:space:]]*include([[:space:]]+optional=true)?[[:space:]]+"([^"]*/)?clavis-effects\.kdl"[[:space:]]*(//.*)?$' "$main_config"; then
    trap - EXIT HUP INT TERM
    echo "configured"
    exit 0
fi

main_dir=$(dirname -- "$main_config")
main_tmp=$(mktemp "$main_dir/.config.kdl.clavis.XXXXXX")
cp -p -- "$main_config" "$main_tmp"
{
    echo
    echo "// BEGIN CLAVIS EFFECTS"
    echo "include optional=true \"clavis-effects.kdl\""
    echo "// END CLAVIS EFFECTS"
} >> "$main_tmp"

"$niri_command" validate -c "$main_tmp" >/dev/null

backup_path="$main_config.clavis-backup"
if [ ! -e "$backup_path" ]; then
    cp -p -- "$main_config" "$backup_path"
fi

mv -f -- "$main_tmp" "$main_config"
main_tmp=
trap - EXIT HUP INT TERM
echo "configured"
