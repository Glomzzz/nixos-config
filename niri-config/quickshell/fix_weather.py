import sys

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "r") as f:
    lines = f.readlines()

# Find the start of ColumnLayout { anchors.fill: parent; anchors.margins: 16
start_idx = -1
for i in range(len(lines)):
    if "ColumnLayout {" in lines[i] and "anchors.fill: parent" in lines[i+1] and "anchors.margins: 16" in lines[i+2]:
        start_idx = i
        break

if start_idx == -1:
    print("Could not find start index")
    sys.exit(1)

new_content = """    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 24

        // Left Column (Master)
        ColumnLayout {
            Layout.preferredWidth: 320
            Layout.fillHeight: true
            spacing: 16

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.hasWeather ? 0 : 1

                // Normal Weather Content
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 24

                        WeatherCurrent { Layout.fillWidth: true }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Appearance.colors.colOutlineVariant
                        }

                        WeatherFiveDayForecast { Layout.fillWidth: true }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Appearance.colors.colOutlineVariant
                        }

                        WeatherAQIIndicator { Layout.fillWidth: true }
                        WeatherSunriseSunset { Layout.fillWidth: true }
                    }
                }

                // Error / Loading State
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        BusyIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            running: WeatherPlugin.loading
                            visible: running
                            Material.accent: Appearance.colors.colPrimary
                        }

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "cloud_off"
                            iconSize: 38
                            color: Appearance.colors.colError
                            visible: !WeatherPlugin.loading
                        }

                        Text {
                            Layout.fillWidth: true
                            text: WeatherPlugin.loading
                                ? qsTr("正在加载天气")
                                : qsTr("天气不可用")
                            color: Appearance.colors.colOnSurface
                            font.family: Sizes.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: WeatherPlugin.loading
                                ? qsTr("正在查找本地天气预报…")
                                : root.weatherErrorText()
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Sizes.fontFamily
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Right Column (Stack 1 & 2)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // Map Area (Stack 1)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.large
                color: Appearance.colors.colSurfaceContainerHigh
                clip: true

                Loader {
                    id: weatherMapLoader
                    anchors.fill: parent
                    active: root.active
                    asynchronous: true
                    source: active ? Qt.resolvedUrl("WeatherMapCard.qml") : ""
                }

                Binding {
                    target: weatherMapLoader.item
                    property: "latitude"
                    value: root.latitude
                    when: weatherMapLoader.status === Loader.Ready
                }

                Binding {
                    target: weatherMapLoader.item
                    property: "longitude"
                    value: root.longitude
                    when: weatherMapLoader.status === Loader.Ready
                }

                Binding {
                    target: weatherMapLoader.item
                    property: "locationAvailable"
                    value: root.hasCoordinates()
                    when: weatherMapLoader.status === Loader.Ready
                }

                Binding {
                    target: weatherMapLoader.item
                    property: "active"
                    value: root.active && root.visible
                    when: weatherMapLoader.status === Loader.Ready
                }

                // Overlay refresh button on map (top right)
                ToolButton {
                    id: refreshButton
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 12

                    width: 42
                    height: 42
                    enabled: !WeatherPlugin.loading
                    hoverEnabled: true

                    background: Rectangle {
                        radius: Appearance.rounding.full
                        color: Appearance.applyAlpha(Appearance.colors.colSurfaceContainerHighest, 0.8)
                    }

                    contentItem: MaterialSymbol {
                        id: refreshIcon
                        text: "refresh"
                        iconSize: 20
                        color: Appearance.colors.colOnSurface
                        anchors.centerIn: parent
                    }

                    onClicked: root.fetchData()

                    RotationAnimation {
                        id: spinAnimation
                        target: refreshIcon
                        property: "rotation"
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }

                    RotationAnimation {
                        id: resetAnimation
                        target: refreshIcon
                        property: "rotation"
                        to: 0
                        duration: Appearance.animation.expressiveEffects.duration
                        direction: RotationAnimation.Shortest
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }

            // Parameters and Moon Phase (Stack 2)
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                spacing: 24

                WeatherParameters {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.hasWeather
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Appearance.colors.colOutlineVariant
                    visible: root.hasWeather
                }

                WeatherMoonPhase {
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true
                    visible: root.hasWeather
                }
            }
        }
    }
}
"""

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "w") as f:
    f.writelines(lines[:start_idx])
    f.write(new_content)

print("Done")
