{
  config,
  pkgs,
  ...
}: {
  # If u meet error when switch:
  # journalctl -xe -u home-manager-<your-username>.service
  # check if there are file that already exist, if so, try to remove it
  xdg = {
    enable = true; # Enable XDG
    userDirs.enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = ["com.google.Chrome.beta.desktop"];
        "x-scheme-handler/http" = ["com.google.Chrome.beta.desktop"];
        "x-scheme-handler/https" = ["com.google.Chrome.beta.desktop"];
      };
    };
  };
  home.packages = with pkgs; [
    xdg-utils
    handlr
  ];
}
