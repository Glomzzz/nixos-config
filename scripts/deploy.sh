#!/usr/bin/env bash
# Build ~/nc/nixos-config (host "nixos") through the local proxy, then optionally activate it.
#
# Usage:
#   scripts/deploy.sh             build only; nothing is activated (default)
#   scripts/deploy.sh --dry-run   evaluate and list what a build would fetch and build
#   scripts/deploy.sh --switch    build, then activate after confirmation
#
# Environment:
#   DEPLOY_PROXY       proxy URL tried before the built-in candidates
#   NIXOS_SECRETS_DIR  local nixos-secrets checkout (default: ~/nixos-secrets)
#   DEPLOY_MAX_JOBS    derivations built in parallel (default: 24)
#
# The flake is evaluated as root because the secrets checkout has root-only files
# (.jj metadata). hardware/default.nix reads DMI, so every evaluation is --impure.
# Run as your normal user (glom); the script calls sudo where needed.
set -euo pipefail

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
say() { printf '==> %s\n' "$*"; }

switch=0
dry_run=0
for arg in "$@"; do
  case $arg in
    --switch) switch=1 ;;
    --dry-run) dry_run=1 ;;
    -h | --help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done
[[ $switch -eq 1 && $dry_run -eq 1 ]] && die "--switch and --dry-run cannot be combined"
[[ $EUID -eq 0 ]] && die "run as your normal user (glom); the script calls sudo where needed"

dir=$(cd "$(dirname "$0")/.." && pwd -P)
secrets_dir=${NIXOS_SECRETS_DIR:-$HOME/nixos-secrets}
state="${XDG_STATE_HOME:-$HOME/.local/state}/nc-deploy"
host=nixos
action=build
if [[ $dry_run -eq 1 ]]; then action=dry-build; fi

