pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string avatarPath: Paths.profileAvatar
    readonly property string avatarUrl: available
        ? Paths.fileUrl(avatarPath) + "?revision=" + revision : ""
    property int revision: 0
    property bool available: false
    property bool busy: false
    property string pendingSource: ""

    signal updateFinished(bool success, string message)

    function setAvatar(path) {
        const source = String(path || "");
        if (source === "" || busy) {
            if (source === "")
                updateFinished(false, qsTr("Select a valid avatar image"));
            return;
        }

        pendingSource = source;
        busy = true;
        copyProcess.command = ["cp", "--", source, avatarPath];
        copyProcess.running = true;
    }

    Process {
        id: copyProcess

        onExited: exitCode => {
            root.busy = false;
            if (exitCode === 0) {
                root.revision += 1;
                root.available = true;
                root.updateFinished(true, qsTr("Avatar updated"));
                Quickshell.execDetached([
                    "notify-send",
                    "-a", "quickshell",
                    "-u", "low",
                    qsTr("Avatar updated"),
                    root.pendingSource
                ]);
            } else {
                root.updateFinished(false, qsTr("Unable to update avatar"));
                Quickshell.execDetached([
                    "notify-send",
                    "-a", "quickshell",
                    "-u", "critical",
                    qsTr("Avatar update failed"),
                    root.pendingSource
                ]);
            }
            root.pendingSource = "";
        }
    }

    Process {
        command: ["test", "-r", root.avatarPath]
        running: true
        onExited: exitCode => root.available = exitCode === 0
    }
}
