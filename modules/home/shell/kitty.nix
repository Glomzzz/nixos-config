{pkgs, ...}: {
  programs.kitty = {
    enable = true;
    font = {
      name = "Cascadia Mono NF";
      package = pkgs.cascadia-code;
      size = 15;
    };
    themeFile = "Catppuccin-Mocha";
    # A new window can be launched from a session that still advertises Foot.
    environment.TERMINAL = "kitty";

    settings = {
      shell = "${pkgs.fish}/bin/fish --login --interactive";
      # Fish 4.x negotiates the kitty keyboard protocol at its prompt. Ctrl+Shift+C/V
      # would then be forwarded to fish, which does not bind them, so the clipboard
      # kitten never copies or pastes there. Keep the prompt in legacy key mode.
      env = "fish_features=no-query-term";
      linux_display_server = "wayland";
      wayland_enable_ime = true;
      scrollback_lines = 10000;
      window_padding_width = 4;
      mouse_hide_wait = -1;
      enable_audio_bell = false;
      background_opacity = "0.93";
      # Never recolor an application's low-contrast theme faces.
      text_fg_override_threshold = 0;
      allow_remote_control = false;
      clipboard_control = "write-clipboard write-primary read-clipboard-ask read-primary-ask";

      # Let Emacs receive Ctrl/Alt/Shift combinations, including Ctrl+Tab,
      # Ctrl+Shift+arrows, and Ctrl+Shift+letters. Clipboard shortcuts below
      # defer to applications that negotiate extended keyboard reporting.
      clear_all_shortcuts = true;
      kitty_mod = "ctrl+alt+shift";
    };

    keybindings = {
      "ctrl+shift+c" = "kitten clipboard.py copy";
      "ctrl+shift+v" = "kitten clipboard.py paste";
      # Explicit terminal clipboard access even in protocol-aware applications.
      "kitty_mod+c" = "copy_to_clipboard";
      "kitty_mod+v" = "paste_from_clipboard";
      "kitty_mod+equal" = "change_font_size current +1.0";
      "kitty_mod+minus" = "change_font_size current -1.0";
      "kitty_mod+0" = "change_font_size current 0";
      "kitty_mod+enter" = "new_os_window_with_cwd";
      "kitty_mod+f5" = "load_config_file";
      "kitty_mod+f6" = "debug_config";
    };

    # Match GUI Emacs' Han typography and bottom-aligned Chinese punctuation.
    # Do not map the entire Unicode range: ordinary fallback must remain free
    # to select fonts for scripts that LXGW WenKai does not cover.
    extraConfig = ''
      symbol_map U+3000-U+303F,U+3100-U+312F,U+31A0-U+31BF,U+3400-U+4DBF,U+4E00-U+9FFF,U+F900-U+FAFF,U+FF01-U+FF60,U+FFE0-U+FFE6 LXGW WenKai
      symbol_map U+1F1E6-U+1F1FF,U+1F300-U+1FAFF Noto Color Emoji
      symbol_map U+E000-U+F8FF,U+F0000-U+FFFFD Symbols Nerd Font Mono
      symbol_map U+2022,U+20E2-U+20E3,U+21AF,U+21E6-U+21F0,U+21F3,U+2218-U+2219,U+2299,U+22C4-U+22C6,U+2316,U+2318 Noto Sans Symbols 2
      symbol_map U+2324-U+2328,U+232B,U+237B,U+237D-U+237F,U+2394,U+23CE-U+23CF,U+23ED-U+23EF,U+23F1-U+23F2,U+23F4-U+2426 Noto Sans Symbols 2
      symbol_map U+2440-U+244A,U+25A0-U+25FC,U+25FF-U+2609,U+260E-U+2612,U+2616-U+2623,U+2630-U+2637,U+263C,U+2654-U+2668 Noto Sans Symbols 2
      symbol_map U+2680-U+268F,U+269E-U+26A0,U+26AC,U+26BF-U+26C3,U+26C6-U+26CD,U+26CF-U+26D3,U+26D5-U+26E1,U+2700-U+2704 Noto Sans Symbols 2
      symbol_map U+2706-U+2709,U+270C-U+271C,U+2722-U+2727,U+2729-U+274B,U+274D,U+274F-U+2752,U+2756,U+2758-U+2775,U+2794 Noto Sans Symbols 2
      symbol_map U+2798-U+27AF,U+27B1-U+27BE,U+2981,U+29BF,U+29EB,U+2B00-U+2B0D,U+2B12-U+2B1A,U+2B1D-U+2B2F,U+2B4D-U+2B4F Noto Sans Symbols 2
      symbol_map U+2B51-U+2B54,U+2B56-U+2B73,U+2B76-U+2B95,U+2B97-U+2BFD,U+2BFF,U+1F10D-U+1F10F,U+1F16D-U+1F16F,U+1F1AD Noto Sans Symbols 2
      symbol_map U+3040-U+309F,U+30A0-U+30FF,U+31F0-U+31FF Noto Sans Mono CJK JP
    '';
  };

  xdg.configFile."kitty/clipboard.py".source = ./kitty-clipboard.py;

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    lxgw-wenkai
    noto-fonts-color-emoji
    nerd-fonts.symbols-only
  ];
}
