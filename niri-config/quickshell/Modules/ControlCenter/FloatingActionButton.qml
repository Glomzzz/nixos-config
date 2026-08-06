import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root

    signal clicked()
    signal altClicked()

    property string iconText: "add"
    property string buttonText: ""
    property bool expanded: false
    property real baseSize: 56
    property real elementSpacing: 5
    property color colBackground: Appearance.colors.colPrimaryContainer
    property color colBackgroundHover: Appearance.colors.colPrimaryContainerHover
    property color colBackgroundActive: Appearance.colors.colPrimaryContainerActive
    property color colOnBackground: Appearance.colors.colOnPrimaryContainer

    Layout.alignment: Qt.AlignLeft
    implicitWidth: root.expanded ? Math.max(contentRow.implicitWidth + 20, root.baseSize) : root.baseSize
    implicitHeight: root.baseSize
    radius: root.baseSize / 14 * 4
    color: mouse.pressed ? root.colBackgroundActive : mouse.containsMouse ? root.colBackgroundHover : root.colBackground

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    Row {
        id: contentRow

        property real horizontalMargins: (root.baseSize - icon.width) / 2

        anchors.left: parent.left
        anchors.leftMargin: horizontalMargins
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        MaterialSymbol {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            iconSize: 26
            color: root.colOnBackground
            text: root.iconText
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: root.expanded ? buttonText.implicitWidth + root.elementSpacing + contentRow.horizontalMargins : 0
            height: parent.height
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Text {
                id: buttonText

                anchors.left: parent.left
                anchors.leftMargin: root.elementSpacing
                anchors.verticalCenter: parent.verticalCenter
                text: root.buttonText
                color: root.colOnBackground
                font.family: Sizes.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.altClicked();
            else
                root.clicked();
        }
    }
}
