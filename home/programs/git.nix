{pkgs, usernameFull, email, ...}: {
  home.packages = [pkgs.gh];

  programs.git = {
    enable = true;
    userName = usernameFull;
    userEmail = email;
  };
}
