{
  lib,
  pkgs,
  ...
}: {
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      rime-data
      fcitx5-rime
      fcitx5-gtk
      kdePackages.fcitx5-qt
      libsForQt5.fcitx5-qt
    ];
  };

  xdg.configFile."fcitx5/profile" = {
    force = true;
    text = ''
      [Groups/0]
      # Group Name
      Name=Default
      # Layout
      Default Layout=us
      # Default Input Method
      DefaultIM=keyboard-us

      [Groups/0/Items/0]
      # Name
      Name=keyboard-us
      # Layout
      Layout=

      [Groups/0/Items/1]
      # Name
      Name=rime
      # Layout
      Layout=

      [GroupOrder]
      0=Default
    '';
  };

  xdg.configFile."fcitx5/config" = {
    force = true;
    text = ''
      [Hotkey]
      # Enumerate when holding modifier of Toggle key
      EnumerateWithTriggerKeys=True
      # Enumerate Input Method Forward
      EnumerateForwardKeys=
      # Enumerate Input Method Backward
      EnumerateBackwardKeys=
      # Skip first input method while enumerating
      EnumerateSkipFirst=False
      # Time limit in milliseconds for triggering modifier key shortcuts
      ModifierOnlyKeyTimeout=250

      [Hotkey/TriggerKeys]
      0=Shift+Shift_R

      [Hotkey/ActivateKeys]

      [Hotkey/DeactivateKeys]

      [Hotkey/AltTriggerKeys]

      [Hotkey/EnumerateGroupForwardKeys]
      0=Super+space

      [Hotkey/EnumerateGroupBackwardKeys]
      0=Shift+Super+space

      [Hotkey/PrevPage]
      0=Up

      [Hotkey/NextPage]
      0=Down

      [Hotkey/PrevCandidate]
      0=Shift+Tab

      [Hotkey/NextCandidate]
      0=Tab

      [Hotkey/TogglePreedit]
      0=Control+Alt+P

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

  xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
    force = true;
    text = ''
      patch:
        schema_list:
          - schema: pin

        menu/page_size: 7
        switcher/caption: 〔拼〕

        ascii_composer/good_old_caps_lock: true
        ascii_composer/switch_key/Caps_Lock: clear
        ascii_composer/switch_key/Shift_L: noop
        ascii_composer/switch_key/Shift_R: noop
        ascii_composer/switch_key/Control_L: noop
        ascii_composer/switch_key/Control_R: noop

        switcher/hotkeys: []

        key_binder/bindings:
          - {accept: minus, send: Page_Up, when: has_menu}
          - {accept: equal, send: Page_Down, when: has_menu}
          - {accept: comma, send: Page_Up, when: paging}
          - {accept: period, send: Page_Down, when: has_menu}
          - {accept: Tab, send: Shift+Right, when: composing}
          - {accept: Shift+Tab, send: Shift+Left, when: composing}
          - {accept: Control+j, send: Down, when: has_menu}
          - {accept: Control+k, send: Up, when: has_menu}
    '';
  };

  xdg.dataFile."fcitx5/rime/luna_pinyin_simp.custom.yaml" = {
    force = true;
    text = ''
      patch:
        switches:
          - name: ascii_mode
            reset: 0
            states: [中文, 西文]
          - name: full_shape
            reset: 0
            states: [半角, 全角]
          - name: zh_simp
            reset: 1
            states: [简体, 简体]
          - name: ascii_punct
            reset: 0
            states: [。，, ．，]

        key_binder/bindings:
          - {accept: minus, send: Page_Up, when: has_menu}
          - {accept: equal, send: Page_Down, when: has_menu}
          - {accept: comma, send: Page_Up, when: paging}
          - {accept: period, send: Page_Down, when: has_menu}
          - {accept: Tab, send: Shift+Right, when: composing}
          - {accept: Shift+Tab, send: Shift+Left, when: composing}
          - {accept: Control+j, send: Down, when: has_menu}
          - {accept: Control+k, send: Up, when: has_menu}

        translator/enable_sentence: true
        translator/enable_user_dict: true
        translator/enable_completion: true
        translator/enable_encoder: true
        translator/encode_commit_history: true
        translator/max_phrase_length: 7
        translator/initial_quality: 1.2

        speller/algebra:
          __patch:
            - pinyin:/zh_z_bufen
            - pinyin:/en_eng_bufen
            - pinyin:/abbreviation
            - pinyin:/spelling_correction
            - pinyin:/key_correction
          __append:
            - derive/ian$/iang/
            - derive/iang$/ian/
    '';
  };

  xdg.dataFile."fcitx5/rime/pin.schema.yaml" = {
    force = true;
    text = ''
      # Rime schema
      # encoding: utf-8

      __include: luna_pinyin_simp.schema:/

      schema:
        schema_id: pin
        name: 拼
        version: "0.1"
        author:
          - 佛振 <chen.sst@gmail.com>
        description: |
          简体拼音输入。

      translator:
        prism: pin
    '';
  };

  xdg.dataFile."fcitx5/rime/punctuation.custom.yaml" = {
    force = true;
    text = ''
      patch:
        half_shape:
          "!": {commit: "!"}
          "\"": {commit: "\""}
          "#": {commit: "#"}
          "$": {commit: "$"}
          "%": {commit: "%"}
          "&": {commit: "&"}
          "'": {commit: "'"}
          "(": {commit: "("}
          ")": {commit: ")"}
          "*": {commit: "*"}
          "+": {commit: "+"}
          "/": {commit: "/"}
          ":": {commit: ":"}
          ";": {commit: ";"}
          "<": {commit: "<"}
          "=": {commit: "="}
          ">": {commit: ">"}
          "?": {commit: "?"}
          "@": {commit: "@"}
          "[": {commit: "["}
          "\\": {commit: "\\"}
          "]": {commit: "]"}
          "^": {commit: "^"}
          "_": {commit: "_"}
          "`": {commit: "`"}
          "{": {commit: "{"}
          "|": {commit: "|"}
          "}": {commit: "}"}
          "~": {commit: "~"}
    '';
  };

  home.activation.removeObsoleteFcitxPinyinConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    run rm -f \
      "$HOME/.config/fcitx5/conf/pinyin.conf" \
      "$HOME/.config/fcitx5/conf/cloudpinyin.conf" \
      "$HOME/.config/fcitx5/conf/punctuation.conf"
  '';

  home.activation.deployRimeConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    rime_data_home="''${XDG_DATA_HOME:-$HOME/.local/share}/fcitx5/rime"
    run rm -f "$rime_data_home/user.yaml"
    run rm -rf "$rime_data_home/build"
    run mkdir -p "$rime_data_home"
    run ${pkgs.librime}/bin/rime_deployer \
      --build \
      "$rime_data_home" \
      "${pkgs.rime-data}/share/rime-data" \
      "$rime_data_home/build"
  '';
}
