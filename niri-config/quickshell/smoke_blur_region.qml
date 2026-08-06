//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Widgets.common

ShellRoot {
    id: root

    property int phase: 0
    property int regionChangeCount: 0
    property int blurRegionPublishCount: 0
    property int blurToggleCount: 0

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    PanelWindow {
        id: testWindow

        visible: true
        color: "transparent"
        implicitWidth: 320
        implicitHeight: 180
        anchors {
            left: true
            top: true
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clavis-blur-smoke-test"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        Rectangle {
            id: firstPill

            x: 12
            y: 16
            width: 96
            height: 40
            radius: 20
            color: "#80000000"
        }

        Rectangle {
            id: secondPill

            x: 180
            y: 80
            width: 112
            height: 52
            radius: 14
            color: "#80000000"
        }

        Item {
            id: cutout

            x: 42
            y: 24
            width: 32
            height: 20
            property real radius: 8
        }

        CompositorBlurRegion {
            id: blurController

            targetWindow: testWindow
            backgroundItem: firstPill
            additionalBackgroundItems: [secondPill]
            subtractedBackgroundItems: [cutout]
            compositorEnabled: true
        }
    }

    FloatingWindow {
        id: regularWindow

        visible: true
        implicitWidth: 160
        implicitHeight: 100
        color: "transparent"
        title: "clavis-blur-smoke-regular"

        Rectangle {
            id: regularBackground

            anchors.fill: parent
            radius: 12
            color: "#80000000"
        }

        CompositorBlurRegion {
            id: regularBlurController

            targetWindow: regularWindow
            backgroundItem: regularBackground
            compositorEnabled: true
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: true

        onTriggered: {
            try {
                if (root.phase === 0) {
                    root.verify(
                        testWindow.BackgroundEffect.blurRegion
                            === blurController.region,
                        "enabled region was not submitted");
                    root.verify(
                        regularWindow.BackgroundEffect.blurRegion
                            === regularBlurController.region,
                        "regular window region was not submitted: ready="
                            + regularBlurController.surfaceReady
                            + " count="
                            + regularBlurController
                                .visibleBackgroundCount
                            + " submit="
                            + regularBlurController.shouldSubmit
                            + " attached="
                            + regularWindow.BackgroundEffect
                                .blurRegion);
                    root.verify(
                        blurController.regionObjects.length === 2,
                        "combined region count");
                    root.verify(
                        blurController.combinedRegionCount() === 3,
                        "dynamic regions were not added to Region.regions");
                    root.verify(
                        blurController.regionObjects[0].item
                            === firstPill
                        && blurController.regionObjects[1].item
                            === secondPill,
                        "combined region contains only visible pills");
                    root.verify(
                        blurController
                            .subtractionRegionObjects.length === 1
                        && blurController
                            .subtractionRegionObjects[0].item
                            === cutout
                        && blurController
                            .subtractionRegionObjects[0].intersection
                            === Intersection.Subtract
                        && blurController
                            .subtractionRegionObjects[0].radius === 8,
                        "subtracted region");
                    root.verify(
                        blurController.regionObjects[0].radius
                            === 20
                        && blurController.regionObjects[1].radius
                            === 14,
                        "region radii");
                    blurController.regionObjects[0].changed
                        .connect(() => ++root.regionChangeCount);
                    testWindow.BackgroundEffect.blurRegionChanged
                        .connect(function() {
                            ++root.blurRegionPublishCount;
                        });
                    root.blurRegionPublishCount = 0;
                    firstPill.x = 32;
                    firstPill.width = 124;
                    firstPill.radius = 18;
                    root.phase = 1;
                    return;
                }

                if (root.phase === 1) {
                    root.verify(root.regionChangeCount > 0,
                        "region did not react to geometry");
                    root.verify(root.blurRegionPublishCount > 0,
                        "changed geometry was not republished");
                    root.verify(
                        blurController.regionObjects[0].radius
                            === 18,
                        "region did not follow radius");
                    firstPill.visible = false;
                    secondPill.visible = false;
                    root.phase = 2;
                    return;
                }

                if (root.phase === 2) {
                    root.verify(
                        testWindow.BackgroundEffect.blurRegion
                            === null,
                        "hidden backgrounds did not clear region");
                    firstPill.visible = true;
                    root.phase = 3;
                    return;
                }

                if (root.phase === 3) {
                    root.verify(
                        testWindow.BackgroundEffect.blurRegion
                            === blurController.region,
                        "visible background did not restore region");
                    testWindow.visible = false;
                    root.phase = 4;
                    return;
                }

                if (root.phase === 4) {
                    root.verify(
                        testWindow.BackgroundEffect.blurRegion
                            === null,
                        "hidden window did not clear region");
                    testWindow.visible = true;
                    root.phase = 5;
                    return;
                }

                if (root.phase === 5) {
                    root.verify(
                        testWindow.BackgroundEffect.blurRegion
                            === blurController.region,
                        "remapped window did not restore region");
                    blurController.blurEnabled = false;
                    root.verify(
                        testWindow.BackgroundEffect.blurRegion
                            === null,
                        "disabled blur did not clear region");
                    blurController.blurEnabled = true;
                    root.phase = 6;
                    return;
                }

                if (root.phase === 6) {
                    root.verify(
                        testWindow.BackgroundEffect.blurRegion
                            === blurController.region,
                        "re-enabled blur did not restore region");
                    ++root.blurToggleCount;
                    if (root.blurToggleCount < 20) {
                        blurController.blurEnabled = false;
                        root.verify(
                            testWindow.BackgroundEffect.blurRegion
                                === null,
                            "disabled blur did not clear region");
                        blurController.blurEnabled = true;
                        return;
                    }
                }
                stop();
                console.log("BLUR_REGION_SMOKE_PASS");
                Qt.callLater(Qt.quit);
            } catch (error) {
                stop();
                console.error("BLUR_REGION_SMOKE_FAIL", error);
                Qt.callLater(Qt.quit);
            }
        }
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: {
            console.error("BLUR_REGION_SMOKE_FAIL", "timeout");
            Qt.quit();
        }
    }
}
