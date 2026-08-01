{
  makeDesktopItem,
  symlinkJoin,
  cherry-studio,
}: let
  desktopItem = makeDesktopItem {
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
in
  symlinkJoin {
    name = "cherry-studio-with-desktop";
    paths = [
      cherry-studio
      desktopItem
    ];
    inherit (cherry-studio) meta;
  }
