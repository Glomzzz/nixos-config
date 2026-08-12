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
    # Keep the established account identity stable for user services and files.
    uid = 1000;
    shell = pkgs.fish;
    extraGroups = [
      "dialout"
      "networkmanager"
      "wheel"
    ];
  };
}
