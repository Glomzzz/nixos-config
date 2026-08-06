import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    property alias headerTools: headerToolsLayout.data
    default property alias content: contentLayout.data
    property var closeAction: () => {}
    property bool showBackButton: false
    property var backAction: closeAction


    // 剥离背景色与边框，让底部固定的液态遮罩透出来！
    color: "transparent"
    border.color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.spacing.panelPadding
        spacing: 16

        RowLayout {
            Layout.fillWidth: true

            ToolButton {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                visible: root.showBackButton
                hoverEnabled: true
                Accessible.name: qsTr("Back to Quick Settings")
                onClicked: root.backAction()

                background: Rectangle {
                    radius: Appearance.rounding.full
                    color: parent.down
                        ? Appearance.colors.colLayer2Active
                        : parent.hovered ? Appearance.colors.colLayer2Hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.expressiveFastEffects.duration
                            easing.type: Appearance.animation.expressiveFastEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                        }
                    }
                }

                contentItem: MaterialSymbol {
                    text: "arrow_back"
                    iconSize: 22
                    color: Appearance.colors.colOnLayer2
                }
            }

            MaterialSymbol {
                visible: !root.showBackButton
                text: root.icon
                iconSize: 22
                color: Appearance.colors.colPrimary
                Layout.preferredWidth: 22
                Layout.preferredHeight: 40
            }

            Text {
                text: root.title
                font.family: Sizes.fontFamily
                font.bold: true
                font.pixelSize: 18
                color: Appearance.colors.colOnLayer2
                Layout.fillWidth: true
                Layout.leftMargin: root.showBackButton ? 0 : 10
                elide: Text.ElideRight
            }

            RowLayout { id: headerToolsLayout; spacing: 12 }
        }

        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true; Layout.fillHeight: true
        }
    }
}
