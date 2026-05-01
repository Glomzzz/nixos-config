{...}: {
  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
    firewall = {
      checkReversePath = "loose";
    };

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };
}
