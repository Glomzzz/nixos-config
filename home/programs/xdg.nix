{ config, pkgs, ... }:

{
  xdg = {
    enable = true; # 启用 XDG 配置
    userDirs.enable = true; # 管理用户的常用目录
  };

  # 自定义 XDG 目录
  environment.variables = {
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
    XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
  };
}