{pkgs, ...} : {
    environment.systemPackages = with pkgs; [
     sony-headphones-client
     libldac
     spotify
  ];
}