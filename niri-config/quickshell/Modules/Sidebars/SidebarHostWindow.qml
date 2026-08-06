import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.Sidebars.Left
import qs.Modules.Sidebars.Right
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    readonly property bool anySidebarOpen:
        WidgetState.leftSidebarOpen || WidgetState.qsOpen
    readonly property var fallbackScreen: Brightness.activeScreen
        || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    // DPMS cycles can replace the Screen instance while preserving its name.
    property string retainedScreenName: ""
    readonly property var retainedScreen:
        Brightness.getScreenByName(retainedScreenName)

    screen: retainedScreen || fallbackScreen
    visible: retainedScreen !== null || fallbackScreen !== null
    color: "transparent"
    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080
    exclusiveZone: 0

    anchors {
        left: true
        top: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-shell-sidebars"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: root.anySidebarOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: root.anySidebarOpen ? interactionRegion : null
    }

    Component.onCompleted: {
        if (root.fallbackScreen)
            root.retainedScreenName = root.fallbackScreen.name;
        if (root.anySidebarOpen)
            Qt.callLater(() => keyGateway.forceActiveFocus());
    }

    onAnySidebarOpenChanged: {
        if (root.anySidebarOpen)
            Qt.callLater(() => keyGateway.forceActiveFocus());
    }

    Connections {
        target: WidgetState

        function onQsScreenNameChanged() {
            const requestedScreen =
                Brightness.getScreenByName(WidgetState.qsScreenName);
            if (requestedScreen)
                root.retainedScreenName = requestedScreen.name;
        }

        function onLeftSidebarOpenChanged() {
            if (WidgetState.leftSidebarOpen && !WidgetState.qsOpen
                    && Brightness.activeScreen)
                root.retainedScreenName = Brightness.activeScreen.name;
        }
    }

    Item {
        id: interactionRegion

        anchors.fill: parent
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.anySidebarOpen
        acceptedButtons: Qt.LeftButton

        onClicked: mouse => {
            if (WidgetState.leftSidebarOpen
                    && !leftSidebar.containsPoint(mouse.x, mouse.y))
                WidgetState.leftSidebarOpen = false;

            if (WidgetState.qsOpen
                    && !rightSidebar.containsPoint(mouse.x, mouse.y))
                WidgetState.qsOpen = false;
        }
    }

    LeftSidebarWindow {
        id: leftSidebar

        anchors.fill: parent
        panelScreen: root.screen
    }

    RightSidebar {
        id: rightSidebar

        anchors.fill: parent
        panelScreen: root.screen
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: leftSidebar.blurBackgroundItem
        additionalBackgroundItems: [
            rightSidebar.blurBackgroundItem
        ]
    }

    Item {
        id: keyGateway

        anchors.fill: parent
        focus: root.anySidebarOpen

        Keys.onEscapePressed: event => {
            WidgetState.closeAllPopups();
            event.accepted = true;
        }
    }
}
