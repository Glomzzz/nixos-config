{
  config,
  pkgs,
  ...
}: let
  emc = "${config.home.homeDirectory}/.local/bin/emc";
in {
  home.file.".local/bin/fish-completion-shell" = {
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      exec ${pkgs.fish}/bin/fish --no-config --init-command '
        set --prepend --global --export PATH ${config.programs.carapace.finalPackage}/bin
        set --prepend fish_complete_path /etc/fish/generated_completions
        set --prepend fish_complete_path /run/current-system/sw/share/fish/vendor_completions.d
        set --prepend fish_complete_path ${config.xdg.dataFile."fish/home-manager/generated_completions".source}
        set --prepend fish_complete_path ${config.home.path}/share/fish/vendor_completions.d
        ${config.programs.carapace.finalPackage}/bin/carapace _carapace fish | source
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
    # Win+; and Win+' (niri/settings.nix) run these through fish, since niri
    # spawns argv directly. Each opens a new GUI frame and returns at once.
    functions.calc = {
      description = "Open Emacs calc in a new GUI frame";
      body = ''
        ${emc} --create-frame --no-wait --eval '(calc)'
      '';
    };
    functions.email = {
      description = "Open Emacs mu4e mail in a new GUI frame";
      body = ''
        ${emc} --create-frame --no-wait --eval '(mu4e)'
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
    environment.CARAPACE_MATCH = true;
  };
}
