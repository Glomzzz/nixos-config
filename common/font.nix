{ pkgs, ...} : {
     fonts = {
      packages = with pkgs; [
        material-design-icons
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
        liberation_ttf
        fira-code
        fira-code-symbols
        mplus-outline-fonts.githubRelease
        dina-font
        proggyfonts
        nerd-fonts.fira-code
        nerd-fonts.jetbrains-mono
        wqy_zenhei # WenQuanYi Zen Hei
      ];
      enableDefaultPackages = false;

      # user defined fonts
      # the reason there's Noto Color Emoji everywhere is to override DejaVu's
      # B&W emojis that would sometimes show instead of some Color emojis
      fontconfig = {
        antialias = true;
        hinting.enable = true;
        defaultFonts = { 
          emoji = [ "Noto Color Emoji" ];
          monospace = [ "FiraCode Nerd Font" ];
          sansSerif = [ "Noto Sans CJK SC" ];
          serif = [ "Noto Serif CJK SC" ];
      };
      };
   };
}
