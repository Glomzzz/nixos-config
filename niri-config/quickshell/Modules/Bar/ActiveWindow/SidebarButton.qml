import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common
import qs.Services

Item {
    id: root

    property var screen: null

    implicitHeight: 36
    implicitWidth: buttonRow.implicitWidth + 16

    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: BlurService.backgroundColor(
            Appearance.colors.colLayer0)
        radius: height / 2
        visible: false
    }

    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Qt.alpha(Appearance.colors.colShadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
    }

    RowLayout {
        id: buttonRow
        anchors.centerIn: parent
        spacing: 8

        SidebarPillButton {
            screen: root.screen
            viewName: "info"
            iconName: "notifications"
            activeColor: Appearance.colors.colSecondary
            activeContentColor: Appearance.colors.colOnSecondary
        }

        SidebarPillButton {
            screen: root.screen
            viewName: "sys"
            iconName: "memory"
            activeColor: Appearance.colors.colTertiary
            activeContentColor: Appearance.colors.colOnTertiary
        }

        SidebarWeatherButton {
            screen: root.screen
        }
    }
}
