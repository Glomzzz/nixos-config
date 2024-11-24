{pkgs, ...} : {
    environment.systemPackages = with pkgs; [
     zotero
     usbutils
  ];
}