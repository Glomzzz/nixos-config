//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.ControlCenter
import qs.Services

ShellRoot {
    id: root

    Item {
        width: 900
        height: 1200

        WallpaperPage {
            id: wallpaperPage
            anchors.fill: parent
        }
    }

    Timer {
        interval: 250
        running: true
        onTriggered: {
            const savedMode =
                PersonalizationConfig.wallpaperFillMode;
            const savedScale =
                PersonalizationConfig.parallaxPreferredScale;
            PersonalizationConfig.loading = true;
            try {
                PersonalizationConfig.parallaxPreferredScale = 1.12;
                PersonalizationConfig.wallpaperFillMode = "panorama";
                if (!wallpaperPage.panoramaSelected
                        || wallpaperPage.effectivePreferredScale !== 1
                        || wallpaperPage.preferredScaleControlEnabled
                        || PersonalizationConfig
                            .parallaxPreferredScale !== 1.12) {
                    throw new Error(
                        "panorama scale presentation");
                }
                if (wallpaperPage.desktopFillModeOptionEnabled(
                        "panorama", true)
                        || !wallpaperPage.desktopFillModeOptionEnabled(
                            "Fill", true)) {
                    throw new Error(
                        "awww panorama option state");
                }
                PersonalizationConfig.wallpaperFillMode = "Fill";
                if (wallpaperPage.panoramaSelected
                        || wallpaperPage.effectivePreferredScale !== 1.12
                        || wallpaperPage
                            .preferredScaleControlEnabled
                            === wallpaperPage.desktopUsesAwww) {
                    throw new Error(
                        "saved preferred scale restored");
                }
                console.log("WALLPAPER_PAGE_SMOKE_PASS");
            } catch (error) {
                console.error(
                    "WALLPAPER_PAGE_SMOKE_FAIL", error);
            } finally {
                PersonalizationConfig.wallpaperFillMode = savedMode;
                PersonalizationConfig.parallaxPreferredScale =
                    savedScale;
                PersonalizationConfig.loading = false;
            }
            Qt.quit();
        }
    }
}
