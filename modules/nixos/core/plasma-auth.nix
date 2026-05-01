{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    kdePackages.kwallet-pam
  ];
}
