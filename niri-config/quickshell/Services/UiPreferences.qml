pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string configDir: Paths.homeDir + "/.cache/quickshell"
    readonly property string filePath: configDir + "/ui-preferences.json"

    property bool dndEnabled: false
    property bool darkMode: false
    property string language: normalizedLanguage(Qt.locale().name)
    property bool storeReady: false
    property bool preferencesReady: false
    property bool savePending: false
    property var systemGridLayout: ({})

    function normalizedLanguage(value) {
        const normalized = String(value || "").replace("-", "_").toLowerCase();
        if (normalized.startsWith("en"))
            return "en_US";
        if (normalized === "zh_tw"
                || normalized === "zh_hk"
                || normalized === "zh_mo"
                || normalized.indexOf("hant") >= 0)
            return "zh_TW";
        return "zh_CN";
    }

    function setDndEnabled(value) {
        root.dndEnabled = value;
        root.save();
    }

    function toggleDnd() {
        root.setDndEnabled(!root.dndEnabled);
    }

    function setLanguage(value) {
        const normalized = root.normalizedLanguage(value);
        if (root.language === normalized)
            return;
        root.language = normalized;
        root.save();
    }

    function setDarkMode(value) {
        root.darkMode = value;
        root.save();
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", value ? "prefer-dark" : "default"]);
        themeDebounce.start();
    }

    function toggleDarkMode() {
        root.setDarkMode(!root.darkMode);
    }

    function setSystemGridLayout(layout) {
        try {
            root.systemGridLayout = JSON.parse(
                JSON.stringify(layout || {})
            );
        } catch (error) {
            console.log(
                "UiPreferences rejected system grid layout:",
                error
            );
            return;
        }
        root.save();
    }

    function save() {
        if (!root.storeReady) {
            root.savePending = true;
            return;
        }

        root.savePending = false;
        prefsFile.setText(JSON.stringify({
            "dndEnabled": root.dndEnabled,
            "language": root.language,
            "systemGridLayout": root.systemGridLayout
        }, null, 2));
    }

    Process {
        id: ensureStoreDir
        command: ["mkdir", "-p", root.configDir]
        running: true
        onExited: {
            root.storeReady = true;
            prefsFile.reload();
            if (root.savePending)
                root.save();
        }
    }

    FileView {
        id: prefsFile
        path: root.filePath
        watchChanges: true
        blockLoading: true
        blockWrites: true
        atomicWrites: true

        onFileChanged: preferencesReloadDebounce.restart()

        onLoaded: {
            try {
                const parsed = JSON.parse(prefsFile.text().trim() || "{}");
                if (typeof parsed.dndEnabled === "boolean")
                    root.dndEnabled = parsed.dndEnabled;
                root.language = root.normalizedLanguage(
                    parsed.language || Qt.locale().name
                );
                if (parsed.systemGridLayout
                        && typeof parsed.systemGridLayout === "object") {
                    root.systemGridLayout =
                        parsed.systemGridLayout;
                }
            } catch (error) {
                console.log("UiPreferences failed to load:", error);
            } finally {
                root.preferencesReady = true;
            }
        }

        onLoadFailed: {
            root.preferencesReady = true;
            root.save();
        }
    }

    Timer {
        id: preferencesReloadDebounce
        interval: 100
        repeat: false
        onTriggered: prefsFile.reload()
    }

    Process {
        id: themePoller
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.darkMode = this.text.toLowerCase().includes("prefer-dark")
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: themePoller.running = true
    }

    Timer {
        id: themeDebounce
        interval: 350
        running: false
        repeat: false
        onTriggered: themePoller.running = true
    }
}
