{
  description = "Reproducible Niri and Clavis Shell desktop configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
      };
    runtimePackagesFor = pkgs:
      with pkgs; [
        awww
        bash
        brightnessctl
        cliphist
        coreutils
        curl
        ddcutil
        ffmpeg-full
        findutils
        gawk
        gettext
        glib
        gnome-system-monitor
        gnugrep
        gnused
        gpu-screen-recorder
        grim
        imagemagick
        jq
        libnotify
        matugen
        niri
        pavucontrol
        playerctl
        procps
        pulseaudio
        python3
        rclone
        systemd
        util-linux
        wireplumber
        wl-clipboard
        which
        wlogout
        wlsunset
        xdg-utils
        xrdb
      ];
    qmlImportPathFor = pkgs: core:
      pkgs.lib.makeSearchPath "lib/qt-6/qml" [
        core
        pkgs.quickshell
        pkgs.qt6.qt5compat
        pkgs.qt6.qtdeclarative
        pkgs.qt6.qtlottie
      ];
  in {
    packages = forAllSystems (system: let
      pkgs = pkgsFor system;
      core = pkgs.callPackage ./nix/package.nix {};
      runtimePackages = runtimePackagesFor pkgs;
      qmlImportPath = qmlImportPathFor pkgs core;
      shell = pkgs.symlinkJoin {
        name = "clavis-shell-${core.version}";
        paths = [core];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          rm "$out/bin/key"
          makeWrapper ${core}/bin/key "$out/bin/key" \
            --prefix PATH : "${pkgs.lib.makeBinPath runtimePackages}"
          makeWrapper ${pkgs.quickshell}/bin/qs "$out/bin/qs" \
            --add-flags "--path ${core}/share/clavis-shell" \
            --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath runtimePackages}" \
            --prefix QML_IMPORT_PATH : "${qmlImportPath}" \
            --prefix QML2_IMPORT_PATH : "${qmlImportPath}" \
            --set CLAVIS_KEY "$out/bin/key" \
            --set CLAVIS_PACKAGE_SERVICE_DISABLED "1" \
            --set CLAVIS_SOUND_DIR "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo"
          ln -s qs "$out/bin/clavis-shell"
        '';
        meta =
          core.meta
          // {
            description = "Clavis desktop shell for Niri";
            mainProgram = "qs";
          };
      };
    in {
      clavis-core = core;
      clavis-shell = shell;
      default = shell;
    });

    apps = forAllSystems (system: {
      default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/qs";
        meta.description = "Run Clavis Shell";
      };
    });

    devShells = forAllSystems (system: let
      pkgs = pkgsFor system;
      core = self.packages.${system}.clavis-core;
      qmlImportPath = qmlImportPathFor pkgs core;
    in {
      default = pkgs.mkShell {
        inputsFrom = [core];
        packages =
          runtimePackagesFor pkgs
          ++ (with pkgs; [
            alejandra
            clang-tools
            deadnix
            direnv
            quickshell
            shellcheck
            statix
          ]);
        CLAVIS_KEY = "${core}/bin/key";
        CLAVIS_PACKAGE_SERVICE_DISABLED = "1";
        CLAVIS_SOUND_DIR = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo";
        QML_IMPORT_PATH = qmlImportPath;
        QML2_IMPORT_PATH = qmlImportPath;
      };
    });

    checks = forAllSystems (system: let
      pkgs = pkgsFor system;
      core = self.packages.${system}.clavis-core;
      qmlImportPath = qmlImportPathFor pkgs core;
    in {
      inherit (self.packages.${system}) clavis-core clavis-shell;

      formatting =
        pkgs.runCommand "niri-config-formatting" {
          nativeBuildInputs = [pkgs.alejandra];
          src = ./.;
        } ''
          cd "$src"
          alejandra --check .
          touch "$out"
        '';

      dead-code =
        pkgs.runCommand "niri-config-dead-code" {
          nativeBuildInputs = [pkgs.deadnix];
          src = ./.;
        } ''
          cd "$src"
          deadnix --fail .
          touch "$out"
        '';

      lint =
        pkgs.runCommand "niri-config-lint" {
          nativeBuildInputs = [pkgs.statix];
          src = ./.;
        } ''
          cd "$src"
          statix check .
          touch "$out"
        '';

      niri-config =
        pkgs.runCommand "niri-config-validation" {
          nativeBuildInputs = [pkgs.niri];
        } ''
          niri validate -c ${./config/niri/config.kdl}
          touch "$out"
        '';

      qml-tests =
        pkgs.runCommand "clavis-shell-qml-tests" {
          nativeBuildInputs = [pkgs.qt6.qtdeclarative];
          src = ./quickshell;
          QML_IMPORT_PATH = qmlImportPath;
          QML2_IMPORT_PATH = qmlImportPath;
        } ''
          env -u QT_QPA_PLATFORMTHEME \
            QT_QPA_PLATFORM=offscreen \
            qmltestrunner -input "$src/tests/qml"

          env -u QT_QPA_PLATFORMTHEME \
            QT_QPA_PLATFORM=offscreen \
            qmlplugindump M3Shapes 1.0 >/dev/null

          touch "$out"
        '';

      shell-tests =
        pkgs.runCommand "clavis-shell-tests" {
          nativeBuildInputs = with pkgs; [
            bash
            coreutils
            findutils
            gawk
            gettext
            gnugrep
            gnused
            matugen
            niri
            python3
            ripgrep
            yazi
            zsh
          ];
          src = ./quickshell;
        } ''
          cp -a "$src" source
          chmod -R u+w source
          cd source
          patchShebangs .
          # test_awww_dedup needs a live Wayland compositor and runs as a smoke
          # test outside the Nix sandbox.
          for test_script in \
            tests/test_manage_niri_effects.sh \
            tests/test_matugen_templates.sh \
            tests/test_power_menu.sh \
            tests/test_shell_blur_audit.sh; do
            "$test_script"
          done
          touch "$out"
        '';
    });

    formatter = forAllSystems (system: (pkgsFor system).alejandra);

    homeManagerModules.default = import ./nix/home-manager-module.nix {inherit self;};
    nixosModules.default = import ./nix/nixos-module.nix {inherit self;};
  };
}
