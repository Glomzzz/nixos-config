//@ pragma UseQApplication

import QtQuick
import Quickshell
import Clavis.Niri 1.0
import "Common/functions/WallpaperMath.js" as WallpaperMath

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
                console.error("NIRI_PARALLAX_SMOKE_FAIL",
                    Niri.lastError);
                Qt.quit();
                return;
            }

            for (let index = 0;
                    index < Quickshell.screens.length; index += 1) {
                const output =
                    String(Quickshell.screens[index].name);
                const active =
                    Niri.activeWorkspaceForOutput(output);
                const windows = active.id
                    ? Niri.windowsForWorkspace(active.id) : [];
                const columns =
                    WallpaperMath.horizontalColumns(windows);
                const focused = Niri.focusedWindow;
                const focusedColumn =
                    WallpaperMath.isHorizontalTiledWindow(focused)
                    && String(focused.workspaceId)
                        === String(active.id)
                        ? focused.layoutColumn
                        : WallpaperMath.nearestHorizontalColumn(
                            columns, columns.length > 0
                                ? columns[0] : 0);
                const progress =
                    WallpaperMath.focusedColumnProgress(
                        columns, focusedColumn, 6);
                if (!isFinite(progress)
                        || progress < 0 || progress > 1) {
                    stop();
                    console.error("NIRI_PARALLAX_SMOKE_FAIL",
                        output, progress);
                    Qt.quit();
                    return;
                }
                console.log("NIRI_PARALLAX_STATE", output,
                    JSON.stringify(
                        Niri.workspacesForOutput(output)),
                    JSON.stringify(active),
                    JSON.stringify(columns),
                    focusedColumn,
                    progress);
            }
            stop();
            console.log("NIRI_PARALLAX_SMOKE_PASS");
            Qt.quit();
        }
    }
}
