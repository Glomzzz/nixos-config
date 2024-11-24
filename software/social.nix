{pkgs, ...} : {
  environment.systemPackages = with pkgs; [
     fluffychat
     thunderbird
     qq
     wechat-uos
  ];
  nixpkgs.config.permittedInsecurePackages = [
    "fluffychat-linux-1.20.0"
    "olm-3.2.16"
  ];

}
