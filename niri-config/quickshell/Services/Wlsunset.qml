pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    signal gammaChangeAttempt()

    readonly property real gammaLowerLimit: 25
    property int gamma: 100

    function clampGamma(value) {
        return Math.round(Math.max(root.gammaLowerLimit, Math.min(100, value)));
    }

    function gammaArgument() {
        return (root.gamma / 100).toFixed(2);
    }

    function stopWlsunset() {
        Quickshell.execDetached(["bash", "-c", "pkill -x wlsunset 2>/dev/null || true"]);
    }

    function applyGamma() {
        if (root.gamma >= 100) {
            root.stopWlsunset();
            return;
        }

        Quickshell.execDetached([
            "bash",
            "-c",
            "pkill -x wlsunset 2>/dev/null || true; wlsunset -T 6501 -t 6500 -S 00:00 -s 00:00 -g " + root.gammaArgument() + " >/dev/null 2>&1 &"
        ]);
    }

    function setGamma(value) {
        const safeGamma = root.clampGamma(value);
        root.gamma = safeGamma;
        root.gammaChangeAttempt();
        applyGammaTimer.restart();
    }

    Timer {
        id: applyGammaTimer

        interval: 40
        repeat: false
        onTriggered: root.applyGamma()
    }
}
