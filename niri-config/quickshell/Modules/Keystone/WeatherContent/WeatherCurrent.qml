import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clavis.Weather 1.0
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    implicitHeight: layout.implicitHeight
    implicitWidth: 300

    signal refreshRequested()

    property string locationName: qsTr("Weather")
    property string currentTemp: "--"
    property string currentIcon: "cloud"
    property string currentDesc: "--"
    property string highTemp: "--"
    property string lowTemp: "--"

    function syncData() {
        if (!WeatherPlugin.hasValidData) {
            root.locationName = WeatherPlugin.locationName || qsTr("Weather");
            root.currentTemp = "--";
            root.currentIcon = "cloud";
            root.currentDesc = "--";
            root.highTemp = "--";
            root.lowTemp = "--";
            return;
        }

        root.locationName = WeatherPlugin.locationName || qsTr("Unknown");
        root.currentTemp = Math.round(WeatherPlugin.currentTemperatureC || 0) + "°";
        root.currentIcon = WeatherPlugin.currentIconName || "cloud";
        root.currentDesc = WeatherPlugin.currentWeatherText || qsTr("Unknown");

        if (WeatherPlugin.dailyForecast.count() > 0) {
            const today = WeatherPlugin.dailyForecast.get(0);
            const dayPart = today.day || {};
            root.highTemp = Math.round(Number(today.temperatureMaxC || dayPart.temperatureC || 0)) + "°";
            root.lowTemp = Math.round(Number(today.temperatureMinC || 0)) + "°";
        } else {
            root.highTemp = "--";
            root.lowTemp = "--";
        }
    }

    Connections {
        target: WeatherPlugin
        function onDataChanged() {
            syncData();
        }
    }

    Component.onCompleted: syncData()

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: 8

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.currentIcon
            iconSize: 64
            fill: 1
            color: Appearance.colors.colPrimary
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: -4

            Text {
                text: root.locationName
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Sizes.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.maximumWidth: 120
            }

            Text {
                text: root.currentTemp
                color: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 42
                font.weight: Font.Light
                lineHeight: 0.95
            }

            Text {
                text: "↑" + root.highTemp + "  ↓" + root.lowTemp
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 12
            }
        }

        Item { Layout.fillWidth: true }

        ToolButton {
            id: refreshButton
            Layout.alignment: Qt.AlignVCenter
            width: 42
            height: 42
            enabled: !WeatherPlugin.loading
            hoverEnabled: true

            background: Item {}

            StyledToolTip { text: qsTr("Refresh weather") }

            contentItem: MaterialSymbol {
                id: refreshIcon
                text: "refresh"
                iconSize: 26
                color: Appearance.colors.colOnSurface
                anchors.centerIn: parent

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: WeatherPlugin.loading
                }

                Behavior on rotation {
                    enabled: !WeatherPlugin.loading
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }

            onClicked: root.refreshRequested()
        }
    }
}
