
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # graalpy
    # trufflerruby
    # graalnodejs
    # graaljs
    #    javaPackages.compiler.openjdk21
    graalvmPackages.graalvm-oracle

  ];
}
