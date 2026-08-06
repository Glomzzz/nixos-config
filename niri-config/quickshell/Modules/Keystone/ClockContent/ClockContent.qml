import QtQuick
import qs.Common
import qs.Services
import "../../../Common/functions/DateFormat.js" as DateFormat

Item {
    id: root
    property var player
    property bool active: true

    property string dateStr: ""

    // Individual digits drive the rolling transitions.
    property int h0: 0
    property int h1: 0
    property int m0: 0
    property int m1: 0

    function formatDate(date) {
        return DateFormat.compactDate(
            date, I18nService.language, Qt.locale(), "ddd dd MMM");
    }

    function updateClock() {
        const date = new Date();
        const hours = date.getHours().toString().padStart(2, "0");
        const minutes = date.getMinutes().toString().padStart(2, "0");

        root.dateStr = root.formatDate(date);
        root.h0 = parseInt(hours[0]);
        root.h1 = parseInt(hours[1]);
        root.m0 = parseInt(minutes[0]);
        root.m1 = parseInt(minutes[1]);
    }

    function scheduleClockUpdate() {
        minuteTimer.stop();
        if (!root.active)
            return;

        root.updateClock();
        const remainder = Date.now() % 60000;
        minuteTimer.interval = Math.max(250, 60000 - remainder);
        minuteTimer.start();
    }

    onActiveChanged: root.scheduleClockUpdate()
    Component.onCompleted: root.scheduleClockUpdate()

    Timer {
        id: minuteTimer

        repeat: false
        onTriggered: root.scheduleClockUpdate()
    }

    // Reusable rolling digit component.
    component RollingDigit : Item {
        id: digitContainer
        property int targetDigit: 0
        property color digitColor: "white"
        property real digitRotation: 0
        property real digitOffset: 0

        width: digitText.implicitWidth
        height: 24
        clip: true

        rotation: digitRotation
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: digitOffset

        Text {
            id: digitText
            text: "0\n1\n2\n3\n4\n5\n6\n7\n8\n9"
            color: digitContainer.digitColor
            font.family: Sizes.fontFamily
            font.pixelSize: 22
            font.weight: Font.Black
            lineHeight: 24
            lineHeightMode: Text.FixedHeight

            y: -digitContainer.targetDigit * 24

            // Keep digit transitions finite so they cannot hold the render loop open.
            Behavior on y {
                NumberAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve:
                        Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: root.dateStr
            color: Appearance.colors.colPrimary
            font.family: Sizes.fontFamily
            font.pixelSize: 13
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: "|"
            color: Appearance.colors.colOutlineVariant
            font.family: Sizes.fontFamily
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Row {
                spacing: -1

                RollingDigit {
                    targetDigit: root.h0
                    digitColor: Appearance.colors.colInversePrimary
                    digitRotation: -3
                    digitOffset: -2
                }
                RollingDigit {
                    targetDigit: root.h1
                    digitColor: Appearance.colors.colPrimary
                    digitRotation: 3
                    digitOffset: 1
                }
            }

            Column {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1

                Rectangle { width: 4; height: 4; radius: 2; color: Appearance.colors.colOutlineVariant }
                Rectangle { width: 4; height: 4; radius: 2; color: Appearance.colors.colOutlineVariant }
            }

            Row {
                spacing: 1

                RollingDigit {
                    targetDigit: root.m0
                    digitColor: Appearance.colors.colInversePrimary
                    digitRotation: -2
                    digitOffset: -1
                }
                RollingDigit {
                    targetDigit: root.m1
                    digitColor: Appearance.colors.colPrimary
                    digitRotation: 2
                    digitOffset: 1
                }
            }
        }
    }
}
