# Selects the hardware profile for this machine from SMBIOS (DMI) data.
#
# /sys/class/dmi is outside the flake, so evaluation must be impure:
#   nixos-rebuild build --flake .#nixos --impure
# Pure evaluation fails with Nix's "forbidden in pure evaluation mode" error
# rather than silently applying the wrong hardware.
{lib, ...}: let
  profiles = import ./profiles.nix;

  # builtins.readFile cannot read sysfs attributes: Nix sizes them as 4096
  # bytes and fails with "unexpected end-of-file". A file:// fetch reads to
  # EOF, so it returns the real value. pathExists guards missing attributes.
  readDmi = field: let
    path = "/sys/class/dmi/id/${field}";
  in
    if builtins.pathExists path
    then lib.strings.trim (builtins.readFile (builtins.fetchurl "file://${path}"))
    else "";

  selected = profiles.select {
    sysVendor = readDmi "sys_vendor";
    productName = readDmi "product_name";
  };
in {
  imports = [(./. + "/${selected}")];

  options.hardware.profile = lib.mkOption {
    type = lib.types.enum (builtins.attrNames profiles.profiles);
    readOnly = true;
    description = "Hardware profile selected from DMI data (see hardware/profiles.nix).";
  };

  config.hardware.profile = selected;
}
