# Hardware profile table. Each profile is a directory under hardware/ that
# provides a complete machine description. `select` is pure so the matching
# rules can be tested with fake DMI values; hardware/default.nix supplies the
# real values from /sys/class/dmi/id.
let
  profiles = {
    zephyrus = {
      # ASUS Zephyrus G16 (GU605MY). Not verified on this repository's laptop
      # from this machine; if the laptop reports another product_name, add it
      # here or the evaluation fails with the detected values.
      sysVendor = "ASUSTeK COMPUTER INC.";
      productName = ".*GU605.*";
    };
  };

  matches = dmi: spec:
    builtins.match spec.sysVendor dmi.sysVendor
    != null
    && builtins.match spec.productName dmi.productName != null;
in {
  inherit profiles;

  select = dmi: let
    found = builtins.filter (name: matches dmi profiles.${name}) (builtins.attrNames profiles);
  in
    if found == []
    then throw "hardware: no profile matches sys_vendor='${dmi.sysVendor}' product_name='${dmi.productName}'. Add a match to hardware/profiles.nix."
    else if builtins.length found > 1
    then throw "hardware: several profiles match sys_vendor='${dmi.sysVendor}' product_name='${dmi.productName}': ${builtins.concatStringsSep ", " found}"
    else builtins.head found;
}
