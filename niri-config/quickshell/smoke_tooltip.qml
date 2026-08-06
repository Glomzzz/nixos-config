//@ pragma UseQApplication

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Widgets.common

ShellRoot {
    id: root

    property bool showTooltip: true
    property int checks: 0

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    PanelWindow {
        id: window

        visible: true
        implicitWidth: 260
        implicitHeight: 100
        color: "transparent"
        anchors {
            top: true
            left: true
        }
        margins {
            top: 120
            left: 120
        }
        WlrLayershell.namespace: "clavis-tooltip-smoke"
        WlrLayershell.layer: WlrLayer.Overlay

        Rectangle {
            id: anchorItem

            property bool hovered: false

            anchors.centerIn: parent
            width: 44
            height: 44
            radius: 22
            color: "#80404040"

            StyledToolTip {
                id: tooltip

                text: qsTr("工具提示文字")
                alternativeVisibleCondition: showTooltip
            }
        }
    }

    ApplicationWindow {
        visible: true
        width: 220
        height: 100
        color: "transparent"

        Rectangle {
            property bool hovered: false

            anchors.centerIn: parent
            width: 44
            height: 44

            StyledToolTip {
                id: fallbackTooltip

                text: qsTr("窗口工具提示")
                alternativeVisibleCondition: true
            }
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: root.showTooltip

        onTriggered: {
            try {
                const popup = tooltip.popupWindow;
                if (!popup || !popup.tooltipContentItem)
                    return;
                const content = popup.tooltipContentItem;
                if (!content.shown || content.blurBackgroundItem.width <= 0)
                    return;

                root.verify(content.text === qsTr("工具提示文字"),
                    "tooltip text");
                root.verify(content.width === content.implicitWidth
                    && content.height === content.implicitHeight,
                    "tooltip content geometry");
                root.verify(content.blurBackgroundItem.width > 0
                    && content.blurBackgroundItem.height > 0,
                    "tooltip background geometry");
                root.verify(popup.implicitWidth
                    === content.implicitWidth
                        + tooltip.horizontalMargin * 2,
                    "popup width");
                root.verify(fallbackTooltip.usingFallback,
                    "application window tooltip fallback");
                console.log("TOOLTIP_SMOKE_PASS");
                stop();
                Qt.callLater(Qt.quit);
            } catch (error) {
                console.error("TOOLTIP_SMOKE_FAIL", error);
                stop();
                Qt.callLater(Qt.quit);
            }
        }
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: {
            console.error("TOOLTIP_SMOKE_FAIL", "timeout");
            Qt.quit();
        }
    }
}
