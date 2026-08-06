//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

ShellRoot {
    id: root

    property int phase: 0
    property int attempts: 0

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    FileView {
        id: effectsFile

        path: BlurService.effectsConfigPath
        blockLoading: true
    }

    FileView {
        id: mainFile

        path: BlurService.niriConfigPath
        blockLoading: true
    }

    Timer {
        interval: 50
        repeat: true
        running: true

        onTriggered: {
            try {
                if (root.phase === 0) {
                    if (!PersonalizationConfig.storeReady
                            || !BlurService.available)
                        return;
                    root.verify(
                        BlurService.supportsVersion(
                            BlurService.niriVersion),
                        "niri version capability");
                    root.verify(
                        !BlurService.niriIntegrationReady,
                        "unexpected initial integration");
                    BlurService.writeEffectsConfig();
                    root.phase = 1;
                    return;
                }

                if (root.phase === 1) {
                    effectsFile.reload();
                    const effects = effectsFile.text();
                    if (effects.indexOf(
                            "X-Ray is niri's default") < 0)
                        return;
                    root.verify(
                        effects.indexOf(
                            "background-effect") < 0,
                        "xray default emitted an override");
                    root.verify(
                        effects.indexOf("blur true") < 0,
                        "snippet forces full-surface blur");
                    BlurService.configureNiriIntegration();
                    root.phase = 2;
                    return;
                }

                if (root.phase === 2) {
                    mainFile.reload();
                    if (!BlurService.niriIntegrationReady
                            || mainFile.text().indexOf(
                                "clavis-effects.kdl") < 0)
                        return;
                    PersonalizationConfig
                        .setShellBlurXray(false);
                    root.phase = 3;
                    return;
                }

                effectsFile.reload();
                if (effectsFile.text().indexOf("xray false") < 0)
                    return;
                root.verify(
                    mainFile.text().split(
                        "clavis-effects.kdl").length - 1 === 1,
                    "duplicate include");
                stop();
                console.log("BLUR_SERVICE_SMOKE_PASS");
                Qt.callLater(Qt.quit);
            } catch (error) {
                stop();
                console.error("BLUR_SERVICE_SMOKE_FAIL", error);
                Qt.callLater(Qt.quit);
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        onTriggered: {
            console.error("BLUR_SERVICE_SMOKE_FAIL", "timeout");
            Qt.quit();
        }
    }
}
