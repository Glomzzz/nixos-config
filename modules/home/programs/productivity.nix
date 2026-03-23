{pkgs, ...}: {
  home.packages = with pkgs; [
    zotero
    cherry-studio
    anydesk
  ];
}
