{pkgs, ...}: {
  programs.kitty = {
    enable = true;
    font = {
      name = "Cascadia Mono NF";
      package = pkgs.cascadia-code;
      size = 16;
    };
    themeFile = "Catppuccin-Mocha";
    # A new window can be launched from a session that still advertises Foot.
    environment.TERMINAL = "kitty";

    settings = {
      shell = "${pkgs.fish}/bin/fish --login --interactive";
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
      # Ctrl+Shift+arrows, and Ctrl+Shift+letters. Terminal actions use a
      # deliberately uncommon modifier chord instead.
      clear_all_shortcuts = true;
      kitty_mod = "ctrl+alt+shift";
    };

    keybindings = {
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
    '';
  };

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    lxgw-wenkai
    noto-fonts-color-emoji
    nerd-fonts.symbols-only
  ];
}
