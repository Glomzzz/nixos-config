import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components
import "../../../../Common/functions/SystemFormat.js" as Format

Rectangle {
    id: root

    property var battery: ({})
    readonly property bool present: root.battery.present === true
    readonly property bool valueAvailable:
        root.present && Format.isNumber(root.battery.chargePercent)
    readonly property real targetLevel: root.valueAvailable
        ? Math.max(0, Math.min(1, root.battery.chargePercent / 100))
        : 0
    property real animatedLevel: targetLevel
    readonly property string normalizedStatus:
        String(root.battery.status || "").toLowerCase()
    readonly property bool charging:
        root.normalizedStatus === "charging"
    readonly property bool full:
        root.normalizedStatus === "full"
        || (
            root.valueAvailable
            && root.battery.chargePercent >= 100
            && !root.charging
        )
    readonly property bool powerConnected:
        root.battery.acOnline === true
        || (
            root.battery.acOnline !== false
            && (
                root.charging
                || root.normalizedStatus === "full"
                || root.normalizedStatus === "not charging"
            )
        )
    readonly property bool lowBattery:
        root.valueAvailable
        && root.battery.chargePercent <= 15
        && !root.powerConnected
    readonly property real batteryIconCenterY:
        Appearance.spacing.medium + 18
    readonly property bool batteryIconCovered:
        root.animatedLevel
        >= 1 - root.batteryIconCenterY / Math.max(1, root.height)

    function batteryIconName() {
        if (!root.present || !root.valueAvailable)
            return "battery_unknown";

        const percent = root.battery.chargePercent;
        if (root.charging) {
            if (percent <= 15)
                return "battery_charging_20";
            if (percent <= 35)
                return "battery_charging_30";
            if (percent <= 55)
                return "battery_charging_50";
            if (percent <= 70)
                return "battery_charging_60";
            if (percent <= 85)
                return "battery_charging_80";
            if (percent <= 95)
                return "battery_charging_90";
            return "battery_charging_full";
        }

        if (percent <= 5)
            return "battery_0_bar";
        if (percent <= 15)
            return "battery_1_bar";
        if (percent <= 30)
            return "battery_2_bar";
        if (percent <= 45)
            return "battery_3_bar";
        if (percent <= 60)
            return "battery_4_bar";
        if (percent <= 75)
            return "battery_5_bar";
        if (percent <= 90)
            return "battery_6_bar";
        return "battery_full";
    }

    function timingText() {
        if (root.full)
            return "—";

        if (root.charging) {
            return Format.isNumber(
                root.battery.timeRemainingSeconds
            )
                ? qsTr("充满还需 ") + Format.duration(
                    root.battery.timeRemainingSeconds
                )
                : qsTr("充满时长未知");
        }

        if (!root.powerConnected) {
            return Format.isNumber(
                root.battery.timeRemainingSeconds
            )
                ? qsTr("耗电时长 ") + Format.duration(
                    root.battery.timeRemainingSeconds
                )
                : qsTr("耗电时长未知");
        }

        return qsTr("已接通电源，未在充电");
    }

    radius: Appearance.rounding.extraLarge
    color: Appearance.colors.colSecondaryContainer
    Accessible.name: qsTr("电池，")
        + (root.present
            ? Format.percent(root.battery.chargePercent, 0)
                + "，" + Format.batteryStatus(root.battery.status)
                + "，" + (
                    root.powerConnected
                        ? qsTr("已接通电源")
                        : qsTr("未接通电源")
                )
            : qsTr("未检测到电池"))

    Behavior on animatedLevel {
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve:
                Appearance.animation.expressiveSlowSpatial.bezierCurve
        }
    }

    BatteryContents {
        anchors.fill: parent
        anchors.margins: Appearance.spacing.medium
        foregroundColor: Appearance.colors.colOnSecondaryContainer
    }

    // Item.clip is rectangular, so mask the liquid layer explicitly to the
    // Material rounded container at every charge level.
    Rectangle {
        id: roundedMask

        anchors.fill: parent
        radius: root.radius
        color: "white"
        visible: false
        layer.enabled: true
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: roundedMask
        }

        Item {
            id: levelClip

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: parent.height * root.animatedLevel
            clip: true

            Rectangle {
                width: root.width
                height: root.height
                y: levelClip.height - height
                color: Appearance.colors.colSecondary

                BatteryContents {
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.medium
                    foregroundColor: Appearance.colors.colOnSecondary
                    Accessible.ignored: true
                }
            }
        }

    }

    MaterialSymbol {
        anchors {
            top: parent.top
            right: parent.right
            margins: Appearance.spacing.medium
        }
        z: 4
        text: root.batteryIconName()
        iconSize: 36
        fill: 1
        color: {
            if (root.batteryIconCovered)
                return Appearance.colors.colOnSecondary;
            if (!root.present)
                return Appearance.colors.colOnSecondaryContainer;
            if (root.lowBattery)
                return Appearance.colors.colError;
            if (root.powerConnected)
                return Appearance.colors.colPrimary;
            return Appearance.colors.colSecondary;
        }

        Behavior on color {
            ColorAnimation {
                duration:
                    Appearance.animation.expressiveEffects.duration
            }
        }
    }

    component BatteryContents: Item {
        id: contents

        required property color foregroundColor

        Text {
            anchors {
                left: parent.left
                top: parent.top
            }
            text: qsTr("电池")
            color: contents.foregroundColor
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeTitleSmall
            font.weight: Font.DemiBold
        }

        ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            visible: root.present
            spacing: Appearance.spacing.xSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    text: "schedule"
                    iconSize: 15
                    fill: 0
                    color: contents.foregroundColor
                }

                Text {
                    Layout.fillWidth: true
                    text: root.timingText()
                    color: contents.foregroundColor
                    opacity: 0.78
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeLabelSmall
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    text: "electric_bolt"
                    iconSize: 15
                    color: contents.foregroundColor
                }

                Text {
                    Layout.fillWidth: true
                    text: Format.isNumber(root.battery.powerWatts)
                        ? (
                            root.powerConnected
                                ? (
                                    root.charging
                                        ? qsTr("充电 ")
                                        : qsTr("功率 ")
                                )
                                : qsTr("放电 ")
                        ) + Format.watts(
                            root.battery.powerWatts
                        )
                        : qsTr("功率未知")
                    color: contents.foregroundColor
                    opacity: 0.78
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeLabelSmall
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Format.isNumber(root.battery.healthPercent)
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    text: "health_and_safety"
                    iconSize: 15
                    color: contents.foregroundColor
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("健康 ")
                        + Format.percent(
                            root.battery.healthPercent,
                            0
                        )
                    color: contents.foregroundColor
                    opacity: 0.78
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeLabelSmall
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.present
            text: qsTr("未检测到\n电池")
            color: contents.foregroundColor
            opacity: 0.76
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeTitleSmall
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignRight
                text: root.present
                    ? Format.batteryStatus(root.battery.status)
                    : qsTr("不可用")
                color: contents.foregroundColor
                opacity: 0.74
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.typeBodySmall
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: Appearance.spacing.xSmall

                Item {
                    Layout.fillWidth: true
                }

                MaterialSymbol {
                    text: root.powerConnected
                        ? "power"
                        : "power_off"
                    iconSize: 22
                    fill: 1
                    color: contents.foregroundColor
                }

                Text {
                    text: root.present
                        ? Format.percent(root.battery.chargePercent, 0)
                        : "—"
                    color: contents.foregroundColor
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeHeadlineSmall
                    font.weight: Font.Bold
                }
            }
        }
    }
}
