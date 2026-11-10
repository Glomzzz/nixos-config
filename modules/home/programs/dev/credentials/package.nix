{
  pkgs,
  secretsFile,
}:
pkgs.writeShellApplication {
  name = "user-credentials";
  runtimeInputs = [pkgs.gnupg];
  text = ''
    exec ${pkgs.python3}/bin/python3 ${./credentials.py} \
      --sops-program ${pkgs.sops}/bin/sops \
      --secrets-file ${secretsFile} "$@"
  '';
}
