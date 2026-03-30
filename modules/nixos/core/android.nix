{ pkgs, username, ... }:
{
  environment.systemPackages = with pkgs; [
    android-tools
    android-studio
  ];
  users.users.${username}.extraGroups = [
    "kvm"
    "adbusers"
  ];
}
