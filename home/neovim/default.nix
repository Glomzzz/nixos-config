{ config, pkgs, ... }:

{
  xdg.configFile.nvim.source = ./config;
  # As default editor
  home.sessionVariables = {
    EDITOR = "nvim";
  };
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    plugins = [
      # pkgs.vimPlugins.nvim-tree-lua
      #   {
      #     plugin = pkgs.vimPlugins.vim-startify;
      #     config = "let g:startify_change_to_vcs_root = 0";
      #   }
    ];
  };
}