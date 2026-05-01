{ pkgs, ... }:
{
  home.packages = with pkgs; [
    qq
    (callPackage ../../../pkgs/wechat { })
    telegram-desktop
    mumble
    discord
    anydesk
    cherry-studio
  ];

  # Add Cherry Studio to application menu
  xdg.desktopEntries.cherry-studio = {
    name = "Cherry Studio";
    genericName = "AI Chat Client";
    exec = "cherry-studio %U";
    icon = "cherry-studio";
    categories = [ "Network" "Chat" "Qt" ];
    mimeType = [ "x-scheme-handler/cherrystudio" ];
    comment = "Desktop client for LLMs and AI tools";
  };
}
