{
  lib,
  buildNpmPackage,
  coreutils,
  makeBinaryWrapper,
  nodejs,
  openviking-agent-plugins,
  pnpm,
  util-linux,
}:
buildNpmPackage rec {
  pname = "deepseek-harness";
  version = "0.1.1-rc.2";

  src = ./deepseek-harness;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-9fPfi8vQ67cYCKqQuiyb5wlkHu64tohlXRjlYbh/+cM=";
  dontNpmBuild = true;
  # The lockfile pins every @deepseek-ai package through overrides, so the
  # plugin's stale `||` peer ranges (e.g. dsh-working-activity's ^0.1.0-rc.6)
  # must not trigger peer resolution: without this flag npm ci's ideal-tree
  # build grinds for tens of minutes over the override set, and offline it
  # needs packuments the prefetched cache does not carry. With it, npm ci
  # replays the lockfile directly and reifies from the fetched cache. The
  # install hook's `npm prune` step must get the same flag (nixpkgs' default
  # of npmPruneFlags ? npmInstallFlags does not propagate into the env).
  # The lockfile also omits metadata-only `workspace:*` dependency maps from
  # dsh-tui's bundled @dsh-std modules; npm rejects those outside the
  # publisher's workspace even though the modules are already in the tarball.
  npmInstallFlags = ["--legacy-peer-deps"];
  npmPruneFlags = ["--legacy-peer-deps"];

  nativeBuildInputs = [makeBinaryWrapper];

  postInstall = ''
    packageRoot="$out/lib/node_modules/deepseek-harness-nix"
    substituteInPlace "$packageRoot/bootstrap.mjs" \
      --replace-fail '@PACKAGE_ROOT@' "$packageRoot"
    substituteInPlace "$packageRoot/node_modules/openviking-dsh-nix/cordis.patch.yml" \
      --replace-fail '@OPENVIKING_PROXY@' '${openviking-agent-plugins}/bin/openviking-mcp-proxy' \
      --replace-fail '@OPENVIKING_SKILLS@' '${openviking-agent-plugins}/share/openviking/agent-plugins/skills'
    # The agent's shell seam hardcodes `bash -c`: dsh-bash-local runs the
    # command and dsh-bash-sandbox confines it, while dsh-tool-bash is the
    # model-facing contract. This machine lives in fish
    # (modules/home/shell/fish.nix), so re-point all three at fish. `fish`
    # resolves through the invoking environment's PATH exactly like `bash`
    # did, keeping the user's own fish the shell of record. If an upstream
    # package update renames any of these literals, --replace-fail fails the
    # build loudly instead of silently shipping a bash harness.
    substituteInPlace "$packageRoot/node_modules/@deepseek-ai/dsh-bash-local/lib/index.js" \
      --replace-fail '"bash",' '"fish",'
    substituteInPlace "$packageRoot/node_modules/@deepseek-ai/dsh-bash-sandbox/lib/index.js" \
      --replace-fail '"bash",' '"fish",'
    substituteInPlace "$packageRoot/node_modules/@deepseek-ai/dsh-tool-bash/lib/index.js" \
      --replace-fail 'bash command' 'fish command' \
      --replace-fail 'bash -c' 'fish -c'
    tuiRoot="$packageRoot/node_modules/@deepseek-harness-tui/dsh-tui"
    # legacy-peer-deps hoists these beside the web profile's React 18. Give
    # the TUI private copies so its renderer and hook helper resolve React 19.
    # Only dsh-tui depends on them, so the hoisted top-level copies are dead
    # weight afterwards and can go.
    cp -r "$packageRoot/node_modules/react-reconciler" "$tuiRoot/node_modules/"
    cp -r "$packageRoot/node_modules/usehooks-ts" "$tuiRoot/node_modules/"
    rm -rf "$packageRoot/node_modules/react-reconciler" \
      "$packageRoot/node_modules/usehooks-ts"
    # Focus-loss screen corruption: the TUI enables DECSET 1004 focus
    # reporting, so every window blur/refocus arrives on stdin as CSI I/CSI O.
    # App.handleReadable counts ANY stdin after a >5s gap as "stdin resume"
    # (tmux attach / ssh reconnect / laptop wake) and fires
    # reassertTerminalModes -> requestViewportReanchor, a full viewport
    # repaint whose geometry does not match the incrementally-diffed screen —
    # every row lands shifted and the UI garbles on focus loss. Focus events
    # are terminal notifications, not user input, so focus-only batches must
    # not trip the gap detector; real input still re-arms it. Applied as a
    # patch (not substituteInPlace) because multi-line substitutions fight
    # Nix indented-string stripping. If an upstream bump changes the
    # handleReadable context, the patch application fails the build loudly.
    patch -d "$packageRoot" -p1 < ${../patches/dsh-tui-focus-loss.patch}
    # Inline-mode stale-cell corruption: the per-second working line
    # (ActivityLine/WorkingSpinner) renders below the transcript, and the
    # diff engine's relative-cursor writes drift over time, leaving ghost
    # cells at every position the line ever occupied — rows interleave
    # ("● active · 5/256 · 1m53t…" inside transcript text) and the screen
    # garbles progressively; blur/scroll just make it visible. Drop the
    # working line while a turn is active; the status bar still shows the
    # context meter, and the screen stays static (no per-second writes).
    patch -d "$packageRoot" -p1 < ${../patches/dsh-tui-working-line.patch}
    # Boot rewrap corruption: the timeline rail appears one frame after boot
    # and narrows the transcript by ~3 columns, so every row rewraps between
    # the first two frames and the diff engine leaves stale cells (interleaved
    # text). Pin scrollGutter to hidden so the transcript width is stable.
    patch -d "$packageRoot" -p1 < ${../patches/dsh-tui-scrollgutter.patch}
    # Residual inline-mode drift: the diff engine's relative-cursor writes
    # desync from the physical screen over time (sporadic per-minute markers
    # land rows off, leaving ghost cells that interleave with the transcript).
    # The upstream fix for this class is the JetBrains frame-end viewport
    # repaint; DSH_TUI_INLINE_REPAINT=1 (set on the dsh-tui wrapper below)
    # enables that same recovery for every inline terminal — every frame ends
    # by repainting the visible viewport from the model, so any stale cells
    # are overwritten instead of accumulating.
    patch -d "$packageRoot" -p1 < ${../patches/dsh-tui-inline-repaint.patch}
    # Trim runtime-irrelevant payload (~27% of the output): source maps,
    # foreign-platform native prebuilds, and bundled test/example/doc trees
    # are never loaded at runtime. node-pty keeps only its linux-x64 prebuild;
    # npm ships win32/darwin/arm64 variants that merely bloat the store.
    find "$packageRoot/node_modules" -type d \( \
      -name test -o -name tests -o -name __tests__ \
      -o -name example -o -name examples -o -name docs \
    \) -prune -exec rm -rf {} +
    find "$packageRoot/node_modules" -name '*.map' -delete
    rm -rf "$packageRoot/node_modules/node-pty/prebuilds"/{darwin-*,win32-*,linux-arm64}
    makeBinaryWrapper ${nodejs}/bin/node "$out/bin/dsh" \
      --add-flags '--expose-internals' \
      --add-flags "$packageRoot/bootstrap.mjs" \
      --prefix PATH : ${lib.makeBinPath [pnpm]}
    makeBinaryWrapper ${nodejs}/bin/node "$out/bin/dsh-tui" \
      --add-flags '--expose-internals' \
      --add-flags "$packageRoot/bootstrap.mjs" \
      --add-flags '--tui-launcher' \
      --set DSH_TUI_INLINE_REPAINT 1 \
      --prefix PATH : "$out/bin:${lib.makeBinPath [pnpm]}"
    makeBinaryWrapper ${nodejs}/bin/node "$out/bin/modlens" \
      --add-flags "$packageRoot/node_modules/@liustack/modlens/dist/main.js"
    makeBinaryWrapper ${nodejs}/bin/node "$out/bin/modsearch" \
      --add-flags "$packageRoot/node_modules/@liustack/modsearch/dist/main.js"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export PATH="$out/bin:$PATH"
    packageRoot="$out/lib/node_modules/deepseek-harness-nix"
    test "$(dsh --version)" = "${version}"
    test "$(modlens --version)" = "3.24.0"
    test "$(modsearch --version)" = "5.9.0"
    checkHome="$TMPDIR/dsh-home"
    DSH_HOME="$checkHome" dsh web --dump-config > "$TMPDIR/dsh-config.yml"
    grep -q "name: '@liustack/modlens'" "$TMPDIR/dsh-config.yml"
    grep -q "name: '@liustack/modsearch'" "$TMPDIR/dsh-config.yml"
    grep -q 'name: dsh-routing-suite' "$TMPDIR/dsh-config.yml"
    grep -q '# == openviking-dsh-nix' "$TMPDIR/dsh-config.yml"
    grep -q "name: '@deepseek-ai/dsh-mcp-client'" "$TMPDIR/dsh-config.yml"
    grep -q "name: '@deepseek-ai/dsh-skill-filesystem'" "$TMPDIR/dsh-config.yml"
    grep -q '${openviking-agent-plugins}/bin/openviking-mcp-proxy' "$TMPDIR/dsh-config.yml"
    # The fish re-point landed in the executor, the sandbox wrapper, and the
    # model-facing tool contract.
    grep -q '"fish",' "$packageRoot/node_modules/@deepseek-ai/dsh-bash-local/lib/index.js"
    grep -q '"fish",' "$packageRoot/node_modules/@deepseek-ai/dsh-bash-sandbox/lib/index.js"
    grep -q 'Execute a fish command' "$packageRoot/node_modules/@deepseek-ai/dsh-tool-bash/lib/index.js"
    test "$(grep -c '"bash",' "$packageRoot/node_modules/@deepseek-ai/dsh-bash-local/lib/index.js")" -eq 0
    # The TUI profile: bundle composition resolves, the plugin is linked into
    # the profile directory, and the dsh-tui launcher delegates to it.
    DSH_HOME="$checkHome" dsh --profile dsh-tui --dump-config > "$TMPDIR/tui-config.yml"
    grep -q "name: '@deepseek-harness-tui/dsh-tui'" "$TMPDIR/tui-config.yml"
    test -L "$checkHome/profiles/dsh-tui/node_modules/@deepseek-harness-tui/dsh-tui"
    DSH_HOME="$checkHome" dsh-tui --dump-config > "$TMPDIR/tui-config-wrapper.yml"
    cmp "$TMPDIR/tui-config.yml" "$TMPDIR/tui-config-wrapper.yml"
    # Boot in a pseudo-terminal long enough to load and render the TUI. A
    # healthy process remains interactive until timeout; startup crashes exit
    # early, while the rendered heading proves the React tree reached commit.
    # The heading renders in under 2s on this hardware, so 3s leaves headroom
    # without pinning every rebuild to the old 5s floor.
    tuiStatus=0
    DSH_HOME="$checkHome" NODE_ENV=production TERM=xterm-256color \
      ${coreutils}/bin/timeout 3 ${util-linux}/bin/script \
        --quiet --return "$TMPDIR/tui-smoke.log" \
        -- ${coreutils}/bin/env PATH=/no-host-path "$out/bin/dsh-tui" > /dev/null 2>&1 \
      || tuiStatus=$?
    test "$tuiStatus" -eq 124
    grep -a -q 'dsh-TUI' "$TMPDIR/tui-smoke.log"
    # The focus-loss patch landed in the TUI's stdin handler: focus events
    # (CSI I / CSI O) no longer trip the stdin-gap re-anchor repaint that
    # garbled the screen on window blur.
    grep -q '\[nix patch\] Focus events (DECSET 1004' \
      "$packageRoot/node_modules/@deepseek-harness-tui/dsh-tui/lib/types/ink/components/App.js"
    grep -q 'let focusOnly = true;' \
      "$packageRoot/node_modules/@deepseek-harness-tui/dsh-tui/lib/types/ink/components/App.js"
    # The working-line and scroll-gutter patches landed too. (The patched
    # ternary wraps across lines, so the grep matches the single-line marker
    # "scrollToBottom() })), false &&" instead.)
    grep -q 'scrollToBottom() })), false &&' \
      "$packageRoot/node_modules/@deepseek-harness-tui/dsh-tui/lib/types/screens/Chat.js"
    grep -q 'wake: undefined' \
      "$packageRoot/node_modules/@deepseek-harness-tui/dsh-tui/lib/types/screens/Chat.js"
    grep -q 'scrollGutter: hidden' \
      "$packageRoot/node_modules/@deepseek-harness-tui/dsh-tui/cordis.patch.yml"
    grep -q "DSH_TUI_INLINE_REPAINT === '1'" \
      "$packageRoot/node_modules/@deepseek-harness-tui/dsh-tui/lib/types/ink/log-update.js"
    runHook postInstallCheck
  '';

  meta = {
    description = "DeepSeek Harness CLI with ModLens, ModSearch, routing, OpenViking integration, and a terminal TUI mode";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  };
}
