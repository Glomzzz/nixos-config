//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.Wallpaper
import qs.Services

ShellRoot {
    id: root

    property bool passed: false
    property int phase: 0

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function runConfigChecks() {
        const saved = JSON.parse(JSON.stringify(
            PersonalizationConfig.toJson()));
        PersonalizationConfig.loading = true;
        try {
            PersonalizationConfig.loadFromObject({
                wallpaper: {
                    path: "/tmp/legacy.png",
                    perMonitor: true,
                    monitorWallpapers: {
                        "DP-1": "/tmp/desktop.png"
                    },
                    monitorFillModes: {
                        "DP-1": "Fit"
                    },
                    transition: {
                        type: "wipe",
                        durationMs: 700,
                        easingMode: "cubic",
                        bezierCurve:
                            [0.1, 0.2, 0.3, 0.4, 1, 1]
                    }
                }
            });
            root.verify(
                PersonalizationConfig.desktopWallpaperBackend
                    === "quickshell",
                "legacy backend default");
            root.verify(PersonalizationConfig.overviewEnabled,
                "overview default");
            root.verify(
                PersonalizationConfig.overviewUseDesktopWallpaper,
                "overview source default");
            root.verify(
                PersonalizationConfig.monitorWallpapers["DP-1"]
                    === "/tmp/desktop.png",
                "legacy monitor map");
            root.verify(
                PersonalizationConfig.wallpaperFillMode
                    === "Fill"
                && PersonalizationConfig
                    .monitorWallpaperFillModes["DP-1"]
                    === "Fit",
                "legacy fill modes");
            root.verify(
                PersonalizationConfig.parallaxPreferredScale === 1.1,
                "parallax scale default");
            root.verify(
                PersonalizationConfig.needsWallpaperMigration({
                    wallpaper: {}
                }),
                "legacy migration detection");

            PersonalizationConfig.loadFromObject({
                wallpaper: {
                    desktopBackend: "awww",
                    perMonitor: true,
                    fillMode: "panorama",
                    monitorFillModes: {
                        "DP-1": "panorama",
                        "HDMI-A-1": "Fit"
                    },
                    awww: {
                        transitionType: "wave",
                        transitionFps: 120,
                        transitionStep: 177
                    },
                    overview: {
                        enabled: false,
                        useDesktopWallpaper: false,
                        path: "#112233",
                        monitorWallpapers: {
                            "DP-1": "/tmp/overview.png"
                        },
                        blurRadius: 45,
                        dim: 0.3,
                        saturation: 1.5,
                        contrast: 0.8
                    },
                    parallax: {
                        followSidebars: true,
                        preferredScale: 1.2,
                        tiledColumnSpan: 8
                    }
                }
            });
            const serialized = JSON.parse(JSON.stringify(
                PersonalizationConfig.toJson()));
            PersonalizationConfig.loadFromObject(serialized);
            root.verify(
                PersonalizationConfig.desktopWallpaperBackend
                    === "awww",
                "backend round trip");
            root.verify(
                PersonalizationConfig.awwwTransitionFps === 120,
                "FPS round trip");
            root.verify(
                PersonalizationConfig.awwwTransitionStep === 177,
                "step round trip");
            root.verify(
                PersonalizationConfig.wallpaperFillMode
                    === "panorama"
                && PersonalizationConfig
                    .monitorWallpaperFillModes["DP-1"]
                    === "panorama"
                && PersonalizationConfig
                    .monitorWallpaperFillModes["HDMI-A-1"]
                    === "Fit",
                "panorama fill modes round trip");
            root.verify(
                PersonalizationConfig.overviewWallpaperPath
                    === "#112233",
                "overview path round trip");
            root.verify(
                PersonalizationConfig
                    .overviewMonitorWallpapers["DP-1"]
                    === "/tmp/overview.png",
                "overview map round trip");
            root.verify(
                PersonalizationConfig.overviewBlurRadius === 45
                    && PersonalizationConfig.overviewDim === 0.3
                    && PersonalizationConfig.overviewSaturation === 1.5
                    && PersonalizationConfig.overviewContrast === 0.8,
                "overview numeric round trip");

            PersonalizationConfig.loadFromObject({
                wallpaper: {
                    desktopBackend: "invalid",
                    transition: {
                        durationMs: 999999
                    },
                    awww: {
                        transitionFps: "invalid",
                        transitionStep: "invalid"
                    },
                    overview: {
                        blurRadius: 999,
                        dim: -1,
                        saturation: "invalid",
                        contrast: 99,
                        fillMode: "panorama",
                        monitorFillModes: {
                            "DP-1": "panorama"
                        }
                    },
                    parallax: {
                        preferredScale: 9,
                        tiledColumnSpan: 1
                    }
                }
            });
            root.verify(
                PersonalizationConfig.desktopWallpaperBackend
                    === "quickshell",
                "invalid backend fallback");
            root.verify(
                PersonalizationConfig.awwwTransitionFps === 60,
                "invalid FPS fallback");
            root.verify(
                PersonalizationConfig.awwwTransitionStep === 90,
                "invalid step fallback");
            root.verify(
                PersonalizationConfig.transitionDurationMs === 5000,
                "transition duration clamp");
            root.verify(
                PersonalizationConfig.overviewBlurRadius === 100
                    && PersonalizationConfig.overviewDim === 0
                    && PersonalizationConfig.overviewSaturation === 1
                    && PersonalizationConfig.overviewContrast === 2,
                "overview numeric clamp");
            root.verify(
                PersonalizationConfig.overviewWallpaperFillMode
                    === "Fill"
                && PersonalizationConfig
                    .overviewMonitorFillModes["DP-1"]
                    === "Fill",
                "overview rejects panorama");
            root.verify(
                PersonalizationConfig.parallaxPreferredScale === 1.35
                    && PersonalizationConfig.parallaxTiledColumnSpan === 2,
                "parallax numeric clamp");

            root.verify(colorSurface.ready,
                "solid-color transition surface");
            root.passed = true;
        } finally {
            PersonalizationConfig.loadFromObject(saved);
            PersonalizationConfig.loading = false;
        }
    }

    Item {
        width: 64
        height: 64

        WallpaperTransitionSurface {
            id: colorSurface
            anchors.fill: parent
            sourcePath: "#112233"
        }
    }

    Timer {
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            if (!PersonalizationConfig.storeReady)
                return;
            try {
                if (root.phase === 0) {
                    root.runConfigChecks();
                    colorSurface.sourcePath =
                        "/tmp/clavis-wallpaper-does-not-exist.png";
                    root.phase = 1;
                    return;
                }
                if (colorSurface.lastError === "")
                    return;
                root.verify(
                    colorSurface.currentSource === "#112233",
                    "decode error did not retain prior wallpaper");
                stop();
                console.log(root.passed
                    ? "WALLPAPER_SMOKE_PASS"
                    : "WALLPAPER_SMOKE_FAIL");
            } catch (error) {
                stop();
                console.error("WALLPAPER_SMOKE_FAIL", error);
            }
            Qt.callLater(Qt.quit);
        }
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: {
            console.error("WALLPAPER_SMOKE_FAIL",
                "decode error timeout");
            Qt.quit();
        }
    }
}
