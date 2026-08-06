import QtQuick
import qs.Common

Item {
    id: root

    property bool active: false
    property bool hubPage: false
    default property alias content: contentHost.data

    enabled: active
    visible: active || opacity > 0.001
    opacity: active ? 1 : 0
    x: active ? 0 : (hubPage ? -16 : 16)
    scale: active ? 1 : 0.985
    z: active ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.active
                ? Appearance.animation.elementResize.duration
                : Appearance.animation.emphasizedAccel.duration
            easing.type: root.active
                ? Appearance.animation.elementResize.type
                : Appearance.animation.emphasizedAccel.type
            easing.bezierCurve: root.active
                ? Appearance.animation.elementResize.bezierCurve
                : Appearance.animation.emphasizedAccel.bezierCurve
        }
    }

    Behavior on x {
        NumberAnimation {
            duration: root.active
                ? Appearance.animation.elementResize.duration
                : Appearance.animation.emphasizedAccel.duration
            easing.type: root.active
                ? Appearance.animation.elementResize.type
                : Appearance.animation.emphasizedAccel.type
            easing.bezierCurve: root.active
                ? Appearance.animation.elementResize.bezierCurve
                : Appearance.animation.emphasizedAccel.bezierCurve
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.active
                ? Appearance.animation.elementResize.duration
                : Appearance.animation.emphasizedAccel.duration
            easing.type: root.active
                ? Appearance.animation.elementResize.type
                : Appearance.animation.emphasizedAccel.type
            easing.bezierCurve: root.active
                ? Appearance.animation.elementResize.bezierCurve
                : Appearance.animation.emphasizedAccel.bezierCurve
        }
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }
}
