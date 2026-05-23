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
      core = {
        editor = "emacsclient -c -a emacs";
      };
    };
  };

  programs.lazygit = {
    enable = true;
  };
}
