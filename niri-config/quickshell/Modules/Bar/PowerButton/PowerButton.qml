import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    // 警告红
    color: Appearance.colors.colError
    radius: height / 2
    implicitHeight: 28
    implicitWidth: 28

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached([
            Paths.systemScriptsDir + "/power-menu.sh",
            PersonalizationConfig.powerMenuStyle
        ])
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "⏻"
        font.pixelSize: 14
        font.bold: true
        color: Appearance.colors.colOnError
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: qsTr("Power menu")
    }
}
