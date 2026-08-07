{username, ...}: {
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "dialout"
      "networkmanager"
      "wheel"
    ];
  };
}
