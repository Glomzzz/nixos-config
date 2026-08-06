pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string commandName: Quickshell.env("CLAVIS_RCLONE") || "rclone"
    property bool available: false
    property bool remotesLoading: false
    property var remotes: []
    property string selectedRemoteName: ""
    readonly property var selectedRemote: remoteByName(selectedRemoteName)

    property string quotaState: "idle"
    property string quotaMessage: ""
    property real totalBytes: -1
    property real usedBytes: -1
    property real freeBytes: -1
    readonly property bool quotaAvailable: quotaState === "ready"
        && totalBytes > 0 && usedBytes >= 0
    readonly property real usageRatio: quotaAvailable
        ? Math.max(0, Math.min(1, usedBytes / totalBytes))
        : 0

    property string backupState: "idle"
    property string backupMessage: ""
    property real backupProgress: -1
    property string backupSource: ""
    property string backupDestination: ""

    property string _remotesOutput: ""
    property string _quotaOutput: ""

    function remoteByName(name) {
        for (let index = 0; index < root.remotes.length; ++index) {
            if (root.remotes[index].name === name)
                return root.remotes[index];
        }
        return null;
    }

    function isReadOnly(remote) {
        if (!remote)
            return true;
        return ["http"].indexOf(String(remote.type || "").toLowerCase()) >= 0;
    }

    function normalizeRemoteName(name) {
        return String(name || "").replace(/:+$/, "");
    }

    function basename(path) {
        const value = String(path || "").replace(/\/+$/, "");
        const index = value.lastIndexOf("/");
        return index >= 0 ? value.substring(index + 1) : value;
    }

    function safePathSegment(value) {
        const normalized = String(value || "")
            .replace(/[\\/:*?"<>|]/g, "_")
            .replace(/^\.+$/, "_")
            .trim();
        return normalized || qsTr("备份");
    }

    function selectRemote(name) {
        const normalized = normalizeRemoteName(name);
        if (!remoteByName(normalized))
            return false;
        if (selectedRemoteName === normalized)
            return true;
        selectedRemoteName = normalized;
        refreshQuota();
        return true;
    }

    function refreshRemotes() {
        if (remoteListProcess.running)
            return;
        remotesLoading = true;
        _remotesOutput = "";
        remoteListProcess.command = [commandName, "listremotes", "--json"];
        remoteListProcess.running = true;
        remoteTimeout.restart();
    }

    function refreshQuota() {
        if (!selectedRemote || quotaProcess.running)
            return;
        quotaState = "loading";
        quotaMessage = "";
        totalBytes = -1;
        usedBytes = -1;
        freeBytes = -1;
        _quotaOutput = "";
        quotaProcess.command = [
            commandName,
            "about",
            selectedRemoteName + ":",
            "--json"
        ];
        quotaProcess.running = true;
        quotaTimeout.restart();
    }

    function clearCompletedBackupStatus() {
        if (backupState === "running")
            return;
        backupState = "idle";
        backupMessage = "";
        backupProgress = -1;
        backupSource = "";
        backupDestination = "";
    }

    function refreshCard() {
        clearCompletedBackupStatus();
        refreshQuota();
    }

    function backup(path, isDirectory) {
        const source = String(path || "");
        const remote = selectedRemote;
        if (backupProcess.running || source === "" || !remote)
            return false;
        if (isReadOnly(remote)) {
            backupState = "error";
            backupMessage = qsTr("所选云存储为只读服务");
            return false;
        }

        const sourceName = safePathSegment(basename(source));
        const hostName = safePathSegment(SystemIdentityService.hostName);
        const destinationRoot = selectedRemoteName
            + ":Clavis Backups/" + hostName + "/" + sourceName;
        const command = isDirectory
            ? [commandName, "copy", source, destinationRoot]
            : [commandName, "copyto", source, destinationRoot];
        command.push(
            "--stats=1s",
            "--stats-one-line-json",
            "--stats-log-level=NOTICE"
        );

        backupSource = source;
        backupDestination = destinationRoot;
        backupState = "running";
        backupMessage = qsTr("正在备份 %1").arg(sourceName);
        backupProgress = -1;
        backupProcess.command = command;
        backupProcess.running = true;
        return true;
    }

    function consumeBackupLine(line) {
        const value = String(line || "").trim();
        if (value === "" || value.charAt(0) !== "{")
            return;
        try {
            const parsed = JSON.parse(value);
            const stats = parsed.stats || parsed;
            const percentage = Number(stats.percentage);
            const bytes = Number(stats.bytes);
            const total = Number(stats.totalBytes);
            if (isFinite(percentage))
                backupProgress = Math.max(0, Math.min(1, percentage / 100));
            else if (isFinite(bytes) && isFinite(total) && total > 0)
                backupProgress = Math.max(0, Math.min(1, bytes / total));
        } catch (error) {
        }
    }

    Component.onCompleted: refreshRemotes()

    Process {
        id: remoteListProcess

        stdout: StdioCollector {
            onStreamFinished: root._remotesOutput = this.text
        }
        onExited: exitCode => {
            remoteTimeout.stop();
            root.remotesLoading = false;
            root.available = exitCode === 0;
            if (exitCode !== 0) {
                root.remotes = [];
                root.selectedRemoteName = "";
                root.quotaState = "error";
                root.quotaMessage = qsTr("无法读取 rclone 配置");
                return;
            }

            try {
                const parsed = JSON.parse(root._remotesOutput || "[]");
                root.remotes = Array.isArray(parsed) ? parsed.map(item => ({
                    name: root.normalizeRemoteName(item.name),
                    type: String(item.type || ""),
                    description: String(item.description || "")
                })) : [];
            } catch (error) {
                root.remotes = [];
                root.quotaState = "error";
                root.quotaMessage = qsTr("rclone 返回了无效的 remote 列表");
            }

            if (root.remotes.length === 0) {
                root.selectedRemoteName = "";
                root.quotaState = "unavailable";
                root.quotaMessage = qsTr("尚未配置云存储");
                return;
            }

            const currentStillExists = root.remoteByName(root.selectedRemoteName);
            if (!currentStillExists) {
                const preferred = root.remoteByName("gdrive");
                root.selectedRemoteName = preferred
                    ? preferred.name : root.remotes[0].name;
            }
            root.refreshQuota();
        }
    }

    Process {
        id: quotaProcess

        stdout: StdioCollector {
            onStreamFinished: root._quotaOutput = this.text
        }
        onExited: exitCode => {
            quotaTimeout.stop();
            if (exitCode !== 0) {
                root.quotaState = "unavailable";
                root.quotaMessage = qsTr("此云存储暂不提供容量信息");
                return;
            }

            try {
                const parsed = JSON.parse(root._quotaOutput || "{}");
                const total = Number(parsed.total);
                const used = Number(parsed.used);
                const free = Number(parsed.free);
                root.totalBytes = isFinite(total) ? total : -1;
                root.usedBytes = isFinite(used) ? used : -1;
                root.freeBytes = isFinite(free) ? free : -1;
                if (root.totalBytes > 0 && root.usedBytes >= 0) {
                    root.quotaState = "ready";
                    root.quotaMessage = "";
                } else {
                    root.quotaState = "unavailable";
                    root.quotaMessage = qsTr("此云存储未报告总容量");
                }
            } catch (error) {
                root.quotaState = "error";
                root.quotaMessage = qsTr("无法解析云存储容量");
            }
        }
    }

    Process {
        id: backupProcess

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.consumeBackupLine(line)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => root.consumeBackupLine(line)
        }
        onExited: exitCode => {
            root.backupProgress = exitCode === 0 ? 1 : root.backupProgress;
            root.backupState = exitCode === 0 ? "success" : "error";
            root.backupMessage = exitCode === 0
                ? qsTr("备份已完成")
                : qsTr("备份失败，请检查网络和远程权限");
            if (exitCode === 0)
                root.refreshQuota();
        }
    }

    Timer {
        id: remoteTimeout
        interval: 10000
        onTriggered: {
            if (remoteListProcess.running)
                remoteListProcess.signal(15);
        }
    }

    Timer {
        id: quotaTimeout
        interval: 20000
        onTriggered: {
            if (quotaProcess.running)
                quotaProcess.signal(15);
        }
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.selectedRemoteName !== ""
        onTriggered: root.refreshQuota()
    }
}
