import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

RowLayout {
    id: root

    enum Style {
        Primary,
        Tonal
    }

    property var model: []
    property var currentValue: ""
    property int buttonHeight: 36
    property int horizontalPadding: 24
    property int innerRadius: 6
    property real edgeRadius: buttonHeight / 2
    property int pressedExpansion: 10
    property int buttonMinWidth: 0
    property int style: StyledButtonGroup.Style.Primary
    property bool iconOnly: false
    property bool roundOuterSegments: true
    property int iconSize: 21
    property int textPixelSize: 14
    property int contentSpacing: 6
    property bool fillActiveIcon: true
    property string valueRole: "value"
    property string textRole: "label"
    property string iconRole: "icon"
    property string tooltipRole: "tooltip"
    property string enabledRole: "enabled"
    property string widthRole: "width"

    signal valueSelected(var value, var modelData)

    spacing: 2

    function roleValue(item, role, fallback) {
        if (item === undefined || item === null)
            return fallback;
        const value = item[role];
        return value === undefined || value === null ? fallback : value;
    }

    function valueFor(item, index) {
        return roleValue(item, valueRole, index);
    }

    function textFor(item) {
        const value = roleValue(item, textRole, "");
        return value === undefined || value === null ? "" : String(value);
    }

    function iconFor(item) {
        const value = roleValue(item, iconRole, "");
        return value === undefined || value === null ? "" : String(value);
    }

    function tooltipFor(item) {
        const value = roleValue(item, tooltipRole, "");
        return value === undefined || value === null ? "" : String(value);
    }

    function enabledFor(item) {
        return roleValue(item, enabledRole, true);
    }

    function segmentWidth(item, labelWidth, iconWidth) {
        const explicitWidth = Number(roleValue(item, widthRole, -1));
        if (explicitWidth > 0)
            return explicitWidth;

        const labelVisible = !iconOnly && textFor(item) !== "";
        const iconVisible = iconFor(item) !== "";
        const contentWidth = (labelVisible ? labelWidth : 0)
                           + (iconVisible ? iconWidth : 0)
                           + (labelVisible && iconVisible ? contentSpacing : 0);
        return Math.max(buttonMinWidth, contentWidth + horizontalPadding);
    }

    function fillColor(active, hovered, pressed) {
        if (style === StyledButtonGroup.Style.Tonal) {
            if (active)
                return pressed ? Appearance.colors.colPrimaryContainerActive
                               : hovered ? Appearance.colors.colPrimaryContainerHover
                                         : Appearance.colors.colPrimaryContainer;
            return pressed ? Appearance.colors.colLayer4Active
                           : hovered ? Appearance.colors.colLayer4
                                     : Appearance.colors.colLayer2;
        }

        if (active)
            return pressed ? Appearance.colors.colPrimaryActive
                           : hovered ? Appearance.colors.colPrimaryHover
                                     : Appearance.colors.colPrimary;
        return pressed ? Appearance.colors.colSecondaryContainerActive
                       : hovered ? Appearance.colors.colSecondaryContainerHover
                                 : Appearance.colors.colSecondaryContainer;
    }

    function contentColor(active) {
        if (style === StyledButtonGroup.Style.Tonal)
            return active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant;
        return active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer;
    }

    Repeater {
        model: root.model

        delegate: Item {
            id: segment

            required property int index
            required property var modelData

            readonly property var segmentValue: root.valueFor(modelData, index)
            readonly property bool segmentEnabled: root.enabledFor(modelData)
            readonly property bool active: root.currentValue === segmentValue
            readonly property bool first: index === 0
            readonly property bool last: index === root.model.length - 1
            readonly property bool pressed: segmentMouse.pressed && segmentEnabled
            readonly property bool hovered: segmentMouse.containsMouse && segmentEnabled
            readonly property real leftRadius: (active || (root.roundOuterSegments && first) || pressed) ? root.edgeRadius : root.innerRadius
            readonly property real rightRadius: (active || (root.roundOuterSegments && last) || pressed) ? root.edgeRadius : root.innerRadius
            readonly property color segmentColor: root.fillColor(active, hovered, pressed)
            readonly property color inkColor: root.contentColor(active)
            readonly property string labelText: root.textFor(modelData)
            readonly property string iconText: root.iconFor(modelData)
            readonly property string tooltipText: root.tooltipFor(modelData)

            Layout.preferredWidth: root.segmentWidth(modelData, label.implicitWidth, root.iconSize)
                                   + (pressed ? root.pressedExpansion : 0)
            Layout.preferredHeight: root.buttonHeight
            opacity: segmentEnabled ? 1 : 0.45
            scale: pressed ? 0.97 : 1
            z: pressed ? 3 : active ? 2 : hovered ? 1 : 0

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.clickBounce.duration
                    easing.type: Appearance.animation.clickBounce.type
                    easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Math.max(segment.leftRadius, segment.rightRadius)
                color: segment.segmentColor

                Behavior on radius {
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }

            Rectangle {
                anchors.left: segment.leftRadius < segment.rightRadius ? parent.left : undefined
                anchors.right: segment.rightRadius < segment.leftRadius ? parent.right : undefined
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width / 2 + 5
                visible: segment.leftRadius !== segment.rightRadius
                radius: Math.min(segment.leftRadius, segment.rightRadius)
                color: segment.segmentColor

                Behavior on radius {
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: root.contentSpacing

                MaterialSymbol {
                    text: segment.iconText
                    iconSize: root.iconSize
                    fill: segment.active && root.fillActiveIcon ? 1 : 0
                    color: segment.inkColor
                    visible: segment.iconText !== ""
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }
                }

                Text {
                    id: label

                    text: segment.labelText
                    visible: !root.iconOnly && segment.labelText !== ""
                    color: segment.inkColor
                    font.family: Sizes.fontFamily
                    font.pixelSize: root.textPixelSize
                    font.weight: segment.active ? Font.Medium : Font.Normal
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }
                }
            }

            MouseArea {
                id: segmentMouse

                anchors.fill: parent
                enabled: segment.segmentEnabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.valueSelected(segment.segmentValue, segment.modelData)
                z: 3
            }

            StyledToolTip {
                extraVisibleCondition: segmentMouse.containsMouse && segment.tooltipText !== ""
                text: segment.tooltipText
            }
        }
    }
}
