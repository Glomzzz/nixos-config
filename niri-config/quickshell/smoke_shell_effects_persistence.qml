//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Services

ShellRoot {
    id: root

    readonly property string phase:
        Quickshell.env("CLAVIS_EFFECTS_SMOKE_PHASE") || "write"
    property int settledTicks: 0

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    Timer {
        interval: 40
        repeat: true
        running: true

        onTriggered: {
            if (!PersonalizationConfig.storeReady)
                return;

            try {
                if (root.phase === "write") {
                    if (root.settledTicks === 0) {
                        PersonalizationConfig
                            .setShellBackgroundOpacity(0.63);
                        PersonalizationConfig
                            .setShellBlurEnabled(true);
                        PersonalizationConfig
                            .setShellBlurXray(false);
                    }
                    ++root.settledTicks;
                    if (root.settledTicks < 4)
                        return;
                    console.log(
                        "SHELL_EFFECTS_PERSISTENCE_WRITE_PASS");
                } else {
                    root.verify(
                        PersonalizationConfig
                            .shellBackgroundOpacity === 0.63,
                        "persisted opacity");
                    root.verify(
                        PersonalizationConfig.shellBlurEnabled,
                        "persisted blur enabled");
                    root.verify(
                        !PersonalizationConfig.shellBlurXray,
                        "persisted xray");
                    console.log(
                        "SHELL_EFFECTS_PERSISTENCE_READ_PASS");
                }
            } catch (error) {
                console.error(
                    "SHELL_EFFECTS_PERSISTENCE_FAIL", error);
            }
            stop();
            Qt.callLater(Qt.quit);
        }
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: {
            console.error(
                "SHELL_EFFECTS_PERSISTENCE_FAIL", "timeout");
            Qt.quit();
        }
    }
}
