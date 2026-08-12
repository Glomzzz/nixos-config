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
        inherit email;
      };
      core = {
        editor = "emacsclient -c -a emacs";
      };
    };
  };
}
