import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root

    property string iconName: ""
    property string title: ""
    property string supportingText: ""
    property bool interactive: false
    property bool highlighted: false
    property real iconFill: highlighted ? 1 : 0
    property alias trailing: trailingSlot.data

    signal clicked()

    implicitHeight: Math.max(56, rowLayout.implicitHeight + Appearance.spacing.small * 2)
    radius: Appearance.rounding.normal
    color: {
        if (root.highlighted)
            return Appearance.colors.colLayer3;
        if (!root.interactive)
            return "transparent";
        if (pointer.pressed)
            return Appearance.colors.colLayer2Active;
        if (pointer.containsMouse)
            return Appearance.colors.colLayer2Hover;
        return "transparent";
    }
    opacity: enabled ? 1 : 0.45

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Appearance.animation.expressiveFastEffects.type
            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
        }
    }

    RowLayout {
        id: rowLayout
        z: 1

        anchors {
            fill: parent
            leftMargin: Appearance.spacing.small
            rightMargin: Appearance.spacing.small
            topMargin: Appearance.spacing.small
            bottomMargin: Appearance.spacing.small
        }
        spacing: Appearance.spacing.small

        Rectangle {
            visible: root.iconName.length > 0
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: Appearance.rounding.full
            color: root.highlighted
                ? Appearance.colors.colPrimaryContainer
                : Appearance.colors.colLayer2

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.iconName
                iconSize: 21
                fill: root.iconFill
                color: root.highlighted
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer2
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Appearance.colors.colOnLayer2
                font.family: Sizes.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.supportingText.length > 0
                text: root.supportingText
                color: Appearance.colors.colOnLayer1
                font.family: Sizes.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }
        }

        RowLayout {
            id: trailingSlot

            Layout.alignment: Qt.AlignVCenter
            spacing: Appearance.spacing.xSmall
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.enabled && root.interactive
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
