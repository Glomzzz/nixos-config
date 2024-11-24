{pkgs, ...} :
{
  environment.systemPackages = with pkgs; [
      wget
      curl
      git
      google-chrome
  ];
  
}