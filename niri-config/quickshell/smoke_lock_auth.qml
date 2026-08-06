//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Modules.Lock.Cards

ShellRoot {
    id: root

    property int phase: 0

    QtObject {
        id: authContext

        property string currentText: ""
        property bool unlockInProgress: false

        function tryUnlock() {
        }
    }

    ApplicationWindow {
        visible: true
        width: 640
        height: 180
        color: Appearance.colors.colLayer0

        AuthCard {
            anchors.centerIn: parent
            width: 520
            height: Sizes.lockAuthHeight
            context: authContext
        }
    }

    Timer {
        interval: 120
        repeat: true
        running: true

        onTriggered: {
            if (root.phase < 6) {
                authContext.currentText += "x";
            } else if (root.phase < 9) {
                authContext.currentText =
                    authContext.currentText.slice(0, -1);
            } else {
                stop();
                console.log("LOCK_AUTH_SHAPES_SMOKE_PASS");
                Qt.quit();
            }

            ++root.phase;
        }
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: {
            console.error("LOCK_AUTH_SHAPES_SMOKE_FAIL", "timeout");
            Qt.quit();
        }
    }
}
