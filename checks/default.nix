{
  self,
  pkgs,
  nixos-secrets,
}: {
  formatting =
    pkgs.runCommand "alejandra-check"
    {
      nativeBuildInputs = [pkgs.alejandra];
      src = ../.;
    }
    ''
      cd "$src"
      alejandra --check .
      touch "$out"
    '';

  dead-code =
    pkgs.runCommand "deadnix-check"
    {
      nativeBuildInputs = [pkgs.deadnix];
      src = ../.;
    }
    ''
      cd "$src"
      deadnix --fail .
      touch "$out"
    '';

  lint =
    pkgs.runCommand "statix-check"
    {
      nativeBuildInputs = [pkgs.statix];
      src = ../.;
    }
    ''
      cd "$src"
      statix check .
      touch "$out"
    '';

  firewall = import ./firewall.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
  };

  configuration-evaluation = let
    config = self.nixosConfigurations.nixos.config;
    force = value: builtins.seq value true;
    forced =
      force config.networking.firewall.backend
      && force config.networking.firewall.extraInputRules
      && force config.networking.nftables.enable
      && force config.virtualisation.docker.rootless.enable
      && force config.virtualisation.docker.rootless.setSocketVariable
      && config.virtualisation.docker.enable == false
      && !(builtins.elem "docker" config.users.users.glom.extraGroups)
      && config.nix.settings.trusted-users == ["root"]
      && config.systemd.services.v2raya.environment.V2RAYA_ADDRESS == "127.0.0.1:2017"
      && force config.services.wivrn.enable
      && force config.services.wivrn.autoStart
      && force config.services.wivrn.highPriority
      && force config.services.wivrn.openFirewall
      && force config.services.wivrn.steam.importOXRRuntimes
      && force config.services.wivrn.config.enable;
  in
    assert forced;
      pkgs.runCommand "configuration-evaluation-check" {} ''
        touch "$out"
      '';

  waybar = let
    helpers = import ../modules/home/desktop/niri/waybar/helpers.nix {inherit pkgs;};
    settings =
      pkgs.writeText "waybar-settings.json"
      (builtins.toJSON self.nixosConfigurations.nixos.config.home-manager.users.glom.programs.waybar.settings);
  in
    pkgs.runCommand "waybar-check"
    {
      nativeBuildInputs = [pkgs.bash pkgs.python3 pkgs.jq pkgs.gawk pkgs.shellcheck];
      src = ../modules/home/desktop/niri/waybar;
      # Realize every packaged helper, including writeShellApplication's
      # shellcheck validation, without launching desktop services.
      helpers = builtins.attrValues (builtins.removeAttrs helpers ["powerMenu"]);
    }
    ''
      shellcheck --shell=bash "$src"/scripts/*.sh
      python3 "$src/tests.py" ${settings}
      touch "$out"
    '';

  celluloid = import ../modules/home/programs/tests/celluloid.nix {
    inherit pkgs;
    home = self.nixosConfigurations.nixos.config.home-manager.users.glom;
  };

  seven-zip = import ../modules/home/programs/cli/tests/7zip.nix {
    inherit pkgs;
    home = self.nixosConfigurations.nixos.config.home-manager.users.glom;
  };

  emacs-terminal = import ../modules/home/shell/tests/emacs-terminal.nix {
    inherit pkgs;
    home = self.nixosConfigurations.nixos.config.home-manager.users.glom;
  };

  emacs-launchers = import ../modules/home/programs/emacs/tests/launchers.nix {
    inherit pkgs;
    home = self.nixosConfigurations.nixos.config.home-manager.users.glom;
  };

  steam-game-laptop = let
    # Exercise the production launcher with a harmless compositor stub.
    # writeShellApplication still runs shellcheck on the complete script.
    fakeGamescope = pkgs.writeShellScriptBin "gamescope" ''
      exec ${pkgs.python3}/bin/python3 ${../modules/nixos/programs/tests/steam-game-laptop.py} --capture-gamescope "$@"
    '';
    packages =
      (import ../modules/nixos/programs/steam.nix {
        pkgs = pkgs // {gamescope = fakeGamescope;};
      }).environment.systemPackages;
    launcher =
      pkgs.lib.findFirst
      (package: pkgs.lib.getName package == "steam-game-laptop")
      (throw "steam-game-laptop package not found")
      packages;
  in
    pkgs.runCommand "steam-game-laptop-check"
    {nativeBuildInputs = [pkgs.python3];}
    ''
      python3 ${../modules/nixos/programs/tests/steam-game-laptop.py} ${launcher}/bin/steam-game-laptop
      touch "$out"
    '';

  steamvr-getcap = let
    shim = self.nixosConfigurations.nixos.config.security.wrappers.getcap;
  in
    assert !shim.setuid && !shim.setgid && shim.capabilities == "";
      pkgs.runCommand "steamvr-getcap-check"
      {nativeBuildInputs = [pkgs.python3];}
      ''
        python3 - ${shim.source} ${pkgs.libcap}/bin/getcap <<'PY'
        from pathlib import Path
        import subprocess
        import sys
        import tempfile

        shim, real = sys.argv[1:]
        with open(shim, "rb") as binary:
            assert binary.read(4) == b"\x7fELF", "Wrapper targets must be native executables"
        for launcher in (
            "/tmp/SteamVR/bin/linux64/vrcompositor-launcher",
            "/tmp/path with spaces/SteamVR/bin/linux64/vrcompositor-launcher",
        ):
            result = subprocess.run([shim, launcher], capture_output=True, text=True)
            assert result.returncode == 0 and not result.stderr
            assert result.stdout == launcher + " cap_sys_nice=eip\n"
        with tempfile.TemporaryDirectory() as directory:
            plain = Path(directory) / "plain-file"
            plain.write_text("No capabilities")
            for args in (
                [], ["-h"], [str(plain)], ["-v", str(plain)],
                ["-r", directory],
                [directory + "/SteamVR/bin/linux64/vrcompositor-launcher-other"],
            ):
                expected = subprocess.run([real, *args], capture_output=True)
                actual = subprocess.run([shim, *args], capture_output=True)
                assert (actual.returncode, actual.stdout, actual.stderr) == (
                    expected.returncode, expected.stdout, expected.stderr
                ), args
        print("Native, unprivileged SteamVR getcap shim and delegation passed")
        PY
        touch "$out"
      '';

  fcitx5 = let
    home = self.nixosConfigurations.nixos.config.home-manager.users.glom;
    settings = pkgs.writeText "fcitx5-settings.json" (builtins.toJSON {
      inherit (home.home) sessionVariables;
      gtk2 = home.gtk.gtk2.extraConfig;
      gtk3 = home.gtk.gtk3.extraConfig.gtk-im-module;
      gtk4 = home.gtk.gtk4.extraConfig.gtk-im-module;
      service = home.systemd.user.services.fcitx5-daemon;
      emacsUnsetEnvironment = home.systemd.user.services.emacs.Service.UnsetEnvironment;
      niriStartup = home.programs.niri.settings.spawn-at-startup;
      autostart = home.xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text;
      footEnabled = home.programs.foot.enable;
      waylandFrontend = home.i18n.inputMethod.fcitx5.waylandFrontend;
      package = toString home.i18n.inputMethod.package;
      globalConfig = home.xdg.configFile."fcitx5/config".text;
      profile = home.xdg.configFile."fcitx5/profile".text;
      addonConfigs = pkgs.lib.genAttrs ["clipboard" "keyboard" "quickphrase" "unicode" "punctuation" "fullwidth"] (
        name: home.xdg.configFile."fcitx5/conf/${name}.conf".text
      );
      addons = map pkgs.lib.getName home.i18n.inputMethod.fcitx5.addons;
      dataFiles = builtins.attrNames home.xdg.dataFile;
      punctuationProfile = toString home.xdg.dataFile."fcitx5/punctuation/punc.mb.zh_CN".source;
      themeConfig = toString home.xdg.dataFile."fcitx5/themes/catppuccin-mocha/theme.conf".source;
      themeBackgrounds = map (
        name: toString home.xdg.dataFile."fcitx5/themes/catppuccin-mocha/${name}.png".source
      ) ["input-panel" "menu"];
      hasRimeDeployment = home.home.activation ? deployRimeConfig;
    });
  in
    pkgs.runCommand "fcitx5-check"
    {
      nativeBuildInputs = [
        pkgs.python3
        pkgs.stdenv.cc
        pkgs.pkg-config
        pkgs.fcitx5
      ];
      buildInputs = [pkgs.qt6Packages.qtbase];
      dontWrapQtApps = true;
    }
    ''
      c++ -std=c++17 $(pkg-config --cflags Qt6Gui) \
        ${../modules/home/desktop/tests/fcitx-theme.cpp} \
        -o fcitx-theme-check $(pkg-config --libs Qt6Gui)
      c++ -std=c++20 $(pkg-config --cflags Fcitx5Config) \
        ${../modules/home/desktop/tests/fcitx-hotkeys.cpp} \
        -o fcitx-hotkeys-check $(pkg-config --libs Fcitx5Config)
      python3 - ${settings} <<'PY'
      import configparser
      import ctypes
      import json
      from pathlib import Path
      import subprocess
      import sys
      import tempfile

      with open(sys.argv[1]) as source:
          settings = json.load(source)
      subprocess.run(
          ["./fcitx-theme-check", settings["themeConfig"], *settings["themeBackgrounds"]],
          check=True,
      )
      env = settings["sessionVariables"]
      assert "GTK_IM_MODULE" not in env, "GTK Wayland apps must use text-input-v3"
      assert env["QT_IM_MODULE"] == "fcitx", "Qt5 still needs the Fcitx plugin"
      assert env["XMODIFIERS"] == "@im=fcitx"
      assert env["SDL_IM_MODULE"] == "fcitx"
      assert 'gtk-im-module="fcitx"' in settings["gtk2"]
      assert settings["gtk3"] == settings["gtk4"] == "fcitx"
      assert "GTK_IM_MODULE" in settings["emacsUnsetEnvironment"]
      assert settings["footEnabled"] and settings["waylandFrontend"]

      service = settings["service"]
      assert service["Service"]["ExecStart"] == [settings["package"] + "/bin/fcitx5"]
      assert service["Service"]["Restart"] == "on-failure"
      assert "graphical-session.target" in service["Install"]["WantedBy"]
      assert not any("fcitx5" in arg for entry in settings["niriStartup"] for arg in entry["argv"])
      autostart = configparser.ConfigParser()
      autostart.read_string(settings["autostart"])
      assert autostart["Desktop Entry"].getboolean("Hidden")

      profile = configparser.ConfigParser()
      profile.read_string(settings["profile"])
      assert profile["Groups/0"]["DefaultIM"] == "phono"
      items = [section for section in profile.sections() if section.startswith("Groups/0/Items/")]
      assert [profile[section]["Name"] for section in items] == [
          "keyboard-us", "phono", "phono-shuangpin",
      ]
      assert not {"fcitx5-rime", "rime-data"}.intersection(settings["addons"])
      assert not any(path.startswith("fcitx5/rime/") for path in settings["dataFiles"])
      assert not settings["hasRimeDeployment"]
      package = Path(settings["package"])
      for path in ("share/fcitx5/addon/rime.conf", "share/fcitx5/inputmethod/rime.conf",
                   "lib/fcitx5/librime.so", "share/rime-data"):
          assert not (package / path).exists(), path
      for addon in ("phono", "punctuation", "fullwidth"):
          assert (package / f"share/fcitx5/addon/{addon}.conf").is_file(), addon
          # Catch missing runtime dependencies/RPATHs in the final addon bundle.
          ctypes.CDLL(str(package / f"lib/fcitx5/lib{addon}.so"))
      for name in ("phono", "phono-shuangpin"):
          entry = configparser.ConfigParser()
          entry.read(package / f"share/fcitx5/inputmethod/{name}.conf")
          assert entry["InputMethod"]["Addon"] == "phono", name

      punctuation = Path(settings["punctuationProfile"]).read_text()
      default_punctuation = (package / "share/fcitx5/punctuation/punc.mb.zh_CN").read_text()
      assert default_punctuation.splitlines().count(". 。") == 1
      assert punctuation == default_punctuation.replace(". 。", ". ．")
      assert punctuation.splitlines().count(". ．") == 1

      hotkeys = configparser.ConfigParser()
      hotkeys.optionxform = str
      hotkeys.read_string(settings["globalConfig"])
      assert dict(hotkeys["Hotkey/TriggerKeys"]) == {"0": "Shift+Shift_R"}
      assert not hotkeys["Hotkey"].getboolean("EnumerateWithTriggerKeys")
      for key in ("EnumerateForwardKeys", "EnumerateBackwardKeys"):
          assert not hotkeys["Hotkey"][key], key
      for key in ("ActivateKeys", "DeactivateKeys", "AltTriggerKeys",
                  "EnumerateGroupForwardKeys", "EnumerateGroupBackwardKeys", "TogglePreedit"):
          assert not dict(hotkeys["Hotkey/" + key]), key

      addon_keys = {
          "clipboard": ("TriggerKey", "PastePrimaryKey"),
          "keyboard": ("Hint Trigger", "One Time Hint Trigger"),
          "quickphrase": ("TriggerKey",),
          "unicode": ("TriggerKey", "DirectUnicodeMode"),
          "punctuation": ("Hotkey",),
          "fullwidth": ("Hotkey",),
      }
      for addon, keys in addon_keys.items():
          config = configparser.ConfigParser()
          config.optionxform = str
          config.read_string("[Addon]\n" + settings["addonConfigs"][addon])
          for key in keys:
              assert config["Addon"][key] == "", (addon, key)

      with tempfile.TemporaryDirectory() as directory:
          user_data = Path(directory)
          # Check effective key lists with Fcitx, not just INI syntax.
          global_config = user_data / "fcitx5.conf"
          global_config.write_text(settings["globalConfig"])
          subprocess.run(
              ["./fcitx-hotkeys-check", str(global_config), "Hotkey/TogglePreedit"],
              check=True,
          )
          for addon, keys in addon_keys.items():
              addon_config = user_data / (addon + ".conf")
              addon_config.write_text(settings["addonConfigs"][addon])
              for key in keys:
                  subprocess.run(
                      ["./fcitx-hotkeys-check", str(addon_config), key], check=True,
                  )

      print("Fcitx startup, Phono-only runtime/profile, fullwidth full stop, Wayland/GTK input, and Emacs-safe hotkeys passed")
      PY
      touch "$out"
    '';

  openpgp = import ../modules/home/programs/dev/tests/openpgp.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
    inherit (nixos-secrets) secretFiles;
  };

  mail = import ../modules/home/programs/mail/tests.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
    email = nixos-secrets.sensitive.identities.glom.email;
  };

  credentials = import ../modules/home/programs/dev/credentials/tests.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
    inherit (nixos-secrets) secretFiles;
  };

  sops = import ../modules/nixos/security/tests/sops.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
    inherit (nixos-secrets) secretFiles;
  };

  yubikey-touch = import ../modules/home/desktop/tests/yubikey-touch.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
  };

  authentication = import ../modules/nixos/security/tests/authentication.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
  };

  login = import ../modules/nixos/desktop/tests/login.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
  };

  backups = import ./backups.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
  };

  power = import ./power.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
  };

  storage-health = import ./storage-health.nix {
    inherit pkgs;
    inherit (self.nixosConfigurations.nixos) config;
  };

  nix-credentials = import ./nix-credentials.nix {inherit pkgs;};

  overlays = import ./overlays.nix {
    inherit pkgs;
    hostPkgs = self.nixosConfigurations.nixos.pkgs;
  };

  toolchains = import ./toolchains.nix {
    inherit pkgs;
    hostPkgs = self.nixosConfigurations.nixos.pkgs;
    inherit (self.nixosConfigurations.nixos) config;
  };

  host = self.nixosConfigurations.nixos.config.system.build.toplevel;
}
