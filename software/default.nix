{...} :
{
  imports = [
    ./dev_env.nix
    ./editor.nix
    ./shell.nix
    ./graphic.nix
    ./network.nix
    ./shell.nix
    ./social.nix
  ];
  nixpkgs.config.allowUnfree = true;
}