# Phono for Fcitx5

[Phono](https://github.com/phono-project/phono-fcitx5-addon) provides local
neural Pinyin and Shuangpin input, with libime dictionary candidates as a
fallback. No cloud service is needed.

## Packaging and configuration

- `pkgs/phono-fcitx5-addon.nix` builds release **0.1.2** from source against the
  flake's Fcitx5 and libime. All ten upstream offline tests run during the build,
  including loading the addon in Fcitx and generating dictionary candidates.
- `pkgs/phono-core.nix` packages the upstream **0.1.1 x86_64 Linux binary SDK**
  pinned by the addon's `ci/core-sdk.json`. It includes ExecuTorch and third-party
  license notices. `autoPatchelfHook` fixes its runtime library paths for NixOS.
  The addon links to this separate store package instead of copying the SDK's
  shared library into its own output.
- `pkgs/default.nix` exposes both through the host overlay. They are also flake
  packages: `nix build --no-link .#phono-fcitx5-addon` or `.#phono-core`.
- `modules/home/desktop/fcitx5.nix` adds Phono and
  `qt6Packages.fcitx5-chinese-addons` (required punctuation/fullwidth modules)
  to Home Manager's Fcitx addon bundle. The managed profile contains `phono`
  and `phono-shuangpin`, after `keyboard-us`. Rime is not installed or configured.

Phono Pinyin is the default Chinese method, and Right Shift remains the only
Chinese/English toggle. Punctuation and fullwidth hotkeys are explicitly empty
so the new modules do not capture application shortcuts. Input-method cycling
shortcuts remain disabled; use the tray menu to select a method, or run:

```bash
fcitx5-remote -s phono
# Alternatively:
fcitx5-remote -s phono-shuangpin
```

To make Shuangpin the permanent default, change `DefaultIM=phono` to
`DefaultIM=phono-shuangpin` in the managed profile in `fcitx5.nix`; GUI profile
changes will be replaced on activation. Shuangpin defaults to Xiaohe; choose
another scheme in Phono's settings if needed.

The former Rime schemas, spelling/punctuation overrides, and deployment hook
have been removed. Existing Rime user dictionaries and generated files under
`~/.local/share/fcitx5/rime/` are left on disk, but Phono does not use them.
Home Manager removes its old managed schema links on activation.

## Download a model

Models are **not downloaded by a system rebuild**. Phono works with dictionary
candidates immediately, but neural sentence candidates require a complete v2.2
model package. Upstream offers
[W4A8](https://huggingface.co/afirelily/phonop2c_v2_2_base_w4a8_model) and
[W8A8](https://huggingface.co/afirelily/phonop2c_v2_2_base_w8a8_model).
For example, download W4A8 to a stable user-owned location:

```bash
nix shell nixpkgs#python3Packages.huggingface-hub -c hf download \
  afirelily/phonop2c_v2_2_base_w4a8_model \
  --local-dir "$HOME/.local/share/phono/models/phonop2c_v2_2_base_w4a8_model"
```

After deploying with `just deploy`, log out and back in, or restart the managed
Fcitx daemon with `systemctl --user restart fcitx5-daemon`. Open
`fcitx5-configtool`, select Phono, and open its settings. Set **Model package
directory** to the absolute download directory (expand `$HOME` yourself) and
leave **Enable Phono model** enabled. The directory must directly contain
`config.json`, `bins/`, and `vocabs/`; do not point to the parent directory.
Save settings and select Phono from the tray menu.

`~/.config/fcitx5/conf/phono.conf` is deliberately not managed by Home Manager,
so the model path and tuning can be saved from the GUI. User dictionaries and
history live under `~/.local/share/fcitx5/phono/`, separate from Rime's data;
XDG directory overrides are respected. Phono can read text before the cursor
for local context-aware inference; disable **Use surrounding text from
applications** in its settings if undesired.

## Verification

```bash
nix build --no-link .#phono-fcitx5-addon
nix build --no-link .#checks.x86_64-linux.fcitx5
```

The configuration check verifies the profile, both Phono input-method entries,
loads the installed Phono/punctuation/fullwidth shared libraries from the final
Fcitx bundle, checks that Rime and its deployment/configuration are absent, and
checks that the managed addon hotkeys remain empty. Offline
checks do not exercise model inference or a live Wayland application; test
those interactively after downloading a model and deploying.

When updating the addon, check its `ci/core-sdk.json` for a required SDK version
change and update both fixed-output hashes as necessary.
