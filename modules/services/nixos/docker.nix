{username, ...}: {
  # Run the daemon in the user's systemd manager so Docker access does not
  # require membership in the root-equivalent docker group.
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  users.users.${username} = {
    autoSubUidGidRange = true;
    linger = true;
  };
}
