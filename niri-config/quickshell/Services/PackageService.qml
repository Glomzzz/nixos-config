pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool disabled:
        Quickshell.env("CLAVIS_PACKAGE_SERVICE_DISABLED") === "1"
    readonly property string commandName:
        Quickshell.env("CLAVIS_PARU") || "paru"
    property int totalPackages: -1
    property int pendingUpdates: -1
    property bool totalLoading: false
    property bool updatesLoading: false
    property int _totalCount: 0
    property int _updateCount: 0

    function refresh() {
        if (root.disabled) {
            root.totalLoading = false;
            root.updatesLoading = false;
            return;
        }

        if (!totalProcess.running) {
            root._totalCount = 0;
            root.totalLoading = true;
            totalProcess.running = true;
        }
        if (!updatesProcess.running) {
            root._updateCount = 0;
            root.updatesLoading = true;
            updatesProcess.running = true;
        }
    }

    Component.onCompleted: {
        if (!root.disabled)
            refresh();
    }

    Process {
        id: totalProcess

        command: [root.commandName, "-Qq"]

        stdout: SplitParser {
            onRead: line => {
                if (String(line).trim() !== "")
                    root._totalCount += 1;
            }
        }

        onExited: exitCode => {
            root.totalLoading = false;
            if (exitCode === 0)
                root.totalPackages = root._totalCount;
        }
    }

    Process {
        id: updatesProcess

        command: [root.commandName, "-Quq"]

        stdout: SplitParser {
            onRead: line => {
                if (String(line).trim() !== "")
                    root._updateCount += 1;
            }
        }

        onExited: exitCode => {
            root.updatesLoading = false;
            if (exitCode === 0 || root._updateCount > 0)
                root.pendingUpdates = root._updateCount;
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: !root.disabled
        onTriggered: root.refresh()
    }
}
