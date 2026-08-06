//@ pragma UseQApplication

import QtQuick
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Modules.ControlCenter
import qs.Services

ShellRoot {
    id: root

    Window {
        id: previewWindow

        visible: true
        width: 680
        height: 900
        color: Appearance.m3colors.m3background

        GeneralPage {
            id: generalPage

            anchors.fill: parent
        }
    }

    Timer {
        interval: 700
        running: true

        onTriggered: {
            if (!BlurService.available) {
                console.error("GENERAL_PAGE_SMOKE_FAIL",
                    "blur capability was not detected");
                Qt.quit();
                return;
            }

            generalPage.grabToImage(result => {
                result.saveToFile(
                    "/tmp/clavis-general-page-preview.png");
                console.log("GENERAL_PAGE_SMOKE_PASS");
                Qt.quit();
            });
        }
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: {
            console.error("GENERAL_PAGE_SMOKE_FAIL", "timeout");
            Qt.quit();
        }
    }
}
