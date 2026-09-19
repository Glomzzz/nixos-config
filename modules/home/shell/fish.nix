{
  config,
  pkgs,
  ...
}: {
  home.file.".local/bin/fish-completion-shell" = {
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      exec ${pkgs.fish}/bin/fish --no-config --init-command '
        set --prepend --global --export PATH ${config.programs.carapace.package}/bin
        set --prepend fish_complete_path /etc/fish/generated_completions
        set --prepend fish_complete_path /run/current-system/sw/share/fish/vendor_completions.d
        set --prepend fish_complete_path ${config.xdg.dataFile."fish/home-manager/generated_completions".source}
        set --prepend fish_complete_path ${config.home.path}/share/fish/vendor_completions.d
        ${config.programs.carapace.package}/bin/carapace _carapace fish | source
      ' "$@"
    '';
  };

  programs.fish = {
    enable = true;
    package = pkgs.fish;
    generateCompletions = true;
    interactiveShellInit = ''
      set --global fish_greeting
    '';
    shellInitLast = ''
      if test "$INSIDE_EMACS" = vterm; and set --query EMACS_VTERM_PATH
        set --local vterm_fish "$EMACS_VTERM_PATH/etc/emacs-vterm.fish"
        if test -r "$vterm_fish"
          source "$vterm_fish"
        end
      end
    '';
    functions.ssh = {
      description = "OpenSSH client with a POSIX SHELL for the remote session";
      wraps = "ssh";
      body = ''
        set --local --export SHELL ${pkgs.runtimeShell}
        command ssh $argv
      '';
    };
  };

  # Carapace provides structured argument completion for a broad command set;
  # commands outside that set retain Fish's native and generated completions.
  programs.carapace = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
    ignoreCase = true;
  };
}
