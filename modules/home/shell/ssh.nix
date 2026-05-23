{...}: {
  programs.ssh = {
    enable = true;
    settings = {
      macmini = {
        hostname = "mac-mini";
        serverAliveInterval = 30;
        serverAliveCountMax = 3;
      };
    };
  };
}
