
{ pkgs, ... }: {
  environment.systemPackages = with pkgs.graalvmPackages; [
    # graalpy
    # trufflerruby
    # graalnodejs
    graaljs
    graalvm-oracle
  ];
}
