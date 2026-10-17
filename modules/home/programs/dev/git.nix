{
  pkgs,
  usernameFull,
  email,
  ...
}: {
  home.packages = with pkgs; [
    gh
    jujutsu
    lazyjj
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = usernameFull;
        inherit email;
      };
      core = {
        editor = "emacsclient -c --alternate-editor=${pkgs.coreutils}/bin/false";
      };
    };
  };
}
