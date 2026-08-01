{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    qq
    wechat
    telegram-desktop
    mumble
    discord
    anydesk
    kdePackages.krdc
    cherry-studio-with-desktop
  ];

  home.activation.refreshKdeApplicationCache = lib.hm.dag.entryAfter ["linkGeneration"] ''
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
      run kbuildsycoca6 --noincremental
    fi
  '';
}
