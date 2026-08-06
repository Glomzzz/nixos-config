import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services

PanelWindow {
    id: root

    visible: true
    screen: Brightness.activeScreen
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"

    anchors {
        top: true
        left: true
    }

    exclusiveZone: 0
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clavis-idle-inhibitor"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
