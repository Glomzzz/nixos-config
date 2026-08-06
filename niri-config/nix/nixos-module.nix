{self}: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.clavis-shell;
  defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  options.services.clavis-shell = {
    enable = lib.mkEnableOption "the Clavis Shell Niri desktop";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "niri-config.packages.\${pkgs.system}.default";
      description = "Wrapped Clavis Shell package to install system-wide.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.niri = {
      enable = true;
      useNautilus = lib.mkDefault false;
    };

    services = {
      displayManager.defaultSession = lib.mkDefault "niri";
      power-profiles-daemon.enable = lib.mkDefault true;
      upower.enable = lib.mkDefault true;
    };

    environment.systemPackages = [cfg.package];

    fonts.packages = with pkgs; [
      lxgw-wenkai-screen
      material-symbols
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
    ];
  };
}
