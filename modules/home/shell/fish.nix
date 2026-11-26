{
  config,
  pkgs,
  ...
}: let
  emc = "${config.home.homeDirectory}/.local/bin/emc";
in {
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
    functions = {
      ssh = {
        description = "OpenSSH client with a POSIX SHELL for the remote session";
        wraps = "ssh";
        body = ''
          set --local --export SHELL ${pkgs.runtimeShell}
          command ssh $argv
        '';
      };

      # Antigravity CLI through the loopback listener on 127.0.0.1:20174 (mihomo base.nix),
      # which routes to vless-sg via vless-hk. Only this command gets the proxy variables.
      agy = {
        description = "Antigravity CLI through the mihomo Singapore listener";
        wraps = "agy";
        body = ''
          set --local --export HTTPS_PROXY http://127.0.0.1:20174
          set --local --export HTTP_PROXY http://127.0.0.1:20174
          command agy $argv
        '';
      };

      # Win+; and Win+' (niri/settings.nix) run these through fish, since niri
      # spawns argv directly. Each opens a new GUI frame and returns at once.
      # emc/open-calc waits 0.3 s for a brand-new frame to settle; emc/open-mail
      # shows mu4e at once and falls back to the whole window if the frame refuses
      # to split (both in modules/core/emc.el).
      calc = {
        description = "Open Emacs calc in a new GUI frame";
        body = ''
          ${emc} --create-frame --no-wait --eval '(emc/open-calc)'
        '';
      };
      email = {
        description = "Open Emacs mu4e mail in a new GUI frame";
        body = ''
          ${emc} --create-frame --no-wait --eval '(emc/open-mail)'
        '';
      };
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
