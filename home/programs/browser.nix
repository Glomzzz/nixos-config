{pkgs, ...}: {
  home.packages = with pkgs.legacy-2411; [
    microsoft-edge
  ];
  home.sessionVariables = {
    BROWSER = "microsoft-edge";
  };
}
