import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import "./notifications"
import "./infoTools"

Item {
    id: root

    property string screenName: ""
    property bool foreground: false

    readonly property bool isForeground: root.foreground
    onIsForegroundChanged: {
        if (isForeground) {
            NotificationManager.timeoutAll();
            NotificationManager.markAllRead();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        ProfileHeaderCard {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            screenName: root.screenName
        }

        NotificationList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        InfoToolDrawer {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            active: root.isForeground
        }
    }
}
