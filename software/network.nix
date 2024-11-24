{pkgs, ...} :
{
  environment.systemPackages = with pkgs; [
      wget
      curl
      git
      google-chrome
      v2raya
  ];
  
}