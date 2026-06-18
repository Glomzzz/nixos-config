{...}: {
  # ASUS
  services.asusd = {
    enable = true;
  };

  # asus-shutdown ignores SIGTERM until logind emits a real shutdown event,
  # so nixos-rebuild switch must not restart asusd or the helper itself.
  systemd.services.asusd.restartIfChanged = false;
  systemd.services."asus-shutdown" = {
    restartIfChanged = false;
    unitConfig.PartOf = "";
  };
  # # SuperGXD https://wiki.archlinux.org/title/Supergfxctl
  # services.supergfxd.enable = true;
  # systemd.services.supergfxd.path = [ pkgs.pciutils ];
}
