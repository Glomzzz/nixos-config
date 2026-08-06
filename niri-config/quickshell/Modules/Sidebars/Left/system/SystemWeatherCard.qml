import QtQuick
import QtQuick.Layouts
import M3Shapes
import Clavis.Weather 1.0
import qs.Common
import qs.Components

Rectangle {
    id: root

    readonly property bool dataAvailable: WeatherPlugin.hasValidData
    readonly property var currentDetails: {
        // Reading lastUpdated makes this map binding track backend refreshes.
        const revision = WeatherPlugin.lastUpdated;
        return WeatherPlugin.current();
    }
    readonly property color heroInk:
        Appearance.colors.colOnSurface
    readonly property color supportingInk:
        Appearance.colors.colOnSurfaceVariant
    readonly property color metricInk:
        Appearance.colors.colOnSurface
    readonly property color metricMutedInk: Appearance.applyAlpha(
        Appearance.colors.colOnSurfaceVariant,
        0.82
    )

    function validNumber(value) {
        return root.dataAvailable
            && value !== undefined
            && value !== null
            && !isNaN(Number(value));
    }

    function temperatureText() {
        return root.validNumber(WeatherPlugin.currentTemperatureC)
            ? Math.round(WeatherPlugin.currentTemperatureC) + "°C"
            : "—";
    }

    function percentText(value) {
        return root.validNumber(value)
            ? Math.round(Number(value)) + "%"
            : "—";
    }

    function speedText(value) {
        return root.validNumber(value)
            ? Number(value).toFixed(1) + " m/s"
            : "—";
    }

    function pressureText(value) {
        return root.validNumber(value)
            ? Math.round(Number(value)) + " hPa"
            : "—";
    }

    function visibilityText(value) {
        if (!root.validNumber(value))
            return "—";
        const kilometers = Number(value) / 1000;
        return (kilometers >= 10
            ? Math.round(kilometers).toString()
            : kilometers.toFixed(1)) + " km";
    }

    function timeText(epoch) {
        const seconds = Number(epoch || 0);
        return seconds > 0
            ? Qt.formatDateTime(
                new Date(seconds * 1000),
                "hh:mm"
            )
            : "—";
    }

    function coordinateText() {
        if (!root.dataAvailable)
            return qsTr("正在定位");
        const latitude = Number(WeatherPlugin.latitude);
        const longitude = Number(WeatherPlugin.longitude);
        if (!isFinite(latitude) || !isFinite(longitude))
            return qsTr("坐标未知");
        return latitude.toFixed(2)
            + "°, " + longitude.toFixed(2) + "°";
    }

    radius: Appearance.rounding.extraLarge
    color: Appearance.colors.colSurfaceContainerHigh
    clip: true
    Accessible.name: qsTr("天气，")
        + root.temperatureText() + "，"
        + (root.dataAvailable
            ? WeatherPlugin.currentWeatherText
            : qsTr("正在获取"))
        + "，" + (WeatherPlugin.locationName || qsTr("位置未知"))
        + qsTr("，坐标 ") + root.coordinateText()
        + qsTr("，湿度 ")
        + root.percentText(WeatherPlugin.currentRelativeHumidity)
        + qsTr("，风速 ")
        + root.speedText(WeatherPlugin.currentWindSpeedMs)
        + qsTr("，气压 ")
        + root.pressureText(WeatherPlugin.currentPressureHpa)
        + qsTr("，能见度 ")
        + root.visibilityText(WeatherPlugin.currentVisibilityM)
        + qsTr("，日出 ") + root.timeText(root.currentDetails.sunrise)
        + qsTr("，日落 ") + root.timeText(root.currentDetails.sunset)

    component CompactMetric: Item {
        id: metric

        required property string iconName
        required property string value
        implicitWidth: metricRow.implicitWidth
        implicitHeight: 28

        RowLayout {
            id: metricRow

            anchors.fill: parent
            spacing: Appearance.spacing.xSmall

            MaterialSymbol {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                text: metric.iconName
                iconSize: Sizes.typeTitleSmall
                fill: 1
                color: root.metricMutedInk
            }

            Text {
                Layout.preferredWidth: implicitWidth
                Layout.fillHeight: true
                text: metric.value
                color: root.metricInk
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.typeBodySmall
                font.weight: Font.Bold
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    component AstroMetric: Item {
        id: metric

        required property string iconName
        required property string value

        Row {
            anchors.centerIn: parent
            height: parent.height
            spacing: Appearance.spacing.xSmall

            MaterialSymbol {
                width: 18
                height: parent.height
                text: metric.iconName
                iconSize: Sizes.typeBodySmall
                fill: 1
                color: Appearance.colors.colOnPrimaryContainer
            }

            Text {
                width: implicitWidth
                height: parent.height
                text: metric.value
                color: Appearance.colors.colOnPrimaryContainer
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.typeBodySmall
                font.weight: Font.Bold
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Item {
        id: heroArea

        anchors {
            top: parent.top
            left: parent.left
            right: weatherCluster.left
            bottom: metricBand.top
            margins: Appearance.spacing.small
            rightMargin: Appearance.spacing.medium
            bottomMargin: Appearance.spacing.xSmall
        }

        Text {
            id: temperature

            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: Math.max(
                128,
                Math.min(174, heroArea.width * 0.29)
            )
            text: root.temperatureText()
            color: Appearance.colors.colPrimary
            font.family: Sizes.fontFamilyMono
            font.pixelSize: Math.min(
                54,
                Math.max(34, heroArea.height * 0.76)
            )
            font.weight: Font.Bold
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 30
            verticalAlignment: Text.AlignVCenter
        }

        Column {
            anchors {
                left: temperature.right
                leftMargin: Appearance.spacing.small
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            Text {
                width: parent.width
                text: root.dataAvailable
                    ? WeatherPlugin.currentWeatherText
                    : (WeatherPlugin.loading
                        ? qsTr("正在获取天气")
                        : qsTr("天气不可用"))
                color: root.heroInk
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.typeTitleMedium
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Row {
                width: parent.width
                height: Math.max(
                    locationName.implicitHeight,
                    locationIcon.implicitHeight
                )
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    id: locationIcon

                    width: 18
                    height: 18
                    text: "location_on"
                    iconSize: Sizes.typeBodySmall
                    fill: 1
                    color: root.supportingInk
                }

                Text {
                    id: locationName

                    width: parent.width - locationIcon.width
                        - parent.spacing
                    text: WeatherPlugin.locationName || qsTr("位置未知")
                    color: root.supportingInk
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeBodySmall
                    elide: Text.ElideRight
                }
            }

            Text {
                width: parent.width
                text: root.coordinateText()
                color: root.supportingInk
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.typeLabelSmall
                elide: Text.ElideRight
            }
        }
    }

    Item {
        id: metricBand

        anchors {
            left: parent.left
            right: weatherCluster.left
            bottom: parent.bottom
            margins: Appearance.spacing.small
            rightMargin: Appearance.spacing.medium
        }
        height: Math.max(
            44,
            Math.min(58, root.height * 0.31)
        )

        Row {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            height: parent.height
            spacing: Appearance.spacing.medium

            CompactMetric {
                width: implicitWidth
                height: parent.height
                iconName: "humidity_percentage"
                value: root.percentText(
                    WeatherPlugin.currentRelativeHumidity
                )
            }

            CompactMetric {
                width: implicitWidth
                height: parent.height
                iconName: "air"
                value: root.speedText(
                    WeatherPlugin.currentWindSpeedMs
                )
            }

            CompactMetric {
                width: implicitWidth
                height: parent.height
                iconName: "compress"
                value: root.pressureText(
                    WeatherPlugin.currentPressureHpa
                )
            }

            CompactMetric {
                width: implicitWidth
                height: parent.height
                iconName: "visibility"
                value: root.visibilityText(
                    WeatherPlugin.currentVisibilityM
                )
            }
        }
    }

    Item {
        id: weatherCluster

        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
            margins: Appearance.spacing.small
        }
        width: Math.max(
            160,
            Math.min(176, root.width * 0.34)
        )
        z: 2

        MaterialShape {
            id: weatherShape

            anchors {
                top: parent.top
                right: parent.right
                rightMargin: Appearance.spacing.medium
            }
            width: Math.min(178, parent.width + 6)
            height: Math.min(108, parent.height * 0.76)
            shape: MaterialShape.Pill
            color: Appearance.colors.colTertiaryContainer
            animationDuration:
                Appearance.animation.expressiveSlowSpatial.duration
            animationEasing:
                Appearance.animation.expressiveSlowSpatial.type

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.dataAvailable
                    ? WeatherPlugin.currentIconName
                    : (WeatherPlugin.loading
                        ? "sync"
                        : "cloud_off")
                iconSize: Math.min(
                    38,
                    weatherShape.height * 0.46
                )
                fill: 1
                color: Appearance.colors.colOnTertiaryContainer
            }
            z: 1
        }

        MaterialShape {
            id: astroBadge

            anchors {
                right: parent.right
                bottom: parent.bottom
            }
            width: Math.min(150, parent.width * 0.88)
            height: Math.min(78, parent.height * 0.55)
            shape: MaterialShape.Cookie9Sided
            color: Appearance.colors.colPrimaryContainer
            z: 2

            ColumnLayout {
                anchors {
                    centerIn: parent
                    verticalCenterOffset: 1
                }
                width: Math.min(104, parent.width * 0.76)
                height: Math.min(52, parent.height * 0.7)
                spacing: 0

                AstroMetric {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    iconName: "wb_twilight"
                    value: root.timeText(
                        root.currentDetails.sunrise
                    )
                }

                AstroMetric {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    iconName: "bedtime"
                    value: root.timeText(
                        root.currentDetails.sunset
                    )
                }
            }
        }
    }
}
