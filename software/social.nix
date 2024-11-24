{pkgs, ...} : {
  environment.systemPackages = with pkgs; [
     fluffychat
     thunderbird
     qq
  ];
  nixpkgs.config.permittedInsecurePackages = [
    "fluffychat-linux-1.20.0"
    "olm-3.2.16"
    "openssl-1.1.1w"
  ];

}
