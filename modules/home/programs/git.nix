{
  pkgs,
  usernameFull,
  email,
  ...
}: {
  home.packages = [pkgs.gh];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = usernameFull;
        email = email;
      };
    };
  };

  programs.lazygit = {
    enable = true;
  };
}
