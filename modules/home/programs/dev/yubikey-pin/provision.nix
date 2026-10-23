{
  pkgs,
  hostname,
}:
pkgs.writeShellApplication {
  name = "sops-save-yubikey-pin";
  text = ''
    exec ${pkgs.python3}/bin/python3 ${./provision.py} \
      --sops-program ${pkgs.sops}/bin/sops \
      --hostname ${pkgs.lib.escapeShellArg hostname} "$@"
  '';
}
