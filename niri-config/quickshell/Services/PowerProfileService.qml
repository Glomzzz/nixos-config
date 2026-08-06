pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Common/functions/PowerProfiles.js" as PowerProfiles

Singleton {
    id: root

    readonly property string commandName: String(
        Quickshell.env("CLAVIS_POWERPROFILESCTL")
            || "powerprofilesctl").trim()

    property var profiles: []
    property string activeProfile: ""
    property bool available: false
    property bool refreshing: false
    property bool setting: false
    readonly property bool busy: refreshing || setting
    property string lastError: ""

    property bool _refreshQueued: false
    property bool _listExited: false
    property bool _listOutputFinished: false
    property int _listExitCode: -1
    property string _listOutput: ""
    property string _pendingProfile: ""

    signal operationStarted(string operation)
    signal operationSucceeded(string operation)
    signal operationFailed(string operation, string message)

    function refresh() {
        if (root.setting || root.refreshing) {
            root._refreshQueued = true;
            return;
        }

        root._refreshQueued = false;
        root._listExited = false;
        root._listOutputFinished = false;
        root._listExitCode = -1;
        root._listOutput = "";
        root.refreshing = true;
        listProcess.command = [root.commandName, "list"];
        listProcess.running = true;
    }

    function setProfile(profile) {
        const requested = PowerProfiles.normalizeProfile(profile);
        if (!root.available
                || root.profiles.indexOf(requested) === -1) {
            root.lastError = qsTr("This power profile is unavailable");
            root.operationFailed("set-profile", root.lastError);
            return;
        }
        if (root.busy || requested === root.activeProfile)
            return;

        root.lastError = "";
        root.setting = true;
        root._pendingProfile = requested;
        root.operationStarted("set-profile");
        setProcess.command = [root.commandName, "set", requested];
        setProcess.running = true;
    }

    function _finishRefreshIfReady() {
        if (!root._listExited || !root._listOutputFinished)
            return;

        root.refreshing = false;
        if (root._listExitCode !== 0) {
            root.available = false;
            root.profiles = [];
            root.activeProfile = "";
            root.lastError = String(listError.text || "").trim()
                || qsTr("Power profile service is unavailable");
        } else {
            const state = PowerProfiles.parseList(root._listOutput);
            if (state.profiles.length === 0
                    || state.activeProfile === "") {
                root.available = false;
                root.profiles = [];
                root.activeProfile = "";
                root.lastError = qsTr(
                    "Power profile service returned invalid data");
            } else {
                root.profiles = state.profiles;
                root.activeProfile = state.activeProfile;
                root.available = true;
                root.lastError = "";
            }
        }

        if (root._refreshQueued)
            Qt.callLater(root.refresh);
    }

    function _finishSet(exitCode) {
        root._pendingProfile = "";
        root.setting = false;

        if (exitCode === 0) {
            root.operationSucceeded("set-profile");
            root.refresh();
            return;
        }

        root.lastError = String(setError.text || "").trim()
            || qsTr("Could not change the power profile");
        root.operationFailed("set-profile", root.lastError);
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: listProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root._listOutput = this.text;
                root._listOutputFinished = true;
                root._finishRefreshIfReady();
            }
        }

        stderr: StdioCollector {
            id: listError
        }

        onExited: (exitCode, exitStatus) => {
            root._listExitCode = exitCode;
            root._listExited = true;
            root._finishRefreshIfReady();
        }
    }

    Process {
        id: setProcess

        stderr: StdioCollector {
            id: setError
        }

        onExited: (exitCode, exitStatus) => root._finishSet(exitCode)
    }
}
