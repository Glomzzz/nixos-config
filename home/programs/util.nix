{pkgs,system,...} : {
    home.packages = with pkgs; [
     usbutils
     yq-go # https://github.com/mikefarah/yq
  ];
}