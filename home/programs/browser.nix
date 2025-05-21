
{
  pkgs,
  ...
}: {

  home.packages = with pkgs.legacy-2505; [
    microsoft-edge
  ];
  home.sessionVariables = {
    BROWSER = "microsoft-edge";
  };
  
}
