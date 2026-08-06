import QtQuick
import qs.Common
import qs.Services
import "../../../../Common/functions/DateFormat.js" as DateFormat

Item {
    id: root

    property bool active: true
    property date currentTime: new Date()
    readonly property int hour24: currentTime.getHours()
    readonly property int hour12: ((hour24 + 11) % 12) + 1
    readonly property string hourText: String(hour12)
        .padStart(2, "0")
    readonly property string minuteText:
        String(currentTime.getMinutes()).padStart(2, "0")
    readonly property string periodText: hour24 >= 12 ? "PM" : "AM"
    readonly property string clockFamily:
        displayFont.status === FontLoader.Ready
            ? displayFont.name
            : Sizes.fontFamily
    readonly property var clockAxes:
        displayFont.status === FontLoader.Ready
            ? ({
                "ROND": 25,
                "wdth": 30
            })
            : ({})
    readonly property var dayNames: [
        qsTr("星期日"),
        qsTr("星期一"),
        qsTr("星期二"),
        qsTr("星期三"),
        qsTr("星期四"),
        qsTr("星期五"),
        qsTr("星期六")
    ]
    readonly property var monthNames: [
        qsTr("一月"), qsTr("二月"), qsTr("三月"), qsTr("四月"),
        qsTr("五月"), qsTr("六月"), qsTr("七月"), qsTr("八月"),
        qsTr("九月"), qsTr("十月"), qsTr("十一月"), qsTr("十二月")
    ]
    readonly property string dateText: I18nService.language.startsWith("zh")
        ? DateFormat.compactDate(
            currentTime, I18nService.language, Qt.locale(), "")
        : dayNames[currentTime.getDay()]
            + " · "
            + String(currentTime.getDate()).padStart(2, "0")
            + " "
            + monthNames[currentTime.getMonth()]

    function topOffset(metrics) {
        return metrics.tightBoundingRect.y - metrics.boundingRect.y;
    }

    Accessible.name: hourText + ":" + minuteText
        + " " + periodText + "，" + dateText

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
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    Item {
        id: clockFace

        anchors {
            fill: parent
            margins: Appearance.spacing.small
        }

        readonly property real hourSize: Math.min(
            284,
            height * 1.06,
            width * 0.88
        )
        readonly property real minuteSize:
            Math.min(164, hourSize * 0.61)
        readonly property real periodSize: Math.min(
            26,
            Math.max(22, height * 0.085)
        )
        readonly property real dateSize: Math.min(
            32,
            Math.max(25, height * 0.115)
        )

        Item {
            id: fullClockComposition

            anchors.centerIn: parent
            width: Math.max(
                glyphGroup.width,
                dateMetrics.tightBoundingRect.width
            )
            height: glyphGroup.height
                + Appearance.spacing.small
                + dateMetrics.tightBoundingRect.height

            Item {
                id: glyphGroup

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }
                width: hourMetrics.tightBoundingRect.width
                    + Appearance.spacing.medium
                    + Math.max(
                        minuteMetrics.tightBoundingRect.width,
                        periodPill.width
                    )
                height: Math.max(
                    hourMetrics.tightBoundingRect.height,
                    minuteMetrics.tightBoundingRect.height
                        + periodPill.height
                        + Appearance.spacing.small
                )

                Text {
                    id: hours

                    x: -hourMetrics.tightBoundingRect.x
                    y: -root.topOffset(hourMetrics)
                    text: root.hourText
                    color: Appearance.colors.colPrimary
                    renderType: Text.NativeRendering
                    font {
                        family: root.clockFamily
                        pixelSize: clockFace.hourSize
                        weight: Font.Medium
                        variableAxes: root.clockAxes
                    }
                }

                TextMetrics {
                    id: hourMetrics

                    text: hours.text
                    font: hours.font
                }

                Item {
                    id: minuteColumn

                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: Math.max(
                        minuteMetrics.tightBoundingRect.width,
                        periodPill.width
                    )
                    height: minuteMetrics.tightBoundingRect.height
                        + periodPill.height
                        + Appearance.spacing.small

                    Text {
                        id: minutes

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -root.topOffset(minuteMetrics)
                        text: root.minuteText
                        color: Appearance.colors.colSecondary
                        renderType: Text.NativeRendering
                        font {
                            family: root.clockFamily
                            pixelSize: clockFace.minuteSize
                            weight: Font.Medium
                            variableAxes: root.clockAxes
                        }
                    }

                    TextMetrics {
                        id: minuteMetrics

                        text: minutes.text
                        font: minutes.font
                    }

                    Rectangle {
                        id: periodPill

                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                        }
                        width: periodLabel.implicitWidth
                            + Appearance.spacing.medium
                        height: periodLabel.implicitHeight
                            + Appearance.spacing.small
                        radius: Appearance.rounding.small
                        color:
                            Appearance.colors.colSecondaryContainer

                        Text {
                            id: periodLabel

                            anchors.centerIn: parent
                            text: root.periodText
                            color:
                                Appearance.colors.colOnSecondaryContainer
                            renderType: Text.NativeRendering
                            font {
                                family: root.clockFamily
                                pixelSize: clockFace.periodSize
                                weight: Font.DemiBold
                                variableAxes: root.clockAxes
                            }
                        }
                    }
                }
            }

            Text {
                id: dateLabel

                anchors {
                    top: glyphGroup.bottom
                    topMargin: Appearance.spacing.small
                    horizontalCenter: parent.horizontalCenter
                }
                width: parent.width
                text: root.dateText
                color: Appearance.colors.colOnSurface
                renderType: Text.NativeRendering
                font {
                    family: root.clockFamily
                    pixelSize: clockFace.dateSize
                    weight: Font.DemiBold
                    letterSpacing: 2.4
                    variableAxes: root.clockAxes
                }
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            TextMetrics {
                id: dateMetrics

                text: dateLabel.text
                font: dateLabel.font
            }
        }
    }
}