# Both candidates are mihomo listeners (mihomo/base.nix: socks-port 20170, mixed-port 20172).
# Earlier timings on GitHub archives ranked SOCKS5 20170 ahead of the mixed port 20172.
# The 27101 HTTP listener is gone: it is not part of the mihomo configuration.
proxy_candidates=(socks5h://127.0.0.1:20170 http://127.0.0.1:20172)
if [[ -n ${DEPLOY_PROXY:-} ]]; then
  proxy_candidates=("$DEPLOY_PROXY" "${proxy_candidates[@]}")
fi
no_proxy_list=localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,mirrors.ustc.edu.cn
proxy_vars=http_proxy,https_proxy,HTTP_PROXY,HTTPS_PROXY,all_proxy,ALL_PROXY,no_proxy,NO_PROXY,NIX_CONFIG
drop=/run/systemd/system/nix-daemon.service.d/proxy.conf
# Flaky routes: wait longer and retry before a download is reported as failed.
export NIX_CONFIG=$'connect-timeout = 60\nstalled-download-timeout = 300\ndownload-attempts = 10'

for f in flake.nix hosts/nixos/default.nix hardware/default.nix; do
  [[ -f $dir/$f ]] || die "missing $dir/$f"
done
[[ -f $secrets_dir/flake.nix ]] || die "secrets flake not found at $secrets_dir (set NIXOS_SECRETS_DIR)"
for cmd in git curl nixos-rebuild sudo; do
  command -v "$cmd" >/dev/null || die "$cmd is not in PATH"
done
mkdir -p "$state"

say "repository: $dir"
# The flake only sees git-tracked files, so untracked files would be silently missing.
untracked=$(git -C "$dir" ls-files --others --exclude-standard)
[[ -z $untracked ]] || die "untracked files are invisible to the flake; git add them:"$'\n'"$untracked"
if [[ -n $(git -C "$dir" status --porcelain) ]]; then
  say "warning: uncommitted changes in $dir; the flake evaluates the working tree"
fi
say "machine: $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) / $(cat /sys/class/dmi/id/product_name 2>/dev/null)"

# Same read-only GitHub token as the Justfile, used only when it is provisioned.
token_file=${NIX_GITHUB_TOKEN_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/nixos/github-read-token}
wrap=()
if [[ -e $token_file || -n ${NIX_GITHUB_TOKEN_FILE:-} ]]; then
  wrap=("$dir/scripts/with-github-token")
fi

say "sudo is needed to route nix-daemon, read the secrets checkout, and build"
sudo -v

# One URL per kind of fetch the build makes: nix cache, GitHub sources, and the
# crates.io vendoring that runs inside nix-daemon's sandbox.
probe_proxy() {
  local p=$1 url code
  for url in https://cache.nixos.org/nix-cache-info https://github.com \
    https://static.crates.io/crates/allocator-api2/0.2.21/download; do
    code=$(curl -sS -x "$p" --max-time 20 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)
    [[ $code == 200 ]] || return 1
  done
}

# Sets $proxy to the first candidate that passes every probe; empty if none does.
choose_proxy() {
  local candidate _
  proxy=""
  for candidate in "${proxy_candidates[@]}"; do
    for _ in 1 2; do
      if probe_proxy "$candidate"; then
        proxy=$candidate
        return 0
      fi
    done
  done
}

# Downloads and builder fetches happen in nix-daemon, not in this shell. sudo
# --preserve-env only reaches the client, so the daemon gets its own drop-in. The
# drop-in also overrides all_proxy/ALL_PROXY: the system unit sets them to SOCKS,
# which Python fetchers handle poorly under concurrency.
apply_proxy() {
  if [[ -z $proxy ]]; then
    say "warning: no proxy candidate passed every probe (${proxy_candidates[*]}); downloads go direct and may time out"
    unset all_proxy ALL_PROXY
    export no_proxy=$no_proxy_list NO_PROXY=$no_proxy_list
    if [[ -e $drop ]]; then
      say "removing the stale nix-daemon proxy drop-in"
      sudo rm -f "$drop"
      sudo systemctl daemon-reload
      sudo systemctl restart nix-daemon
    fi
    return 0
  fi
  say "proxy $proxy passes the probes; routing nix-daemon through it (CN mirror and LAN stay direct)"
  export http_proxy=$proxy https_proxy=$proxy HTTP_PROXY=$proxy HTTPS_PROXY=$proxy
  export all_proxy=$proxy ALL_PROXY=$proxy no_proxy=$no_proxy_list NO_PROXY=$no_proxy_list
  sudo install -d -m 0755 "$(dirname "$drop")"
  {
    printf '[Service]\n'
    for var in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY; do
      printf 'Environment="%s=%s"\n' "$var" "${!var}"
    done
  } | sudo tee "$drop" >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl restart nix-daemon
}

# A failed build is retried only when the log shows a transfer failure. Outputs that
# finished are kept by nix, so a retry rebuilds just what failed.
is_network_failure() {
  grep -qE '^error: unable to download|Failed to download tarball|ReadTimeoutError|ConnectTimeoutError|ConnectionError|Timeout was reached|Failed sending data|SSL connect error|Could not resolve host|Connection refused' "$1"
}

# prefetch-begin
# Single-URL fixed-output downloads (for example the NVIDIA driver) are slow as one
# stream: a single connection here reaches about 120-200 KB/s, while eight parallel
# ranges reach about 0.8-1 MB/s. They are fetched here, checked by the store path they
# produce, and added to the store, so the builder finds the output and skips its download.
fetch_ranged() {
  local url=$1 dest=$2 size=$3 streams=8 chunk i s e code rc=0
  local -a pids=() parts=()
  chunk=$(( (size + streams - 1) / streams ))
  for ((i = 0; i < streams; i++)); do
    s=$((i * chunk)); e=$((s + chunk - 1))
    if ((e >= size)); then e=$((size - 1)); fi
    if ((s > e)); then break; fi
    parts+=("$dest.part$i")
    (
      for _ in 1 2 3 4 5; do
        code=$(curl -sSL --max-time 1200 --speed-time 60 --speed-limit 1000 \
          -r "$s-$e" -o "$dest.part$i" -w '%{http_code}' "$url" 2>/dev/null || true)
        [[ $code == 206 ]] && exit 0
        sleep 3
      done
      exit 1
    ) &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do wait "$pid" || rc=1; done
  if ((rc != 0)); then rm -f "$dest".part*; return 1; fi
  cat "${parts[@]}" > "$dest"
  rm -f "${parts[@]}"
  [[ $(stat -c %s "$dest") -eq $size ]]
}

fetch_file() {
  local url=$1 dest=$2 size="" accept=""
  read -r size accept < <(curl -sIL --max-time 30 "$url" 2>/dev/null | tr -d '\r' |
    awk 'tolower($1)=="content-length:"{l=$2} tolower($1)=="accept-ranges:"{a=$2} END{print l+0, a}')
  if [[ ${size:-0} -ge 8388608 && $accept == bytes ]]; then
    if fetch_ranged "$url" "$dest" "$size"; then return 0; fi
    say "ranged download failed; falling back to one stream"
  fi
  curl -fsSL --retry 20 --retry-all-errors --retry-delay 3 --speed-time 60 --speed-limit 1000 \
    -C - -o "$dest" "$url"
}

# Fetches one fixed-output derivation's download if it is flat sha256 with URLs and not
# already in the store. Returns 0 when nothing is needed or the file was added.
prefetch_one() {
  local drv=$1 json hash out name tmp url urls added
  json=$(nix derivation show "$drv" 2>/dev/null) || return 0
  hash=$(grep -oE '"outputHash":"[^"]+"' <<<"$json" | head -1 | cut -d'"' -f4)
  if [[ $hash != sha256-* ]]; then return 0; fi
  if ! grep -q '"outputHashMode":"flat"' <<<"$json"; then return 0; fi
  urls=$(grep -oE '"urls":\[[^]]*\]' <<<"$json" | head -1 | grep -oE 'https?://[^"]+' || true)
  if [[ -z $urls ]]; then return 0; fi
  out=$(nix-store -q --outputs "$drv" | head -1)
  # A file can sit at $out without being registered (a failed build leaves one), so ask
  # nix whether the path is valid rather than testing for the file.
  if nix path-info "$out" >/dev/null 2>&1; then return 0; fi
  name=${out#/nix/store/*-}
  tmp=$(mktemp -d "$state/prefetch.XXXXXX")
  for url in $urls; do
    say "prefetching $name from $url"
    if fetch_file "$url" "$tmp/$name" && added=$(nix-store --add-fixed sha256 "$tmp/$name") && [[ $added == "$out" ]]; then
      say "prefetched $name"
      rm -rf "$tmp"
      return 0
    fi
    say "  not usable from $url; trying the next URL"
    rm -f "$tmp/$name"
  done
  rm -rf "$tmp"
  say "warning: could not prefetch $name; the builder will fetch it"
}

# Derivations that the dry-build plan lists as to be built.
prefetch_plan() {
  awk '/derivations will be built:/{f=1; next} f && /^  \/nix\/store\/.*\.drv$/{print $1; next} f{exit}' "$1"
}
# prefetch-end

choose_proxy
apply_proxy
rebuild=(sudo "--preserve-env=$proxy_vars" nixos-rebuild)

# --no-update-lock-file: a build must never rewrite flake.lock. The local secrets
# checkout replaces the GitHub input, so the GitHub copy is not needed for a build.
# 16 cores and 31 GB RAM here. Most derivations wait on fetches, so more jobs than
# cores overlap that waiting; memory limits how far this can go.
max_jobs=${DEPLOY_MAX_JOBS:-24}
[[ $max_jobs =~ ^[1-9][0-9]*$ ]] || die "DEPLOY_MAX_JOBS must be a positive integer, got '$max_jobs'"
rebuild_args=(--flake "$dir#$host" --impure --max-jobs "$max_jobs" --no-update-lock-file --override-input nixos-secrets "path:$secrets_dir")
if [[ $action == build ]]; then
  plan_log="$state/$(date -u +%Y%m%dT%H%M%SZ)-plan.log"
  say "planning the build (dry-build) to prefetch fixed-output downloads; log: $plan_log"
  (cd "$state" && "${wrap[@]}" "${rebuild[@]}" dry-build "${rebuild_args[@]}") >"$plan_log" 2>&1 || say "warning: dry-build failed; the build will report the error"
  while read -r drv; do
    prefetch_one "$drv" || say "warning: prefetch of ${drv##*/} failed"
  done < <(prefetch_plan "$plan_log")
fi

attempt=1
max_attempts=3
while :; do
  log="$state/$(date -u +%Y%m%dT%H%M%SZ)-$action.log"
  say "nixos-rebuild $action $host (attempt $attempt/$max_attempts); nothing is activated. Log: $log"
  if (cd "$state" && "${wrap[@]}" "${rebuild[@]}" "$action" "${rebuild_args[@]}") 2>&1 | tee -a "$log"; then
    break
  fi
  if [[ $attempt -ge $max_attempts ]] || ! is_network_failure "$log"; then
    die "$action failed (log: $log)"
  fi
  attempt=$((attempt + 1))
  say "build hit transfer failures; finished outputs are kept. Re-probing proxies in 20 s, then attempt $attempt/$max_attempts"
  sleep 20
  choose_proxy
  apply_proxy
done

if [[ $dry_run -eq 1 ]]; then
  say "dry run finished; nothing was built or activated"
  exit 0
fi
say "build OK: $(readlink -f "$state/result")"

if [[ $switch -eq 0 ]]; then
  say "not activated. Review, then run: $0 --switch"
  exit 0
fi

[[ -t 0 ]] || die "--switch needs an interactive terminal to confirm"
read -r -p "Activate with nixos-rebuild switch now? [y/N] " answer
[[ $answer == [yY] ]] || { say "not activated"; exit 0; }

log="$state/$(date -u +%Y%m%dT%H%M%SZ)-switch.log"
say "nixos-rebuild switch $host; log: $log"
if ! (cd "$state" && "${wrap[@]}" "${rebuild[@]}" switch "${rebuild_args[@]}") 2>&1 | tee -a "$log"; then
  die "switch failed (log: $log)"
fi
say "activated"
