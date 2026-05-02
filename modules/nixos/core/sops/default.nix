{
  hostname,
  inputs,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./opencode.nix
    ./ai.nix
    ./tailscale.nix
  ];

  sops = {
    defaultSopsFile = ../../../../secrets/hosts + "/${hostname}.yaml";
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  };
}
