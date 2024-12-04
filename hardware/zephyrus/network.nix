{  ... }:

{
  services.printing.enable = true;
  # Network
  networking = {
    networkmanager.enable = true;
    useDHCP = true;
  };
}
