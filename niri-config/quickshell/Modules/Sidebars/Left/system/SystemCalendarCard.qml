import QtQuick
import qs.Common

Rectangle {
    id: root

    property bool active: true
    property date currentDate: new Date()
    readonly property var monthNames: [
        qsTr("一月"), qsTr("二月"), qsTr("三月"), qsTr("四月"),
        qsTr("五月"), qsTr("六月"), qsTr("七月"), qsTr("八月"),
        qsTr("九月"), qsTr("十月"), qsTr("十一月"), qsTr("十二月")
    ]
    readonly property var weekdayNames: [
        qsTr("周日"), qsTr("周一"), qsTr("周二"), qsTr("周三"),
        qsTr("周四"), qsTr("周五"), qsTr("周六")
    ]
    readonly property var accessibleWeekdayNames: [
        qsTr("星期日"), qsTr("星期一"), qsTr("星期二"), qsTr("星期三"),
        qsTr("星期四"), qsTr("星期五"), qsTr("星期六")
    ]
    readonly property string calendarFamily:
        displayFont.status === FontLoader.Ready
            ? displayFont.name
            : Sizes.fontFamily
    readonly property var calendarAxes:
        displayFont.status === FontLoader.Ready
            ? ({
                "ROND": 45,
                "wdth": 78
            })
            : ({})

    radius: Appearance.rounding.extraLarge
    color: Appearance.colors.colSurfaceContainerHigh
    clip: true
    Accessible.name: currentDate.getFullYear()
        + qsTr("年") + (currentDate.getMonth() + 1)
        + qsTr("月") + currentDate.getDate()
        + qsTr("日，") + accessibleWeekdayNames[currentDate.getDay()]

    FontLoader {
        id: displayFont

        source: Paths.fileUrl(
            Paths.fontsDir
                + "/google-sans-flex/"
                + "GoogleSansFlex-VariableFont_"
                + "GRAD,ROND,opsz,slnt,wdth,wght.ttf"
        )
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    Rectangle {
        id: headingBand

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Math.max(42, root.height * 0.36)
        color: Appearance.colors.colSecondaryContainer
        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: 0
        bottomRightRadius: 0

        Text {
            anchors.centerIn: parent
            text: root.monthNames[root.currentDate.getMonth()]
                + "  " + root.weekdayNames[root.currentDate.getDay()]
            color: Appearance.colors.colOnSecondaryContainer
            renderType: Text.NativeRendering
            font {
                family: root.calendarFamily
                pixelSize: Math.min(
                    Sizes.typeTitleMedium,
                    headingBand.height * 0.36
                )
                weight: Font.Bold
                letterSpacing: 0.8
                variableAxes: root.calendarAxes
            }
        }
    }

    Text {
        anchors {
            top: headingBand.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        text: String(root.currentDate.getDate())
        color: Appearance.colors.colOnSurface
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font {
            family: root.calendarFamily
            pixelSize: Math.min(root.width * 0.52, root.height * 0.5)
            weight: Font.Medium
            variableAxes: root.calendarAxes
        }
    }
}
