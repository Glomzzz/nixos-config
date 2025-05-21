{pkgs,system,...} : {
    home.packages = with pkgs; [
    typst
     usbutils
     yq-go # https://github.com/mikefarah/yq
  ];
}
