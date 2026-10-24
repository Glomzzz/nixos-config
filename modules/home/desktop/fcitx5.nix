{
  lib,
  pkgs,
  ...
}: let
  # Explicit PNGs avoid procedural-background rendering differences in bundled
  # Qt clients such as WeChat. Keep one solid pixel inside the two-pixel border
  # before the stretchable center starts (Background/Margin=3 below).
  themeBackgrounds =
    pkgs.runCommand "fcitx5-catppuccin-backgrounds" {
      nativeBuildInputs = [pkgs.imagemagick];
    } ''
      mkdir -p "$out"
      magick -size 32x32 xc:'#1e1e2e' -bordercolor '#89b4fa' -border 2 \
        -strip PNG32:"$out/input-panel.png"
      magick -size 32x32 xc:'#1e1e2e' -bordercolor '#45475a' -border 2 \
        -strip PNG32:"$out/menu.png"
    '';
in {
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      # Home Manager owns startup; do not also spawn a daemon from niri.
      systemd.enable = true;
      addons = with pkgs; [
        phono-fcitx5-addon
        # Phono uses the native punctuation and fullwidth modules.
        qt6Packages.fcitx5-chinese-addons
        fcitx5-gtk
        qt6Packages.fcitx5-configtool
        # Qt IM modules, needed so Qt apps get a working preedit. Spelled via
        # qt6Packages/libsForQt5 rather than kdePackages: it is the identical
        # derivation, but the kdePackages alias reads like a leftover KDE
        # dependency now that Plasma is gone.
        qt6Packages.fcitx5-qt
        libsForQt5.fcitx5-qt
      ];
    };
  };

  systemd.user.services.fcitx5-daemon.Service.Restart = "on-failure";

  xdg = {
    configFile = {
      # niri-session also runs XDG autostart. Mask the package's desktop entry
      # so it cannot race the dedicated fcitx5-daemon.service.
      "autostart/org.fcitx.Fcitx5.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Fcitx 5
        Hidden=true
      '';

      "fcitx5/profile" = {
        force = true;
        text = ''
          [Groups/0]
          # Group Name
          Name=Default
          # Layout
          Default Layout=us
          # Default Input Method
          DefaultIM=phono

          [Groups/0/Items/0]
          # Name
          Name=keyboard-us
          # Layout
          Layout=

          [Groups/0/Items/1]
          Name=phono
          Layout=

          [Groups/0/Items/2]
          Name=phono-shuangpin
          Layout=

          [GroupOrder]
          0=Default
        '';
      };

      # Classic UI and Qt's client-side candidate windows share this theme.
      # The bundled default is light even in a dark session; pin the palette
      # explicitly rather than relying on a client or portal's dark preference.
      #
      # Theme is pinned to the Catppuccin Mocha theme written below rather than
      # to the bundled "default-dark", because default-dark is pure #000000 with
      # grey borders and would not match foot/waybar/swaync/Thunar.
      #
      # UseDarkTheme is deliberately left False. When True, classicui swaps
      # between Theme and DarkTheme based on the XDG portal's
      # org.freedesktop.appearance color-scheme, and only the exact value 1
      # (prefer-dark) counts as dark - a portal that answers 0/no-preference
      # would silently put the light theme back. Since this session is
      # unconditionally dark, naming the dark theme directly cannot regress.
      # DarkTheme is still set to the same theme so that flipping UseDarkTheme
      # on later stays correct.
      "fcitx5/conf/classicui.conf" = {
        force = true;
        text = ''
          # Vertical Candidate List
          Vertical Candidate List=False
          # Use mouse wheel to go to prev or next page
          WheelForPaging=True
          # Font
          Font="Noto Sans CJK SC 11"
          # Menu Font
          MenuFont="Noto Sans CJK SC 11"
          # Tray Font
          TrayFont="Noto Sans CJK SC Bold 10"
          # Tray Label Outline Color
          TrayOutlineColor=#000000
          # Tray Label Text Color
          TrayTextColor=#ffffff
          # Prefer Text Icon
          PreferTextIcon=False
          # Show Layout Name In Icon
          ShowLayoutNameInIcon=True
          # Use input method language to display text
          UseInputMethodLanguageToDisplayText=True
          # Theme
          Theme=catppuccin-mocha
          # Dark Theme
          DarkTheme=catppuccin-mocha
          # Follow system light/dark color scheme
          UseDarkTheme=False
          # Follow system accent color if it is supported by theme and desktop
          UseAccentColor=False
          # Use Per Screen DPI on X11
          PerScreenDPI=False
          # Force font DPI on Wayland
          ForceWaylandDPI=0
          # Enable fractional scale under Wayland
          EnableFractionalScale=True
        '';
      };

      # Optional addon shortcuts steal Emacs bindings even in keyboard-us.
      # Keep the addons available, but make their actions menu-only.
      "fcitx5/conf/clipboard.conf" = {
        force = true;
        text = ''
          # Leave Ctrl+semicolon to applications.
          TriggerKey=
          PastePrimaryKey=
        '';
      };

      "fcitx5/conf/keyboard.conf" = {
        force = true;
        text = ''
          Hint Trigger=
          One Time Hint Trigger=
        '';
      };

      "fcitx5/conf/quickphrase.conf" = {
        force = true;
        text = ''
          TriggerKey=
        '';
      };

      "fcitx5/conf/unicode.conf" = {
        force = true;
        text = ''
          TriggerKey=
          DirectUnicodeMode=
        '';
      };

      # Phono's native modules must not introduce Ctrl+. or width toggles.
      "fcitx5/conf/punctuation.conf" = {
        force = true;
        text = ''
          Hotkey=
        '';
      };

      "fcitx5/conf/fullwidth.conf" = {
        force = true;
        text = ''
          Hotkey=
        '';
      };

      "fcitx5/config" = {
        force = true;
        text = ''
          [Hotkey]
          # Enumerate when holding modifier of Toggle key
          EnumerateWithTriggerKeys=False
          # Enumerate Input Method Forward
          EnumerateForwardKeys=
          # Enumerate Input Method Backward
          EnumerateBackwardKeys=
          # Skip first input method while enumerating
          EnumerateSkipFirst=False
          # Time limit in milliseconds for triggering modifier key shortcuts
          ModifierOnlyKeyTimeout=250

          # Right Shift is the only toggle; leave Ctrl/Alt chords to Emacs.
          [Hotkey/TriggerKeys]
          0=Shift+Shift_R

          [Hotkey/ActivateKeys]

          [Hotkey/DeactivateKeys]

          [Hotkey/AltTriggerKeys]

          [Hotkey/EnumerateGroupForwardKeys]

          [Hotkey/EnumerateGroupBackwardKeys]

          [Hotkey/PrevPage]
          0=Up

          [Hotkey/NextPage]
          0=Down

          [Hotkey/PrevCandidate]
          0=Shift+Tab

          [Hotkey/NextCandidate]
          0=Tab

          # Leave Ctrl+Alt+P to applications.
          [Hotkey/TogglePreedit]

          [Behavior]
          # Active By Default
          ActiveByDefault=False
          # Reset state on Focus In
          resetStateWhenFocusIn=No
          # Share Input State
          ShareInputState=No
          # Show preedit in application
          PreeditEnabledByDefault=True
          # Show Input Method Information when switch input method
          ShowInputMethodInformation=True
          # Show Input Method Information when changing focus
          showInputMethodInformationWhenFocusIn=False
          # Show compact input method information
          CompactInputMethodInformation=True
          # Show first input method information
          ShowFirstInputMethodInformation=True
          # Default page size
          DefaultPageSize=5
          # Override XKB Option
          OverrideXkbOption=False
          # Custom XKB Option
          CustomXkbOption=
          # Force Enabled Addons
          EnabledAddons=
          # Force Disabled Addons=
          DisabledAddons=
          # Preload input method to be used by default
          PreloadInputMethod=True
          # Allow input method in the password field
          AllowInputMethodForPassword=False
          # Show preedit text when typing password
          ShowPreeditForPassword=False
          # Interval of saving user data in minutes
          AutoSavePeriod=30
        '';
      };
    };

    dataFile = {
      # User punctuation profiles replace the whole table, so preserve upstream
      # mappings and change only the Chinese full stop to U+FF0E.
      "fcitx5/punctuation/punc.mb.zh_CN" = {
        force = true;
        source = pkgs.runCommand "fcitx5-punctuation-zh_CN" {} ''
          substitute ${pkgs.qt6Packages.fcitx5-chinese-addons}/share/fcitx5/punctuation/punc.mb.zh_CN "$out" \
            --replace-fail '. 。' '. ．'
        '';
      };

      # Catppuccin Mocha theme for the candidate window, selected by
      # conf/classicui.conf above.
      #
      # This has to be a NEW theme name rather than a patch of the bundled
      # "default-dark": classicui treats exactly the two names "default" and
      # "default-dark" as system themes and reads those only from the package's
      # own share/fcitx5/themes, ignoring ~/.local/share/fcitx5/themes entirely.
      # Any other name is looked up in the user directory, which is what makes
      # this file take effect.
      #
      # Colours are the same Mocha values used in waybar/swaync/foot: base
      # #1e1e2e for backgrounds, text #cdd6f4, surface0 #45475a for the selected
      # candidate, blue #89b4fa for the border, matching niri's focus ring.
      "fcitx5/themes/catppuccin-mocha/theme.conf" = {
        force = true;
        text = ''
          [Metadata]
          Name=Catppuccin Mocha
          Version=1
          Author=local
          Description=Catppuccin Mocha, matching foot/waybar/swaync
          ScaleWithDPI=True

          [InputPanel]
          NormalColor=#cdd6f4
          HighlightCandidateColor=#1e1e2e
          HighlightColor=#1e1e2e
          HighlightBackgroundColor=#89b4fa
          PageButtonAlignment=Last Candidate

          [InputPanel/TextMargin]
          Left=6
          Right=6
          Top=5
          Bottom=5

          [InputPanel/ContentMargin]
          Left=3
          Right=3
          Top=3
          Bottom=3

          [InputPanel/Background]
          Image=input-panel.png
          Color=#1e1e2e
          BorderColor=#89b4fa
          BorderWidth=2

          [InputPanel/Background/Margin]
          Left=3
          Right=3
          Top=3
          Bottom=3

          [InputPanel/Highlight]
          Color=#89b4fa

          [InputPanel/Highlight/Margin]
          Left=5
          Right=5
          Top=5
          Bottom=5

          [InputPanel/PrevPage]
          Image=prev.png

          [InputPanel/PrevPage/ClickMargin]
          Left=5
          Right=5
          Top=4
          Bottom=4

          [InputPanel/NextPage]
          Image=next.png

          [InputPanel/NextPage/ClickMargin]
          Left=5
          Right=5
          Top=4
          Bottom=4

          [Menu]
          NormalColor=#cdd6f4
          HighlightCandidateColor=#1e1e2e

          [Menu/Background]
          Image=menu.png
          Color=#1e1e2e
          BorderColor=#45475a
          BorderWidth=2

          [Menu/Background/Margin]
          Left=3
          Right=3
          Top=3
          Bottom=3

          [Menu/ContentMargin]
          Left=3
          Right=3
          Top=3
          Bottom=3

          [Menu/CheckBox]
          Image=radio.png

          [Menu/SubMenu]
          Image=arrow.png

          [Menu/Highlight]
          Color=#89b4fa

          [Menu/Highlight/Margin]
          Left=5
          Right=5
          Top=5
          Bottom=5

          [Menu/Separator]
          Color=#45475a

          [Menu/TextMargin]
          Left=6
          Right=6
          Top=5
          Bottom=5
        '';
      };

      "fcitx5/themes/catppuccin-mocha/input-panel.png".source = "${themeBackgrounds}/input-panel.png";
      "fcitx5/themes/catppuccin-mocha/menu.png".source = "${themeBackgrounds}/menu.png";

      # theme.conf resolves Image= relative to its own directory, so the four
      # sprites it names have to exist alongside it. They are reused verbatim
      # from the bundled dark theme (grey glyphs on transparency, so they suit
      # any dark palette) rather than redrawn.
      "fcitx5/themes/catppuccin-mocha/prev.png".source = "${pkgs.fcitx5}/share/fcitx5/themes/default-dark/prev.png";
      "fcitx5/themes/catppuccin-mocha/next.png".source = "${pkgs.fcitx5}/share/fcitx5/themes/default-dark/next.png";
      "fcitx5/themes/catppuccin-mocha/radio.png".source = "${pkgs.fcitx5}/share/fcitx5/themes/default-dark/radio.png";
      "fcitx5/themes/catppuccin-mocha/arrow.png".source = "${pkgs.fcitx5}/share/fcitx5/themes/default-dark/arrow.png";
    };
  };

  home = {
    sessionVariables = {
      XMODIFIERS = "@im=fcitx";
      # Leave GTK_IM_MODULE unset: GTK3/4 on Wayland use text-input-v3,
      # avoiding the GTK plugin's hide/show popup repositioning flicker.
      # waylandFrontend supplies gtk-im-module=fcitx in GTK's config files
      # for X11/GTK2 apps. Foot uses text-input-v3 directly, not this variable.
      # Qt5 still needs its Fcitx plugin on niri (no text-input-v2 support).
      QT_IM_MODULE = "fcitx";
      SDL_IM_MODULE = "fcitx";
      GLFW_IM_MODULE = "ibus";
    };

    activation = {
      removeObsoleteFcitxPinyinConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
        run rm -f \
          "$HOME/.config/fcitx5/conf/pinyin.conf" \
          "$HOME/.config/fcitx5/conf/cloudpinyin.conf"
      '';
    };
  };
}
