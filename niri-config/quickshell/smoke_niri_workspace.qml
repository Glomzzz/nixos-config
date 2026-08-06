//@ pragma UseQApplication

import QtQuick
import Quickshell
import Clavis.Niri 1.0

ShellRoot {
    id: root

    property int attempts: 0

    Timer {
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            root.attempts += 1;
            if (!Niri.connected || Quickshell.screens.length === 0) {
                if (root.attempts < 60)
                    return;
                stop();
                console.error("NIRI_WORKSPACE_SMOKE_FAIL",
                    Niri.lastError);
                Qt.quit();
                return;
            }

            const output = Quickshell.screens[0].name;
            const workspace =
                Niri.activeWorkspaceForOutput(output);
            if (workspace.id === undefined) {
                if (root.attempts < 60)
                    return;
                stop();
                console.error("NIRI_WORKSPACE_SMOKE_FAIL",
                    "no active workspace for " + output);
                Qt.quit();
                return;
            }

            const passed =
                workspace.tiledWindowCount !== undefined
                && workspace.tiledColumnCount !== undefined
                && workspace.windowCount !== undefined;
            stop();
            console.log(passed
                ? "NIRI_WORKSPACE_SMOKE_PASS"
                : "NIRI_WORKSPACE_SMOKE_FAIL");
            Qt.quit();
        }
    }
}
