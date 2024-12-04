{ config, pkgs, ... }:

{
  xdg = {
    enable = true; # 启用 XDG 配置
    userDirs.enable = true; # 管理用户的常用目录
  };
}