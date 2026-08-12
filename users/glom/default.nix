{
  pkgs,
  username,
  ...
}: {
  programs.fish = {
    enable = true;
    generateCompletions = true;
  };

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    # Pinned because modules/services/nixos/smb.nix needs it at eval time for
    # the CIFS `uid=` mount option. Left unset it is null, which renders as an
    # empty `uid=` that mount.cifs accepts and ignores. 1000 is what the
    # first-user allocation already assigned, so this is not a change.
    uid = 1000;
    shell = pkgs.fish;
    extraGroups = [
      "dialout"
      "networkmanager"
      "wheel"
    ];
  };
}
