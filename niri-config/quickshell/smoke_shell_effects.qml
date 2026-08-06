//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Common
import qs.Services

ShellRoot {
    id: root

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    Item {
        id: visualFixture

        Rectangle {
            id: outerBackground

            color: Appearance.applyAlpha(
                Appearance.colors.colLayer0,
                PersonalizationConfig.shellBackgroundOpacity)
        }

        Text {
            id: foregroundText

            opacity: 1
        }

        Item {
            id: internalContent

            opacity: 1
        }
    }

    Timer {
        interval: 25
        repeat: true
        running: true

        onTriggered: {
            if (!PersonalizationConfig.storeReady)
                return;

            const saved = JSON.parse(JSON.stringify(
                PersonalizationConfig.toJson()));
            PersonalizationConfig.loading = true;
            try {
                PersonalizationConfig.loadFromObject({});
                root.verify(
                    PersonalizationConfig.shellBackgroundOpacity
                        === 1,
                    "default shell background opacity");
                root.verify(
                    !PersonalizationConfig.shellBlurEnabled,
                    "default shell blur");
                root.verify(
                    PersonalizationConfig.shellBlurXray,
                    "default shell blur xray");
                root.verify(
                    PersonalizationConfig.needsEffectsMigration({}),
                    "legacy effects migration");

                PersonalizationConfig.loadFromObject({
                    effects: {
                        shellBackgroundOpacity: "invalid",
                        shellBlurEnabled: "true",
                        shellBlurXray: 0
                    }
                });
                root.verify(
                    PersonalizationConfig.shellBackgroundOpacity
                        === 1
                    && !PersonalizationConfig.shellBlurEnabled
                    && PersonalizationConfig.shellBlurXray,
                    "invalid effects fallback");

                PersonalizationConfig.loadFromObject({
                    effects: {
                        shellBackgroundOpacity: 0.6,
                        shellBlurEnabled: true,
                        shellBlurXray: false
                    }
                });
                const serialized = JSON.parse(JSON.stringify(
                    PersonalizationConfig.toJson()));
                PersonalizationConfig.loadFromObject(serialized);
                root.verify(
                    PersonalizationConfig.shellBackgroundOpacity
                        === 0.6
                    && PersonalizationConfig.shellBlurEnabled
                    && !PersonalizationConfig.shellBlurXray,
                    "effects round trip");
                root.verify(
                    Math.abs(outerBackground.color.a - 0.6)
                        < 0.001,
                    "outer background alpha");
                root.verify(foregroundText.opacity === 1,
                    "text opacity unchanged");
                root.verify(internalContent.opacity === 1,
                    "internal content opacity unchanged");

                PersonalizationConfig
                    .setShellBackgroundOpacity(-10);
                root.verify(
                    PersonalizationConfig.shellBackgroundOpacity
                        === 0,
                    "opacity lower clamp");
                PersonalizationConfig
                    .setShellBackgroundOpacity(10);
                root.verify(
                    PersonalizationConfig.shellBackgroundOpacity
                        === 1,
                    "opacity upper clamp");

                console.log("SHELL_EFFECTS_SMOKE_PASS");
            } catch (error) {
                console.error("SHELL_EFFECTS_SMOKE_FAIL", error);
            } finally {
                PersonalizationConfig.loadFromObject(saved);
                PersonalizationConfig.loading = false;
            }
            stop();
            Qt.callLater(Qt.quit);
        }
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: {
            console.error("SHELL_EFFECTS_SMOKE_FAIL", "timeout");
            Qt.quit();
        }
    }
}
