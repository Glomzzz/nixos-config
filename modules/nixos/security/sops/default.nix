{
  hostname,
  inputs,
  secretFiles,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./tailscale.nix
    ./yubikey-pin.nix
  ];

  sops = {
    defaultSopsFile = secretFiles.hosts.${hostname};
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  };
}
