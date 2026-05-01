{
  lib,
  pkgs,
  ...
}: let
  cherryStudioDesktop = pkgs.makeDesktopItem {
    name = "cherry-studio";
    desktopName = "Cherry Studio";
    genericName = "AI Chat Client";
    exec = "cherry-studio %U";
    icon = "cherry-studio";
    categories = [
      "Network"
      "Chat"
    ];
    mimeTypes = ["x-scheme-handler/cherrystudio"];
    comment = "Desktop client for LLMs and AI tools";
  };

  cherryStudioWithDesktop = pkgs.symlinkJoin {
    name = "cherry-studio-with-desktop";
    paths = [
      pkgs.cherry-studio
      cherryStudioDesktop
    ];
  };
in {
  home.packages = with pkgs; [
    qq
    (callPackage ../../../pkgs/wechat {})
    telegram-desktop
    mumble
    discord
    anydesk
    cherryStudioWithDesktop
  ];

  xdg.dataFile."applications/cherry-studio.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.5
    Name=Cherry Studio
    GenericName=AI Chat Client
    Comment=Desktop client for LLMs and AI tools
    Exec=cherry-studio %U
    Icon=cherry-studio
    Categories=Network;Chat;
    MimeType=x-scheme-handler/cherrystudio;
  '';

  home.activation.refreshKdeApplicationCache = lib.hm.dag.entryAfter ["linkGeneration"] ''
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
      run kbuildsycoca6 --noincremental
    fi
  '';
}
