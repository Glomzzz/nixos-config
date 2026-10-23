{
  pkgs,
  cardSerial,
}:
pkgs.writeShellApplication {
  name = "pinentry-yubikey-sops";
  text = ''
    exec ${pkgs.python3}/bin/python3 ${./pinentry.py} \
      --fallback ${pkgs.pinentry-qt}/bin/pinentry \
      --card-serial ${pkgs.lib.escapeShellArg cardSerial} "$@"
  '';
  meta.mainProgram = "pinentry-yubikey-sops";
}
