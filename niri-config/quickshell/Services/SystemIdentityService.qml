pragma Singleton

import QtQuick
import Quickshell
import Clavis.Sysmon 1.0

Singleton {
    id: root

    readonly property string accountName: SysmonPlugin.systemUser || "user"
    readonly property string hostName: SysmonPlugin.hostName || "host"
    readonly property string accountIdentity: accountName + "@" + hostName
    readonly property string distroId: SysmonPlugin.distroId || "linux"
    readonly property string distroName: SysmonPlugin.distroName || "Linux"
    readonly property real uptimeSeconds: Math.max(0, Number(SysmonPlugin.uptimeSeconds) || 0)
    readonly property string uptimeText: formatUptime(uptimeSeconds)

    function formatUptime(value) {
        const total = Math.max(0, Math.floor(Number(value) || 0));
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (days > 0)
            return qsTr("%1 天 %2 小时").arg(days).arg(hours);
        if (hours > 0)
            return qsTr("%1 小时 %2 分钟").arg(hours).arg(minutes);
        return qsTr("%1 分钟").arg(minutes);
    }
}
