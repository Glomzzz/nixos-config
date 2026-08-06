import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    property var trayItemMenuHandle: null
    property string trayItemId: ""
    property var anchorItem: null
    property real padding: 10
    property real edgeMargin: 10
    property real anchorGap: 4
    property real menuX: edgeMargin
    property real menuY: edgeMargin
    property var submenuStack: []
    property bool submenuLoading: false
    property int submenuRefreshAttempt: 0
    readonly property int menuDepth: submenuStack.length
    readonly property var currentSubmenuEntry: menuDepth > 0 ? submenuStack[menuDepth - 1] : null
    readonly property var currentSubmenuHandle: currentSubmenuEntry
                                                 ? (currentSubmenuEntry.menu || currentSubmenuEntry)
                                                 : null

    signal menuClosed()
    signal menuOpened(var qsWindow)

    visible: false
    color: "transparent"
    exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-shell-tray-menu"
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    mask: Region { item: inputRegion }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function refreshMenuHandle(handle) {
        if (handle && typeof handle.updateLayout === "function")
            handle.updateLayout();
    }

    function beginSubmenuRefresh() {
        if (root.menuDepth === 0)
            return;

        root.submenuRefreshAttempt = 0;
        root.submenuLoading = true;
        root.refreshMenuHandle(root.currentSubmenuHandle);
        submenuRefreshTimer.restart();
    }

    function pushSubmenu(entry) {
        if (!entry || entry.hasChildren !== true)
            return;

        const nextStack = root.submenuStack.slice();
        nextStack.push(entry);
        root.submenuStack = nextStack;
        root.beginSubmenuRefresh();
        Qt.callLater(root.updatePosition);
    }

    function popSubmenu() {
        if (root.menuDepth === 0)
            return;

        submenuRefreshTimer.stop();
        root.submenuLoading = false;

        const nextStack = root.submenuStack.slice(0, -1);
        root.submenuStack = nextStack;
        if (root.menuDepth > 0)
            root.beginSubmenuRefresh();
        Qt.callLater(root.updatePosition);
    }

    function resetSubmenus() {
        submenuRefreshTimer.stop();
        root.submenuLoading = false;
        root.submenuRefreshAttempt = 0;
        root.submenuStack = [];
    }

    function updatePosition() {
        const surfaceWidth = Math.max(1, menuSurface.implicitWidth);
        const surfaceHeight = Math.max(1, menuSurface.implicitHeight);
        const availableWidth = Math.max(surfaceWidth + root.edgeMargin * 2, root.width);
        const availableHeight = Math.max(surfaceHeight + root.edgeMargin * 2, root.height);

        if (!root.anchorItem) {
            root.menuX = root.clamp((availableWidth - surfaceWidth) / 2, root.edgeMargin, availableWidth - surfaceWidth - root.edgeMargin);
            root.menuY = root.edgeMargin;
            return;
        }

        const globalPos = root.anchorItem.mapToGlobal(0, 0);
        const screenX = root.screen ? (root.screen.x || 0) : 0;
        const screenY = root.screen ? (root.screen.y || 0) : 0;
        const anchorX = globalPos.x - screenX;
        const anchorY = globalPos.y - screenY;
        const anchorWidth = root.anchorItem.width || 0;
        const anchorHeight = root.anchorItem.height || 0;

        root.menuX = root.clamp(
            anchorX + anchorWidth / 2 - surfaceWidth / 2,
            root.edgeMargin,
            availableWidth - surfaceWidth - root.edgeMargin
        );

        const belowY = anchorY + anchorHeight + root.anchorGap;
        const aboveY = anchorY - surfaceHeight - root.anchorGap;
        const maxY = availableHeight - surfaceHeight - root.edgeMargin;
        root.menuY = belowY <= maxY || aboveY < root.edgeMargin
            ? root.clamp(belowY, root.edgeMargin, maxY)
            : root.clamp(aboveY, root.edgeMargin, maxY);
    }

    function open() {
        root.resetSubmenus();
        root.visible = true;
        root.menuOpened(root);
        Qt.callLater(() => {
            root.updatePosition();
            keyScope.forceActiveFocus();
        });
    }

    function close() {
        if (!root.visible && root.menuDepth === 0)
            return;

        root.visible = false;
        root.resetSubmenus();
        root.menuClosed();
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => {
                root.updatePosition();
                keyScope.forceActiveFocus();
            });
    }

    Item {
        id: inputRegion
        anchors.fill: parent
    }

    Timer {
        id: submenuRefreshTimer

        interval: 150
        repeat: true

        onTriggered: {
            if (root.menuDepth === 0) {
                stop();
                root.submenuLoading = false;
                return;
            }

            if (menuContent.menuEntries.length > 0) {
                stop();
                root.submenuLoading = false;
                return;
            }

            root.submenuRefreshAttempt += 1;
            root.refreshMenuHandle(root.currentSubmenuHandle);
            if (root.submenuRefreshAttempt >= 5) {
                stop();
                root.submenuLoading = false;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        z: -1

        onClicked: event => {
            const outsideMenu = event.x < menuSurface.x
                || event.x > menuSurface.x + menuSurface.width
                || event.y < menuSurface.y
                || event.y > menuSurface.y + menuSurface.height;
            if (outsideMenu)
                root.close();
        }
    }

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: root.visible

        Keys.onEscapePressed: event => {
            if (root.menuDepth > 0)
                root.popSubmenu();
            else
                root.close();
            event.accepted = true;
        }

        QsMenuOpener {
            id: rootMenuOpener
            menu: root.trayItemMenuHandle
        }

        QsMenuOpener {
            id: submenuOpener
            menu: root.currentSubmenuHandle
        }

        Item {
            id: menuSurface

            x: root.menuX
            y: root.menuY
            implicitWidth: popupBackground.implicitWidth + root.padding * 2
            implicitHeight: popupBackground.implicitHeight + root.padding * 2
            width: implicitWidth
            height: implicitHeight

            onImplicitWidthChanged: Qt.callLater(root.updatePosition)
            onImplicitHeightChanged: Qt.callLater(root.updatePosition)

            StyledRectangularShadow {
                target: popupBackground
                opacity: popupBackground.opacity
            }

            Rectangle {
                id: popupBackground

                readonly property real popupPadding: 4

                x: root.padding
                y: root.padding
                implicitWidth: menuContent.implicitWidth + popupPadding * 2
                implicitHeight: menuContent.implicitHeight + popupPadding * 2
                color: BlurService.backgroundColor(
                    Appearance.colors.colLayer0)
                radius: 18
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                clip: true
                opacity: 0

                Component.onCompleted: opacity = 1

                Behavior on opacity {
                    NumberAnimation {
                        alwaysRunToEnd: true
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
                Behavior on implicitWidth {
                    NumberAnimation {
                        alwaysRunToEnd: true
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                Behavior on implicitHeight {
                    NumberAnimation {
                        alwaysRunToEnd: true
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }

                MenuContent {
                    id: menuContent

                    anchors {
                        fill: parent
                        margins: popupBackground.popupPadding
                    }

                    onImplicitWidthChanged: Qt.callLater(root.updatePosition)
                    onImplicitHeightChanged: Qt.callLater(root.updatePosition)
                }
            }
        }
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: popupBackground
    }

    component MenuContent: ColumnLayout {
        id: submenu

        readonly property var menuModel: root.menuDepth > 0 ? submenuOpener.children : rootMenuOpener.children
        readonly property var menuEntries: menuModel ? menuModel.values : []
        spacing: 0

        onMenuEntriesChanged: {
            if (root.menuDepth > 0 && menuEntries.length > 0) {
                submenuRefreshTimer.stop();
                root.submenuLoading = false;
                root.submenuRefreshAttempt = 0;
            } else if (root.menuDepth > 0 && root.visible && !root.submenuLoading) {
                root.beginSubmenuRefresh();
            }
            Qt.callLater(root.updatePosition);
        }

        Loader {
            Layout.fillWidth: true
            visible: root.menuDepth > 0
            active: visible

            sourceComponent: MaterialRippleButton {
                id: backButton

                buttonRadius: popupBackground.radius - popupBackground.popupPadding
                colBackground: Appearance.transparentize(Appearance.colors.colLayer0, 1)
                colBackgroundHover: Appearance.colors.colSecondaryContainer
                colRipple: Appearance.colors.colSecondaryContainerActive
                rippleEnabled: false
                implicitWidth: backContent.implicitWidth + 24
                implicitHeight: 36
                Layout.fillWidth: true
                releaseAction: () => root.popSubmenu()

                contentItem: RowLayout {
                    id: backContent

                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 8

                    MaterialSymbol {
                        text: "chevron_left"
                        iconSize: 20
                        color: backButton.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                    }

                    Text {
                        text: qsTr("返回")
                        color: backButton.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                        font.family: Sizes.fontFamily
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                }
            }
        }

        MaterialRippleButton {
            id: pinEntry

            visible: root.trayItemId.length > 0 && root.menuDepth === 0
            buttonRadius: popupBackground.radius - popupBackground.popupPadding
            colBackground: Appearance.transparentize(Appearance.colors.colLayer0, 1)
            colBackgroundHover: Appearance.colors.colSecondaryContainer
            colRipple: Appearance.colors.colSecondaryContainerActive
            rippleEnabled: false
            implicitWidth: pinContent.implicitWidth + 24
            implicitHeight: 36
            Layout.fillWidth: true
            releaseAction: () => TrayService.togglePin(root.trayItemId)

            contentItem: RowLayout {
                id: pinContent

                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 8

                MaterialSymbol {
                    text: "push_pin"
                    iconSize: 18
                    color: pinEntry.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                }

                Text {
                    text: TrayService.isPinned(root.trayItemId)
                        ? qsTr("取消固定") : qsTr("固定")
                    color: pinEntry.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colSubtext
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        RowLayout {
            visible: root.menuDepth > 0 && submenu.menuEntries.length === 0
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            spacing: 8

            MaterialSymbol {
                text: root.submenuLoading ? "progress_activity" : "inbox"
                iconSize: 18
                color: Appearance.colors.colOnSurfaceVariant

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.submenuLoading
                }
            }

            Text {
                text: root.submenuLoading ? qsTr("正在加载…") : qsTr("暂无可用项目")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Sizes.fontFamily
                font.pixelSize: 13
                Layout.fillWidth: true
            }
        }

        Repeater {
            id: menuEntriesRepeater

            property bool iconColumnNeeded: {
                for (let i = 0; i < submenu.menuEntries.length; i += 1) {
                    if ((submenu.menuEntries[i].icon || "").length > 0)
                        return true;
                }
                return false;
            }
            property bool specialInteractionColumnNeeded: {
                for (let i = 0; i < submenu.menuEntries.length; i += 1) {
                    if (submenu.menuEntries[i].buttonType !== QsMenuButtonType.None)
                        return true;
                }
                return false;
            }

            model: submenu.menuModel

            delegate: TrayMenuEntry {
                required property var modelData

                menuEntry: modelData
                forceIconColumn: menuEntriesRepeater.iconColumnNeeded
                forceSpecialInteractionColumn: menuEntriesRepeater.specialInteractionColumnNeeded
                buttonRadius: popupBackground.radius - popupBackground.popupPadding

                onDismiss: root.close()
                onOpenSubmenu: handle => root.pushSubmenu(handle)
            }
        }
    }
}
