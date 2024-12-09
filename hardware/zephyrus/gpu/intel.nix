 
{
  pkgs,
  flake-inputs,
  config,
  lib,
  ...
}:
{
  services.xserver.videoDrivers = ["i915"];

  hardware.graphics = {
    extraPackages = with pkgs; [
      vpl-gpu-rt
    ];
  };
  hardware.nvidia = {
    prime = {
      intelBusId = "PCI:0:2:0";
    };
  }
}

