{
  config,
  pkgs,
  usernameFull,
  email,
  ...
}: {
  home.packages = with pkgs; [
    gh
    lazyjj
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
    };
  };
}
