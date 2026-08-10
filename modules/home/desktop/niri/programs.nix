{pkgs, ...}: {
  # Viewers and daemons that KDE used to supply. Each entry here replaces a
  # Plasma component rather than adding something new.
  programs = {
    # yazi is both the TUI file manager and the GUI-less replacement for nemo.
    # Image previews come from foot's native sixel support, which yazi detects
    # on its own - no ueberzugpp overlay, which never worked under niri anyway
    # (yazi only whitelists Sway/Hyprland/Wayfire for its Wayland adapter).
    yazi = {
      enable = true;
      enableNushellIntegration = true;

      settings = {
        mgr = {
          show_hidden = false;
          sort_by = "natural";
          sort_dir_first = true;
        };

        preview = {
          # Sixel is sized in pixels; these bounds keep previews sharp without
          # pushing huge payloads through the pty on every cursor move.
          max_width = 1200;
          max_height = 1200;
          image_quality = 90;
        };

        # yazi's preset `edit` opener is `${EDITOR:-vi} %s` with block = true,
        # which assumes a terminal editor that owns the pty until it exits.
        # emacs-pgtk is a GUI client, so blocking would freeze yazi behind a
        # window it does not draw. orphan = true detaches the child into its own
        # session instead, leaving yazi interactive.
        #
        # The store path is spelled out rather than relying on $EDITOR (set in
        # programs/dev/editor/emacs.nix): openers run through `sh -c` from
        # whatever environment launched yazi, which for the niri keybind in
        # settings.nix is not a login shell and so has no EDITOR at all.
        #
        # -c makes a new frame, and -a emacs falls back to a standalone emacs
        # when no daemon is listening - this session runs none.
        opener.edit = [
          {
            run = "${pkgs.emacs-pgtk}/bin/emacsclient -c -a ${pkgs.emacs-pgtk}/bin/emacs %s";
            desc = "emacs";
            block = false;
            orphan = true;
            "for" = "unix";
          }
        ];
      };

      # <Enter> on a directory descends into it instead of handing it to the
      # editor, and <S-Enter> is what opens a directory in emacs (dired).
      #
      # This cannot be expressed as a plain action list: yazi runs a chord's
      # `run` array as an unconditional sequence, so [ "enter", "open" ] would
      # descend into the directory and then immediately open whichever file the
      # cursor landed on inside it. The branch has to happen before either
      # action is emitted, which means a sync plugin that can read the hovered
      # file's Cha.
      plugins.smart-enter = pkgs.writeTextDir "main.lua" ''
        --- @sync entry
        return {
        	entry = function()
        		local h = cx.active.current.hovered
        		if h and h.cha.is_dir then
        			ya.emit("enter", {})
        		else
        			ya.emit("open", { hovered = true })
        		end
        	end,
        }
      '';

      keymap.mgr.prepend_keymap = [
        {
          on = "<Enter>";
          run = "plugin smart-enter";
          desc = "Enter the directory, or open the file";
        }
        {
          on = "<S-Enter>";
          run = "open --hovered";
          desc = "Open the hovered file or directory in emacs";
        }
        # The mac-mini's home directory over SMB. The mount is an idle-timeout
        # automount (modules/services/nixos/smb.nix), so the first `gm` after a
        # while pauses briefly while the kernel dials out, and the share
        # unmounts itself once yazi leaves it alone for ten minutes.
        {
          on = ["g" "m"];
          run = "cd /mnt/mac-mini";
          desc = "Go to mac-mini (SMB)";
        }
        # Drag the selection out to GUI apps (Firefox upload targets, chat
        # windows). A TUI cannot be a Wayland drag source at all - the drag has
        # to originate from a real wl_data_device - so ripdrag stands in as a
        # small GTK4 window holding the files, and the drag starts from there.
        #
        # yazi 26.5.6 does have native drag-and-drop, but it rides the terminal
        # DnD escape protocol that only kitty implements; foot does not, so that
        # path is unavailable here and ripdrag is the working option.
        #
        # %s is yazi's own shell formatting and expands to the selection, or to
        # the hovered file when nothing is selected (Mgr::selected is backed by
        # selected_or_hovered), with each path escaped by yazi. The older `"$@"`
        # spelling seen in most recipes online is deprecated and already gone
        # from yazi's git main, so it is deliberately avoided.
        #
        # -x closes the window after one successful drag, so the window is not
        # left behind. orphan detaches it from yazi's task lifetime the way the
        # editor opener above does; without block yazi stays interactive while
        # the drag is in progress.
        {
          on = "<C-n>";
          run = "shell --orphan -- ${pkgs.ripdrag}/bin/ripdrag -x %s";
          desc = "Drag the selection out (ripdrag)";
        }
      ];
    };

    # PDF viewer. zathura's own config lives here rather than a dotfile.
    zathura = {
      enable = true;
      options = {
        selection-clipboard = "clipboard";
        adjust-open = "width";
        guioptions = "";

        # Catppuccin Mocha, matching the rest of the session.
        default-bg = "#1e1e2e";
        default-fg = "#cdd6f4";
        statusbar-bg = "#181825";
        statusbar-fg = "#cdd6f4";
        inputbar-bg = "#1e1e2e";
        inputbar-fg = "#cdd6f4";
        highlight-color = "#f9e2af";
        highlight-active-color = "#89b4fa";
        recolor-lightcolor = "#1e1e2e";
        recolor-darkcolor = "#cdd6f4";
      };
    };

    # Video player, replacing vlc.
    mpv = {
      enable = true;
      config = {
        hwdec = "auto-safe";
        vo = "gpu-next";
        gpu-api = "vulkan";
        profile = "high-quality";
        keep-open = true;
      };
    };
  };

  home.packages = with pkgs; [
    # X11 shim so Steam/Discord/JetBrains keep working under niri.
    xwayland-satellite

    # Region select -> annotate -> save/clipboard. niri's own `screenshot`
    # action saves straight to disk with no editing step, so satty needs its
    # own path in. Bound to Mod+Shift+S in settings.nix.
    # niri spawns commands with a minimal environment, so coreutils is
    # referenced by store path rather than assumed to be on PATH.
    (writeShellScriptBin "screenshot-annotate" ''
      set -euo pipefail
      out="$HOME/Pictures/Screenshots"
      ${coreutils}/bin/mkdir -p "$out"
      stamp=$(${coreutils}/bin/date '+%Y%m%dT%H%M%S')
      ${grim}/bin/grim -g "$(${slurp}/bin/slurp -d)" -t ppm - \
        | ${satty}/bin/satty \
            --filename - \
            --fullscreen \
            --early-exit \
            --copy-command ${wl-clipboard}/bin/wl-copy \
            --output-filename "$out/satty-$stamp.png"
    '')
    satty
    grim
    slurp

    # Screen recording.
    wl-screenrec
    # wl-copy / wl-paste. cliphist depends on this.
    wl-clipboard

    # Image viewer, replacing loupe.
    oculante

    # Wayland drag source for yazi's <C-n> bind above. Also useful on its own:
    # `ripdrag -t` accepts drops from GUI apps and prints the paths.
    ripdrag

    # GUI/TUI control panels that replace the Plasma applets.
    overskride # Bluetooth
    wiremix # audio mixer
    # nmtui, not impala, for wifi: impala is an iwd front end and talks to
    # net.connman.iwd over D-Bus, but this host manages wifi with
    # NetworkManager over wpa_supplicant (modules/nixos/core/networking.nix,
    # wifi.backend=wpa_supplicant) and iwd is not installed at all. With no
    # iwd on the bus impala panics on startup instead of reporting the
    # missing backend, which is why clicking the netspeed module appeared to
    # do nothing. nmtui ships in the same networkmanager package the daemon
    # comes from, so the TUI and the daemon can never drift apart.
    networkmanager # nmtui, wifi
    # gnome-keyring front end (replaces kwalletmanager). Needed to change the
    # login keyring's own password, which is stored inside the keyring file and
    # so cannot be set declaratively. See modules/nixos/desktop/autologin.nix.
    seahorse

    # Hardware keys wired up in settings.nix.
    brightnessctl
    playerctl
  ];
}
