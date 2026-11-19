{
  config,
  pkgs,
  usernameFull,
  email,
  ...
}: {
  home.packages = with pkgs; [
    gh
  ];

  programs.jujutsu = {
    enable = true;
    ediff = false;
    settings.user = {
      name = "Glomzzz";
      inherit email;
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = usernameFull;
        inherit email;
      };
      core = {
        editor = "${config.home.homeDirectory}/.local/bin/emc";
      };
      # GitHub rejects account passwords over HTTPS. The "password" is the
      # OAuth token that `gh auth login` keeps in the credential store; gh
      # supplies it on demand and git never persists it.
      credential."https://github.com" = {
        username = "Glomzzz";
        helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
    };
  };
}
