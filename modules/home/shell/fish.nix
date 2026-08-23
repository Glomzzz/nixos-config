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
    functions.dsh-web = {
      description = "Open the DeepSeek Harness web GUI, starting it detached if needed";
      body = ''
        set -l port 3080
        set -l url "http://127.0.0.1:$port"
        if command -v curl >/dev/null 2>&1; and curl -sf --max-time 1 "$url" >/dev/null 2>&1
          echo "DeepSeek Harness web GUI is already running at $url" >&2
        else
          set -l logdir "$HOME/.local/state/dsh"
          mkdir -p "$logdir"
          nohup dsh web --no-open >"$logdir/web.log" 2>&1 &
          echo "starting DeepSeek Harness web GUI at $url (log: $logdir/web.log)" >&2
          for i in (seq 1 60)
            if command -v curl >/dev/null 2>&1; and curl -sf --max-time 1 "$url" >/dev/null 2>&1
              break
            end
            sleep 1
          end
          if not command -v curl >/dev/null 2>&1; or not curl -sf --max-time 1 "$url" >/dev/null 2>&1
            echo "dsh web failed to come up; last log lines:" >&2
            tail -20 "$logdir/web.log" 2>/dev/null >&2
            return 1
          end
        end
        if set -q WAYLAND_DISPLAY; or set -q DISPLAY
          command xdg-open "$url" >/dev/null 2>&1 &
        else
          echo "$url"
        end
      '';
    };
    completions."dsh.fish" = ''
      # DeepSeek Harness CLI: profile boot, plugin management, browser UI
      complete -c dsh -f
      complete -c dsh -s V -l version -d 'Output the version number'
      complete -c dsh -l profile -x -a 'web dsh-tui' -d 'The profile under $DSH_HOME/profiles to boot'
      complete -c dsh -l patch -r -F -d 'Extra patch-list overlay applied after the profile layer'
      complete -c dsh -l dump-config -d 'Print the composed profile tree and exit'
      complete -c dsh -l dump-default-config -d 'Print the bundle layers without the user layer'
      complete -c dsh -n '__fish_use_subcommand' -a web -d 'Boot the web profile (browser UI)'
      complete -c dsh -n '__fish_use_subcommand' -a plugin -d "Manage a profile's plugins via pnpm"
      complete -c dsh -n '__fish_seen_subcommand_from web' -l host -x -d 'Bind host'
      complete -c dsh -n '__fish_seen_subcommand_from web' -l port -x -d 'Listen port (0 lets the OS pick)'
      complete -c dsh -n '__fish_seen_subcommand_from web' -l no-open -d 'Do not open the browser'
      complete -c dsh -n '__fish_seen_subcommand_from web' -l trusted-host -x -d 'Extra browser-trust authority'
      complete -c dsh -n '__fish_seen_subcommand_from plugin' -l profile -x -a 'web dsh-tui' -d 'Profile whose plugins to manage'
    '';
    completions."dsh-tui.fish" = ''
      # DeepSeek Harness TUI (terminal front door)
      complete -c dsh-tui -f
      complete -c dsh-tui -l resume -x -a '(__fish_dsh_sessions)' -d 'Resume the most recent session, or the given session id'
      complete -c dsh-tui -s c -l continue -d 'Resume the most recent session'
      complete -c dsh-tui -a '(__fish_dsh_workspaces)' -d 'Workspace directory target'
    '';
    functions.__fish_dsh_sessions = {
      description = "Suggest DeepSeek Harness session ids for completion";
      body = ''
        set -l sessions "$HOME/.dsh/sessions"
        if test -d "$sessions"
          command find "$sessions" -maxdepth 1 -type d -name '--*' -printf '%f\n' 2>/dev/null
        end
      '';
    };
    functions.__fish_dsh_workspaces = {
      description = "Suggest workspace directories for the DeepSeek Harness TUI";
      body = ''
        command find . -maxdepth 1 -type d -not -name '.*' -printf '%f\n' 2>/dev/null
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
