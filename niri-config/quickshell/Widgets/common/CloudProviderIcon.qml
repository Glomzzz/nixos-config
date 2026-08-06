import QtQuick
import qs.Common
import qs.Components

Item {
    id: root

    property string remoteName: ""
    property string remoteType: ""
    property real iconSize: 28
    property color symbolColor: Appearance.colors.colPrimary

    readonly property string normalizedType: remoteType.toLowerCase()
    readonly property string normalizedName: remoteName.toLowerCase()
    readonly property string logoPath: {
        if (normalizedType === "drive")
            return Paths.rcloneIconsDir + "/logos--google-drive.svg";
        if (normalizedType === "onedrive")
            return Paths.rcloneIconsDir + "/logos--microsoft-onedrive.svg";
        if (normalizedType === "s3"
                && (normalizedName.indexOf("r2") >= 0
                    || normalizedName.indexOf("cloudflare") >= 0))
            return Paths.rcloneIconsDir + "/logos--cloudflare-icon.svg";
        return "";
    }
    readonly property string symbolName: {
        switch (normalizedType) {
        case "http": return "http";
        case "smb": return "lan";
        case "ftp":
        case "sftp": return "folder_shared";
        case "webdav": return "cloud_sync";
        default: return "cloud";
        }
    }

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.logoPath !== "" ? Paths.fileUrl(root.logoPath) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: root.logoPath !== ""
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: root.logoPath === ""
        text: root.symbolName
        iconSize: root.iconSize
        fill: 1
        color: root.symbolColor
    }
}
