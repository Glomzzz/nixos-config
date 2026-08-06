//@ pragma UseQApplication

import QtQuick
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Modules.ControlCenter

ShellRoot {
    Window {
        id: previewWindow

        visible: true
        width: 900
        height: 1200
        color: Appearance.m3colors.m3background

        WallpaperPage {
            id: wallpaperPage
            anchors.fill: parent
        }
    }

    Timer {
        interval: 800
        running: true
        onTriggered: {
            wallpaperPage.grabToImage(result => {
                result.saveToFile(
                    "/tmp/clavis-wallpaper-page-preview.png");
                console.log("WALLPAPER_PAGE_VISUAL_PASS");
                Qt.quit();
            });
        }
    }
}
