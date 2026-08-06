//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.Wallpaper

ShellRoot {
    id: root

    property int phase: 0
    property string widePath:
        Quickshell.shellDir + "/tests/fixtures/panorama-wide.svg"
    property string widerPath:
        Quickshell.shellDir + "/tests/fixtures/panorama-wider.svg"

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    Item {
        width: 320
        height: 180

        WallpaperTransitionSurface {
            id: surface

            anchors.fill: parent
            sourcePath: root.widePath
            panoramaEnabled: true
            horizontalProgress: 0.5
            transitionType: "fade"
            transitionDurationMs: 80
            transitionsEnabled: true
            textureWidth: 320
            textureHeight: 180
        }
    }

    Timer {
        interval: 10
        repeat: true
        running: true

        onTriggered: {
            try {
                if (root.phase === 0) {
                    if (!surface.ready)
                        return;
                    root.verify(surface.width === 320
                            && surface.height === 180,
                        "fixed transition viewport");
                    root.verify(
                        surface.currentViewportGeometry.active,
                        "wide panorama active: "
                            + JSON.stringify(
                                surface.currentViewportGeometry)
                            + " image="
                            + surface.imagePixelWidth
                            + "x" + surface.imagePixelHeight);
                    root.verify(Math.round(surface
                            .currentViewportGeometry.canvasWidth)
                            === 640,
                        "current panorama width");
                    root.verify(Math.round(surface.currentViewportX)
                            === -160,
                        "current panorama midpoint");
                    surface.sourcePath = root.widerPath;
                    root.phase = 1;
                    return;
                }

                if (root.phase === 1) {
                    if (!surface.effectActive)
                        return;
                    root.verify(surface.width === 320
                            && surface.height === 180,
                        "viewport stable during transition");
                    root.verify(Math.round(surface
                            .currentViewportGeometry.canvasWidth)
                            === 640,
                        "current geometry retained");
                    root.verify(Math.round(surface
                            .nextViewportGeometry.canvasWidth)
                            === 960,
                        "next geometry independent");
                    root.verify(Math.round(surface.currentViewportX)
                            === -160
                            && Math.round(surface.nextViewportX)
                            === -320,
                        "shared progress with independent overflow");
                    root.phase = 2;
                    return;
                }

                if (root.phase === 2) {
                    if (surface.effectActive
                            || surface.currentSource
                                !== root.widerPath)
                        return;
                    root.verify(surface.ready,
                        "promoted viewport remains ready");
                    root.verify(Math.round(surface
                            .currentViewportGeometry.canvasWidth)
                            === 960,
                        "ready viewport promoted without reload");
                    stop();
                    console.log("PANORAMA_SMOKE_PASS");
                    Qt.quit();
                }
            } catch (error) {
                stop();
                console.error("PANORAMA_SMOKE_FAIL", error);
                Qt.quit();
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: {
            console.error("PANORAMA_SMOKE_FAIL", "timeout");
            Qt.quit();
        }
    }
}
