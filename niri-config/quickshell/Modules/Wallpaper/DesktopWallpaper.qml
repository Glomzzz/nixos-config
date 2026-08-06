import QtQuick
import Quickshell
import Quickshell.Wayland
import Clavis.Niri 1.0
import qs.Common
import qs.Services
import "../../Common/functions/WallpaperMath.js" as WallpaperMath

Variants {
    id: variants

    model: Quickshell.screens
    property var lastFocusedHorizontalColumnByWorkspace: ({})

    function rememberFocusedWindow() {
        const next = WallpaperMath.rememberFocusedHorizontalColumn(
            variants.lastFocusedHorizontalColumnByWorkspace,
            Niri.focusedWindow);
        if (next !== variants.lastFocusedHorizontalColumnByWorkspace)
            variants.lastFocusedHorizontalColumnByWorkspace = next;
    }

    function resolveHorizontalColumn(workspace, columns) {
        const workspaceId = workspace && workspace.id
            ? workspace.id : 0;
        if (!workspaceId || !columns || columns.length === 0)
            return 0;

        variants.rememberFocusedWindow();
        const workspaceKey = String(workspaceId);
        let preferred = Number(
            variants.lastFocusedHorizontalColumnByWorkspace[
                workspaceKey]);

        if (!isFinite(preferred) || preferred <= 0) {
            const activeWindow = Niri.windowById(
                workspace.activeWindowId || 0);
            if (WallpaperMath.isHorizontalTiledWindow(activeWindow))
                preferred = Number(activeWindow.layoutColumn);
        }

        const resolved = WallpaperMath.nearestHorizontalColumn(
            columns, preferred);
        const remembered =
            variants.lastFocusedHorizontalColumnByWorkspace[
                workspaceKey];
        if (Number(remembered) !== resolved) {
            const next = {};
            const current =
                variants.lastFocusedHorizontalColumnByWorkspace;
            for (let key in current)
                next[key] = current[key];
            next[workspaceKey] = resolved;
            variants.lastFocusedHorizontalColumnByWorkspace = next;
        }
        return resolved;
    }

    PanelWindow {
        id: wallpaperWindow

        required property var modelData

        screen: modelData
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "clavis-wallpaper"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        mask: Region {
            item: Item {}
        }

        Item {
            id: root

            anchors.fill: parent
            clip: true
            visible: AwwwWallpaperService.quickshellContentVisible

            property int serviceRevision: WallpaperService.revision
            property int settingsRevision:
                WallpaperService.settingsRevision
            property var outputWorkspaces: []
            property var activeWorkspace: ({})
            property var horizontalColumns: []
            property int focusedHorizontalColumn: 0

            readonly property string targetSource:
                serviceRevision >= 0
                    ? WallpaperService
                        .wallpaperForScreen(modelData.name)
                    : ""
            readonly property string targetFillModeName:
                settingsRevision >= 0
                    ? WallpaperService
                        .fillModeForScreen(modelData.name)
                    : "Fill"
            readonly property int targetFillMode:
                WallpaperService.qtFillMode(targetFillModeName)
            readonly property real targetShaderFillMode:
                WallpaperService.shaderFillMode(targetFillModeName)
            readonly property bool panoramaSelected:
                targetFillModeName === "panorama"
            readonly property bool hasHorizontalDriver:
                PersonalizationConfig.parallaxFollowTiledColumns
                || PersonalizationConfig.parallaxFollowSidebars
            readonly property bool hasVerticalDriver:
                PersonalizationConfig.parallaxVerticalEnabled
                && PersonalizationConfig.parallaxFollowWorkspaces
            readonly property bool parallaxRequested:
                hasHorizontalDriver || hasVerticalDriver
            readonly property bool parallaxSupported:
                WallpaperMath.supportsParallaxCanvas(
                    !panoramaSelected
                        && targetFillMode === Image.PreserveAspectCrop,
                    targetSource,
                    WallpaperService.isColorSource(targetSource))
            readonly property bool manualParallaxActive:
                parallaxRequested && parallaxSupported
            readonly property real preferredScale:
                panoramaSelected
                    ? 1
                    : manualParallaxActive
                    ? PersonalizationConfig.parallaxPreferredScale : 1
            readonly property var parallaxCanvas:
                WallpaperMath.parallaxCanvasGeometry(
                    width, height, preferredScale,
                    manualParallaxActive)
            readonly property real scaledWidth:
                parallaxCanvas.scaledWidth
            readonly property real scaledHeight:
                parallaxCanvas.scaledHeight
            readonly property real overflowX:
                parallaxCanvas.overflowX
            readonly property real overflowY:
                parallaxCanvas.overflowY
            readonly property real tiledProgress: {
                if (!PersonalizationConfig
                        .parallaxFollowTiledColumns)
                    return 0.5;
                return WallpaperMath.focusedColumnProgress(
                    horizontalColumns,
                    focusedHorizontalColumn,
                    PersonalizationConfig.parallaxTiledColumnSpan);
            }
            readonly property bool leftSidebarOnThisScreen:
                WidgetState.leftSidebarOpen
                && Brightness.activeScreen
                && Brightness.activeScreen.name === modelData.name
            readonly property string rightSidebarScreenName:
                WidgetState.qsScreenName !== ""
                    ? WidgetState.qsScreenName
                    : (Brightness.activeScreen
                        ? Brightness.activeScreen.name : "")
            readonly property bool rightSidebarOnThisScreen:
                WidgetState.qsOpen
                && rightSidebarScreenName === modelData.name
            readonly property real sidebarStep:
                PersonalizationConfig.parallaxPreferredScale
                / Math.max(2,
                    PersonalizationConfig.parallaxTiledColumnSpan)
                / 2
            readonly property real horizontalProgress: {
                return WallpaperMath.horizontalProgress(
                    tiledProgress,
                    PersonalizationConfig.parallaxFollowSidebars
                        && leftSidebarOnThisScreen,
                    PersonalizationConfig.parallaxFollowSidebars
                        && rightSidebarOnThisScreen,
                    sidebarStep);
            }
            property real panoramaHorizontalProgress:
                horizontalProgress
            readonly property real verticalProgress: {
                if (!PersonalizationConfig.parallaxVerticalEnabled
                        || !PersonalizationConfig
                            .parallaxFollowWorkspaces)
                    return 0.5;
                return WallpaperMath.workspaceProgress(
                    outputWorkspaces);
            }

            Behavior on panoramaHorizontalProgress {
                enabled: root.panoramaSelected

                NumberAnimation {
                    duration: Appearance.animation
                        .wallpaperParallax.duration
                    easing.type: Appearance.animation
                        .wallpaperParallax.type
                }
            }

            function clamp01(value) {
                return WallpaperMath.clamp01(value);
            }

            function refreshNiriState() {
                root.outputWorkspaces =
                    Niri.workspacesForOutput(modelData.name);
                root.activeWorkspace =
                    Niri.activeWorkspaceForOutput(modelData.name);
                const workspaceId = root.activeWorkspace
                    && root.activeWorkspace.id
                    ? root.activeWorkspace.id : 0;
                const windows = workspaceId
                    ? Niri.windowsForWorkspace(workspaceId) : [];
                root.horizontalColumns =
                    WallpaperMath.horizontalColumns(windows);
                root.focusedHorizontalColumn =
                    variants.resolveHorizontalColumn(
                        root.activeWorkspace,
                        root.horizontalColumns);
            }

            Component.onCompleted: root.refreshNiriState()

            Connections {
                target: Niri

                function onWorkspacesChanged() {
                    root.refreshNiriState();
                }

                function onWindowsChanged() {
                    root.refreshNiriState();
                }

                function onOutputsChanged() {
                    root.refreshNiriState();
                }
            }

            WallpaperTransitionSurface {
                id: renderer

                x: !root.panoramaSelected && root.overflowX > 0
                    ? WallpaperMath.wallpaperPosition(
                        root.overflowX, root.horizontalProgress)
                    : 0
                y: !root.panoramaSelected && root.overflowY > 0
                    ? WallpaperMath.wallpaperPosition(
                        root.overflowY, root.verticalProgress)
                    : 0
                width: root.panoramaSelected
                    ? Math.max(1, root.width)
                    : Math.max(1, root.scaledWidth)
                height: root.panoramaSelected
                    ? Math.max(1, root.height)
                    : Math.max(1, root.scaledHeight)
                sourcePath: root.targetSource
                imageFillMode: root.targetFillMode
                shaderFillMode: root.targetShaderFillMode
                panoramaEnabled: root.panoramaSelected
                    && !WallpaperService.isColorSource(root.targetSource)
                horizontalProgress:
                    root.panoramaHorizontalProgress
                transitionType:
                    PersonalizationConfig.wallpaperTransitionType
                includedTransitions:
                    PersonalizationConfig.includedTransitions
                transitionDurationMs:
                    PersonalizationConfig.transitionDurationMs
                transitionEasingMode:
                    PersonalizationConfig.transitionEasingMode
                transitionBezierCurve:
                    PersonalizationConfig.transitionBezierCurve
                transitionsEnabled:
                    AwwwWallpaperService.quickshellContentVisible
                textureWidth: Math.min(
                    Math.max(1, Math.round(root.width)), 8192)
                textureHeight: Math.min(
                    Math.max(1, Math.round(root.height)), 8192)

                onLoadFailed: (source, message) => {
                    WallpaperService.reportDesktopError(
                        modelData.name, message);
                }

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.animation
                            .wallpaperParallax.duration
                        easing.type: Appearance.animation
                            .wallpaperParallax.type
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: Appearance.animation
                            .wallpaperParallax.duration
                        easing.type: Appearance.animation
                            .wallpaperParallax.type
                    }
                }
            }
        }
    }
}
