# Plannotator (`plannotator`): visual plan and code review for coding agents. Installed
# on every profile that imports the shared dev modules.
{pkgs, ...}: {
  home.packages = [pkgs.plannotator];
}
