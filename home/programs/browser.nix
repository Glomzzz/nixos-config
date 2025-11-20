{pkgs, ...}: {
  home.packages = with pkgs; [
    microsoft-edge
    google-chrome
  ];
  home.sessionVariables = {
    BROWSER = "microsoft-edge";
  };
}
