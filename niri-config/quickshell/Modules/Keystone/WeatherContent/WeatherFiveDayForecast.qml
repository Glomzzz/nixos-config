import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clavis.Weather 1.0
import qs.Common
import qs.Components

Item {
    id: root

    implicitHeight: layout.implicitHeight
    implicitWidth: 300

    property var dailyData: []

    function syncForecast() {
        if (!WeatherPlugin.hasValidData) {
            root.dailyData = [];
            return;
        }

        const nextDaily = [];
        const count = Math.min(5, WeatherPlugin.dailyForecast.count());

        let globalMin = 1000;
        let globalMax = -1000;

        for (let i = 0; i < count; ++i) {
            const item = WeatherPlugin.dailyForecast.get(i);
            const dayPart = item.day || {};
            const minTemp = Number(item.temperatureMinC || 0);
            const maxTemp = Number(item.temperatureMaxC || dayPart.temperatureC || 0);

            if (minTemp < globalMin) globalMin = minTemp;
            if (maxTemp > globalMax) globalMax = maxTemp;

            const dateObject = item.date
                ? new Date(item.date + "T00:00:00")
                : new Date(Number(item.time || 0) * 1000);

            nextDaily.push({
                dayIndex: dateObject.getDay(),
                icon: dayPart.iconName || item.iconName || "cloud",
                minTemp: Math.round(minTemp),
                maxTemp: Math.round(maxTemp),
                rawMin: minTemp,
                rawMax: maxTemp
            });
        }

        // Calculate offsets
        if (globalMax - globalMin < 1) {
            globalMax += 1;
            globalMin -= 1;
        }
        const range = globalMax - globalMin;

        for (let i = 0; i < nextDaily.length; ++i) {
            nextDaily[i].startRatio = (nextDaily[i].rawMin - globalMin) / range;
            nextDaily[i].widthRatio = (nextDaily[i].rawMax - nextDaily[i].rawMin) / range;
        }

        root.dailyData = nextDaily;
    }

    Connections {
        target: WeatherPlugin
        function onDataChanged() {
            syncForecast();
        }
    }

    Component.onCompleted: syncForecast()

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 20

        Repeater {
            model: root.dailyData

            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 8

                property var week: [qsTr("周日"), qsTr("周一"), qsTr("周二"), qsTr("周三"), qsTr("周四"), qsTr("周五"), qsTr("周六")]

                Text {
                    Layout.preferredWidth: 40
                    text: index === 0 ? qsTr("今天") : week[modelData.dayIndex]
                    color: index === 0 ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 16
                    font.weight: index === 0 ? Font.Medium : Font.Normal
                }

                MaterialSymbol {
                    text: modelData.icon
                    iconSize: 26
                    fill: 1
                    color: Appearance.colors.colPrimary
                }

                Text {
                    Layout.preferredWidth: 32
                    text: modelData.minTemp + "°"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: Math.min(width, height) / 2
                        color: Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.22)
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * modelData.startRatio
                        width: Math.max(parent.height, parent.width * modelData.widthRatio)
                        height: 8
                        radius: Math.min(width, height) / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.55) }
                            GradientStop { position: 1.0; color: Appearance.colors.colPrimary }
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: 32
                    text: modelData.maxTemp + "°"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 16
                }
            }
        }
    }
}
