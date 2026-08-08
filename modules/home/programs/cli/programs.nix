_: {
  programs = {
    tmux = {
      enable = true;
      clock24 = true;
      keyMode = "vi";
      mouse = true;
      extraConfig = ''
        set -g allow-passthrough on
        set -ga update-environment TERM
        set -ga update-environment TERM_PROGRAM
      '';
    };

    bat = {
      enable = true;
      config = {
        pager = "less -FR";
      };
    };

    btop.enable = true;
    eza.enable = true;
    jq.enable = true;
    aria2.enable = true;

    skim = {
      enable = true;
      defaultCommand = "rg --files --hidden";
      changeDirWidgetOptions = [
        "--preview 'exa --icons --git --color always -T -L 3 {} | head -200'"
        "--exact"
      ];
    };
  };
}
