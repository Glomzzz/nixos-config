{
  pkgs,
  config,
}:
assert config.services.upower.enable && config.services.fwupd.enable;
assert config.services.upower.usePercentageForPolicy;
assert config.services.upower.percentageLow == 20;
assert config.services.upower.percentageCritical == 10;
assert config.services.upower.percentageAction == 3;
assert config.services.upower.criticalPowerAction == "Hibernate";
assert !config.services.upower.allowRiskyCriticalPowerAction;
assert config.boot.resumeDevice == (builtins.head config.swapDevices).device;
assert config.home-manager.users.glom.services.poweralertd.enable;
  pkgs.runCommand "laptop-power-check"
  {nativeBuildInputs = [pkgs.python3];}
  ''
    python3 - ${pkgs.writeText "tested-upower.conf" config.environment.etc."UPower/UPower.conf".text} <<'PY'
    import configparser
    import sys
    config = configparser.ConfigParser()
    config.read(sys.argv[1])
    policy = config["UPower"]
    assert policy.getboolean("UsePercentageForPolicy")
    assert policy["CriticalPowerAction"] == "Hibernate"
    assert policy.getint("PercentageLow") > policy.getint("PercentageCritical") > policy.getint("PercentageAction") == 3
    print("UPower thresholds, notifications, firmware tooling, and resume-device policy passed")
    PY
    touch "$out"
  ''
