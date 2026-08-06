#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
launcher="$repo_dir/scripts/system/power-menu.sh"
test_dir=$(mktemp -d /tmp/clavis-power-menu-test.XXXXXX)

cleanup() {
    rm -rf -- "$test_dir"
}
trap cleanup EXIT HUP INT TERM

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

mkdir -p "$test_dir/bin"

cat > "$test_dir/bin/niri" <<'EOF'
#!/bin/sh
cat <<'OUTPUT'
Output "Test" (TEST-1)
  Logical size: 1920x1080
OUTPUT
EOF

cat > "$test_dir/bin/wlogout" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$MOCK_WLOGOUT_ARGS"
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--css" ]; then
        shift
        cp -- "$1" "$MOCK_WLOGOUT_CSS"
        exit 0
    fi
    shift
done
exit 1
EOF

chmod +x "$test_dir/bin/niri" "$test_dir/bin/wlogout"
mkdir -p "$test_dir/cache/quickshell"
printf '%s\n' \
    '{"effects":{"shellBackgroundOpacity":0.42}}' \
    > "$test_dir/cache/quickshell/personalization.json"

run_style() {
    style=$1
    expected_layout=$2
    expected_columns=$3
    args="$test_dir/$style.args"
    css="$test_dir/$style.css"

    MOCK_WLOGOUT_ARGS="$args" \
    MOCK_WLOGOUT_CSS="$css" \
    XDG_CACHE_HOME="$test_dir/cache" \
    PATH="$test_dir/bin:$PATH" \
        "$launcher" "$style"

    assert_contains "$args" "--buttons-per-row"
    assert_contains "$args" "$expected_columns"
    assert_contains "$args" "$repo_dir/assets/wlogout/$expected_layout"
    assert_contains "$args" "--protocol"
    assert_contains "$args" "layer-shell"
    assert_contains "$css" 'font-family: "LXGW WenKai GB Screen"'
    assert_contains "$css" "$repo_dir/assets/wlogout/icons/lock_white.png"
    assert_contains "$css" "cubic-bezier(.55, 0, .28, 1.682)"
    assert_contains "$css" "background-color: alpha(#2a4a5f, 0.42)"

    if grep -Fq '${' "$css"; then
        fail "$style CSS contains an unresolved template variable"
    fi
}

run_style grid layout_2 2
run_style row layout_1 6

echo "power menu launcher tests passed"
