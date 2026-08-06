pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property bool runningOnNiri: ThemeService.isNiriSession
    property bool compositorSupported: false
    readonly property bool available:
        root.runningOnNiri && root.compositorSupported
    readonly property bool enabled:
        root.available && PersonalizationConfig.shellBlurEnabled
    readonly property bool xray:
        PersonalizationConfig.shellBlurXray
    readonly property bool integrationBusy:
        integrationProcess.running

    property bool niriIntegrationReady: false
    property string lastError: ""
    property string niriVersion: ""
    property bool effectsWritePending: false

    readonly property string niriConfigPath: {
        const configured = Quickshell.env("NIRI_CONFIG") || "";
        return configured !== ""
            ? configured
            : Paths.homeDir + "/.config/niri/config.kdl";
    }
    readonly property string niriConfigDir: {
        const separator = root.niriConfigPath.lastIndexOf("/");
        return separator > 0
            ? root.niriConfigPath.slice(0, separator)
            : Paths.homeDir + "/.config/niri";
    }
    readonly property string effectsConfigPath:
        root.niriConfigDir + "/clavis-effects.kdl"
    readonly property string configScript:
        Paths.systemScriptsDir + "/manage-niri-effects.sh"

    signal integrationConfigured()
    signal integrationFailed(string message)

    function backgroundColor(baseColor) {
        return Appearance.applyAlpha(
            baseColor,
            PersonalizationConfig.shellBackgroundOpacity);
    }

    function supportsVersion(versionText) {
        const match = String(versionText || "")
            .match(/(?:^|\s)(\d+)\.(\d+)(?:\D|$)/);
        if (!match)
            return false;
        const major = Number(match[1]);
        const minor = Number(match[2]);
        return major > 26 || (major === 26 && minor >= 4);
    }

    function includesEffectsConfig(text) {
        return /(^|\n)\s*include(?:\s+optional=true)?\s+"(?:[^"]*\/)?clavis-effects\.kdl"\s*(?:\/\/[^\n]*)?(?:\n|$)/
            .test(String(text || ""));
    }

    function refreshIntegrationState() {
        niriConfigFile.reload();
    }

    function writeEffectsConfig() {
        if (!root.available)
            return;
        if (effectsWriteProcess.running) {
            root.effectsWritePending = true;
            return;
        }

        root.effectsWritePending = false;
        root.lastError = "";
        effectsWriteProcess.command = [
            root.configScript,
            "write",
            root.niriConfigPath,
            root.effectsConfigPath,
            root.xray ? "true" : "false",
            "niri",
            PersonalizationConfig.shellBlurEnabled
                ? "true" : "false"
        ];
        effectsWriteProcess.running = true;
    }

    function configureNiriIntegration() {
        if (!root.available || integrationProcess.running)
            return;

        root.lastError = "";
        integrationProcess.command = [
            root.configScript,
            "configure",
            root.niriConfigPath,
            root.effectsConfigPath,
            root.xray ? "true" : "false",
            "niri",
            PersonalizationConfig.shellBlurEnabled
                ? "true" : "false"
        ];
        integrationProcess.running = true;
    }

    Connections {
        target: PersonalizationConfig

        function onShellBlurXrayChanged() {
            root.writeEffectsConfig();
        }

        function onShellBlurEnabledChanged() {
            root.writeEffectsConfig();
        }
    }

    Process {
        id: versionProcess

        command: ["niri", "--version"]
        running: root.runningOnNiri

        stdout: StdioCollector {
            id: versionOutput
        }

        stderr: StdioCollector {
            id: versionError
        }

        onExited: exitCode => {
            root.niriVersion = versionOutput.text.trim();
            root.compositorSupported = exitCode === 0
                && root.supportsVersion(root.niriVersion);
            if (!root.compositorSupported) {
                root.lastError = exitCode === 0
                    ? qsTr("当前 Niri 版本不支持背景模糊")
                    : (versionError.text.trim()
                        || qsTr("无法检测 Niri 版本"));
                return;
            }

            root.lastError = "";
            if (root.niriIntegrationReady)
                root.writeEffectsConfig();
            root.refreshIntegrationState();
        }
    }

    Process {
        id: effectsWriteProcess

        stderr: StdioCollector {
            id: effectsWriteError
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.lastError = "";
            } else {
                root.lastError = effectsWriteError.text.trim()
                    || qsTr("无法写入 Niri 效果配置");
            }
            if (root.effectsWritePending)
                Qt.callLater(root.writeEffectsConfig);
        }
    }

    Process {
        id: integrationProcess

        stderr: StdioCollector {
            id: integrationError
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.lastError = "";
                root.refreshIntegrationState();
                root.integrationConfigured();
                return;
            }

            root.lastError = integrationError.text.trim()
                || qsTr("无法配置 Niri 集成");
            root.integrationFailed(root.lastError);
        }
    }

    FileView {
        id: niriConfigFile

        path: root.niriConfigPath
        blockLoading: true
        watchChanges: true

        onLoaded: {
            root.niriIntegrationReady =
                root.includesEffectsConfig(niriConfigFile.text());
            if (root.niriIntegrationReady && root.available)
                root.writeEffectsConfig();
        }
        onLoadFailed: root.niriIntegrationReady = false
        onFileChanged: Qt.callLater(root.refreshIntegrationState)
    }
}
