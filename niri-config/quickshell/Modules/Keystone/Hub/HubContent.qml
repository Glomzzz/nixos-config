import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Components

import qs.Modules.Keystone.DashboardContent
import qs.Modules.Keystone.Media
import qs.Modules.Keystone.WallpaperContent
import qs.Modules.Keystone.WeatherContent

Item {
    id: root
    signal closeRequested()
    signal avatarEditRequested()

    property var player: null
    property var screen: null
    property int currentIndex: 0
    property bool active: false

    Shortcut {
        sequence: "Tab"
        enabled: root.active
        onActivated: root.currentIndex = (root.currentIndex + 1) % 4
    }

    Shortcut {
        sequence: "Shift+Tab"
        enabled: root.active
        onActivated: root.currentIndex = (root.currentIndex + 3) % 4
    }

    implicitWidth: currentIndex === 0 ? 860 :
                   currentIndex === 2 ? 960 :
                   currentIndex === 3 ? 960 :
                   760
    Behavior on implicitWidth { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    implicitHeight: 80 + 20 + (
        currentIndex === 0 ? 520 :
        currentIndex === 1 ? 480 :
        currentIndex === 2 ? 300 :
        570
    )
    Behavior on implicitHeight { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    RowLayout {
        id: tabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        anchors.margins: 10
        spacing: 15

        component TabBtn : Item {
            property string icon: ""
            property string title: ""
            property int index: 0
            property bool active: root.currentIndex === index

            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: parent.parent.icon
                    iconSize: 22
                    fill: parent.parent.active ? 1 : 0
                    color: parent.parent.active
                           ? Appearance.colors.colOnLayer0
                           : Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.50)
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: parent.parent.title
                    font.pixelSize: 13
                    font.bold: parent.parent.active
                    color: parent.parent.active
                           ? Appearance.colors.colOnLayer0
                           : Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.50)
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.active ? 40 : 0
                height: 3
                radius: 1.5
                color: Appearance.colors.colPrimary
                opacity: parent.active ? 1.0 : 0.0
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentIndex = parent.index
            }
        }

        TabBtn { icon: "dashboard"; title: qsTr("Dashboard"); index: 0 }
        TabBtn { icon: "queue_music"; title: qsTr("Media"); index: 1 }
        TabBtn { icon: "wallpaper"; title: qsTr("Wallpaper"); index: 2 }
        TabBtn { icon: "sunny"; title: qsTr("Weather"); index: 3 }
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 10

        RetainedPageLoader {
            id: dashboardLoader

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            presented: root.active && root.currentIndex === 0
            sourceComponent: dashboardComponent
        }

        RetainedPageLoader {
            id: mediaLoader

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            presented: root.active && root.currentIndex === 1
            sourceComponent: mediaComponent
        }

        RetainedPageLoader {
            id: wallpaperLoader

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.95
            height: 300
            presented: root.active && root.currentIndex === 2
            sourceComponent: wallpaperComponent
        }

        RetainedPageLoader {
            id: weatherLoader

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            presented: root.active && root.currentIndex === 3
            sourceComponent: weatherComponent
        }
    }

    Component {
        id: dashboardComponent

        DashboardContent {
            player: root.player
            screen: root.screen
            active: dashboardLoader.presented
            onCloseRequested: root.closeRequested()
            onAvatarEditRequested: root.avatarEditRequested()
        }
    }

    Component {
        id: mediaComponent

        Media {
            player: root.player
            active: mediaLoader.presented
        }
    }

    Component {
        id: wallpaperComponent

        WallpaperContent {
            anchors.fill: parent
            screen: root.screen
            onWallpaperChanged: root.closeRequested()
        }
    }

    Component {
        id: weatherComponent

        WeatherContent {
            active: weatherLoader.presented
        }
    }
}
