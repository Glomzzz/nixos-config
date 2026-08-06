import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    readonly property var profileDefinitions: [
        {
            "value": "performance",
            "label": qsTr("Performance"),
            "icon": "speed"
        },
        {
            "value": "balanced",
            "label": qsTr("Balanced"),
            "icon": "balance"
        },
        {
            "value": "power-saver",
            "label": qsTr("Power saver"),
            "icon": "battery_saver"
        }
    ]
    readonly property var profileModel: {
        const supported = root.profileDefinitions.filter(definition =>
            PowerProfileService.profiles.indexOf(definition.value) !== -1);
        const segmentWidth = supported.length > 0
            ? Math.max(0, (root.width - root.horizontalPadding * 2
                - root.segmentSpacing * (supported.length - 1))
                / supported.length)
            : 0;
        return supported.map(definition => ({
            "value": definition.value,
            "label": definition.label,
            "icon": definition.icon,
            "tooltip": PowerProfileService.lastError
                || definition.label,
            "width": segmentWidth
        }));
    }
    readonly property int horizontalPadding: 6
    readonly property int segmentSpacing: 2

    Layout.fillWidth: true
    implicitHeight: 56
    visible: PowerProfileService.available
        && root.profileModel.length >= 2
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    StyledButtonGroup {
        anchors {
            fill: parent
            margins: root.horizontalPadding
        }
        model: root.profileModel
        currentValue: PowerProfileService.activeProfile
        accessibleName: qsTr("Power mode")
        buttonHeight: 44
        horizontalPadding: 10
        innerRadius: Appearance.rounding.extraSmall
        edgeRadius: Appearance.rounding.normal
        style: StyledButtonGroup.Style.Tonal
        spacing: root.segmentSpacing
        enabled: !PowerProfileService.busy
        opacity: enabled ? 1 : 0.55

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve:
                    Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onValueSelected: value =>
            PowerProfileService.setProfile(String(value))
    }
}
