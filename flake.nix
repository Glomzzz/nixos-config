{
  description = "Glom's Flake configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien-source.url = "github:thiagokokada/nix-alien";
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned to PR #452, which adds compositor-side scaling for X11 clients.
    # Release 0.8.2 in nixpkgs derives one X-wide scale as the *minimum* of all
    # output scales and then positions each XRandR output at niri's logical
    # coordinate while sizing it in native pixels. Those two coordinate spaces
    # disagree whenever the scales differ, so the X rectangles overlap and no
    # X11 client can tell which monitor its window is on. This revision makes
    # the X screen a uniform multiple of niri's logical space instead, which is
    # what allows per-monitor scaling to work at all; see
    # hardware/zephyrus/gpu for the scale that goes with it.
    #
    # Pinned by revision rather than tracking a branch: this is an unmerged PR,
    # so its head can be rebased or force-pushed out from under us.
    xwayland-satellite = {
      url = "github:Supreeeme/xwayland-satellite/d10a015a9423c360d723ab7d65f824db662cbbd7";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    ...
  }: let
    systems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
  in {
    formatter = forAllSystems (system: (pkgsFor system).alejandra);

    checks = forAllSystems (
      system: let
        pkgs = pkgsFor system;
      in {
        formatting =
          pkgs.runCommand "alejandra-check"
          {
            nativeBuildInputs = [pkgs.alejandra];
            src = ./.;
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
            src = ./.;
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
            src = ./.;
          }
          ''
            cd "$src"
            statix check .
            touch "$out"
          '';

        waybar = let
          helpers = import ./modules/home/desktop/niri/waybar/helpers.nix {inherit pkgs;};
          settings =
            pkgs.writeText "waybar-settings.json"
            (builtins.toJSON self.nixosConfigurations.nixos.config.home-manager.users.glom.programs.waybar.settings);
        in
          pkgs.runCommand "waybar-check"
          {
            nativeBuildInputs = [pkgs.bash pkgs.python3 pkgs.jq pkgs.gawk pkgs.shellcheck];
            src = ./modules/home/desktop/niri/waybar;
            # Realize every packaged helper, including writeShellApplication's
            # shellcheck validation, without launching desktop services.
            helpers = builtins.attrValues (builtins.removeAttrs helpers ["powerMenu"]);
          }
          ''
            shellcheck --shell=bash "$src"/scripts/*.sh
            python3 "$src/tests.py" ${settings}
            touch "$out"
          '';

        steam-game-laptop = let
          # Exercise the production launcher with a harmless compositor stub.
          # writeShellApplication still runs shellcheck on the complete script.
          fakeGamescope = pkgs.writeShellScriptBin "gamescope" ''
            exec ${pkgs.python3}/bin/python3 ${./modules/nixos/programs/tests/steam-game-laptop.py} --capture-gamescope "$@"
          '';
          packages =
            (import ./modules/nixos/programs/steam.nix {
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
            python3 ${./modules/nixos/programs/tests/steam-game-laptop.py} ${launcher}/bin/steam-game-laptop
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
            addonConfigs = pkgs.lib.genAttrs ["clipboard" "keyboard" "quickphrase" "unicode"] (
              name: home.xdg.configFile."fcitx5/conf/${name}.conf".text
            );
            rimeConfigs = pkgs.lib.genAttrs ["default.custom.yaml" "luna_pinyin_simp.custom.yaml" "pin.schema.yaml"] (
              name: home.xdg.dataFile."fcitx5/rime/${name}".text
            );
          });
        in
          pkgs.runCommand "fcitx5-check"
          {
            nativeBuildInputs = [
              (pkgs.python3.withPackages (ps: [ps.pyyaml]))
              pkgs.librime
              pkgs.stdenv.cc
              pkgs.pkg-config
              pkgs.fcitx5
            ];
          }
          ''
            c++ -std=c++20 $(pkg-config --cflags Fcitx5Config) \
              ${./modules/home/desktop/tests/fcitx-hotkeys.cpp} \
              -o fcitx-hotkeys-check $(pkg-config --libs Fcitx5Config)
            python3 - ${settings} <<'PY'
            import configparser
            import json
            from pathlib import Path
            import subprocess
            import sys
            import tempfile

            import yaml

            with open(sys.argv[1]) as source:
                settings = json.load(source)
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
            }
            for addon, keys in addon_keys.items():
                config = configparser.ConfigParser()
                config.optionxform = str
                config.read_string("[Addon]\n" + settings["addonConfigs"][addon])
                for key in keys:
                    assert config["Addon"][key] == "", (addon, key)

            # Compile the real schema: inherited bindings/+ can silently append
            # Ctrl shortcuts after an apparently complete custom replacement.
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
                for name, text in settings["rimeConfigs"].items():
                    (user_data / name).write_text(text)
                result = subprocess.run(
                    ["rime_deployer", "--build", directory,
                     "${pkgs.rime-data}/share/rime-data", str(user_data / "build")],
                    capture_output=True, text=True,
                )
                assert result.returncode == 0, result.stderr
                default = yaml.safe_load((user_data / "build/default.yaml").read_text())
                schema = yaml.safe_load((user_data / "build/pin.schema.yaml").read_text())
                assert default["switcher"]["hotkeys"] == []
                assert all(value == "noop" for value in default["ascii_composer"]["switch_key"].values())
                bindings = default["key_binder"]["bindings"]
                assert schema["key_binder"]["bindings"] == bindings
                assert len(bindings) == 6, "Keep punctuation and Tab candidate navigation"
                for shape in ("half_shape", "full_shape"):
                    assert schema["punctuator"][shape]["."] == {"commit": "\uff0e"}, shape
                for binding in bindings:
                    assert not any(modifier in binding["accept"] for modifier in ("Control+", "Alt+", "Super+"))
                    assert "toggle" not in binding

            print("Fcitx startup, Wayland/GTK input, fullwidth period, and Emacs-safe hotkeys passed")
            PY
            touch "$out"
          '';

        openpgp = import ./modules/home/programs/dev/tests/openpgp.nix {
          inherit pkgs;
          inherit (self.nixosConfigurations.nixos) config;
        };

        authentication = import ./modules/nixos/security/tests/authentication.nix {
          inherit pkgs;
          inherit (self.nixosConfigurations.nixos) config;
        };

        login = import ./modules/nixos/desktop/tests/login.nix {
          inherit pkgs;
          inherit (self.nixosConfigurations.nixos) config;
        };

        host = self.nixosConfigurations.nixos.config.system.build.toplevel;
      }
    );

    nixosConfigurations = {
      nixos = let
        system = "x86_64-linux";
        hostname = "nixos";
        username = "glom";
        usernameFull = "Glom Zhao";
        email = "me@glomzzz.com";
        specialArgs = {
          inherit hostname;
          inherit username;
          inherit usernameFull;
          inherit email;
          inherit system;
          inherit inputs;
        };
      in
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          inherit system;
          modules = [
            ./hosts/nixos
            home-manager.nixosModules.home-manager
          ];
        };
    };
  };
}
