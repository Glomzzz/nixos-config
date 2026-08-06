import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.Common
import qs.Widgets.common

Item {
    id: toolsRoot

    ToolsBackend {
        id: toolsBackend
    }

    signal requestHideKeystone()

    property var toolsModel: [
        { action: "color", icon: "colorize", tip: qsTr("Color picker") },
        { action: "video", icon: "videocam", tip: qsTr("Record screen") },
        { action: "gif", icon: "gif", tip: qsTr("Record GIF") },
        { action: "screenshot", icon: "crop_free", tip: qsTr("Screenshot") },
        { action: "microphone", icon: "mic", tip: qsTr("Record microphone") },
        { action: "systemAudio", icon: "speaker", tip: qsTr("Record system audio") }
    ]

    property int selectedIndex: 0

    focus: visible
    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            forceActiveFocus();
        }
    }

    Keys.onLeftPressed: {
        selectedIndex = (selectedIndex - 1 + toolsModel.length) % toolsModel.length
    }

    Keys.onRightPressed: {
        selectedIndex = (selectedIndex + 1) % toolsModel.length
    }

    Keys.onReturnPressed: triggerSelected()
    Keys.onEnterPressed: triggerSelected()

    function triggerSelected() {
        const tool = toolsModel[selectedIndex]
        if (!tool)
            return

        toolsRoot.requestHideKeystone()

        if (tool.action === "color") {
            toolsBackend.pickColor()
        } else if (tool.action === "video") {
            toolsBackend.startRecord("video")
        } else if (tool.action === "gif") {
            toolsBackend.startRecord("gif")
        } else if (tool.action === "screenshot") {
            toolsBackend.takeScreenshot()
        } else if (tool.action === "microphone") {
            toolsBackend.startAudio("mic")
        } else if (tool.action === "systemAudio") {
            toolsBackend.startAudio("system")
        }
    }

    function stopRecording() {
        toolsBackend.stopRecord()
    }
    function stopAudio() {
        toolsBackend.stopAudio()
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: toolsRoot.toolsModel

            Rectangle {
                width: 48
                height: 48
                radius: 12

                color: (toolsMouse.containsMouse || index === toolsRoot.selectedIndex)
                    ? Appearance.colors.colLayer2Hover : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 22
                    color: Appearance.colors.colOnSurface
                }

                MouseArea {
                    id: toolsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: toolsRoot.selectedIndex = index

                    onClicked: {
                        toolsRoot.selectedIndex = index
                        toolsRoot.triggerSelected()
                    }
                }

                StyledToolTip {
                    extraVisibleCondition: toolsMouse.containsMouse
                    text: modelData.tip
                }
            }
        }
    }
}
