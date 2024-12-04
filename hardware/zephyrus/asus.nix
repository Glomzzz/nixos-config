{ ... }:

{
  # ASUS 
  services.asusd = {
    enable = true;
    enableUserService = true;
  };
  # # SuperGXD https://wiki.archlinux.org/title/Supergfxctl
  # services.supergfxd.enable = true;
  # systemd.services.supergfxd.path = [ pkgs.pciutils ];

}
