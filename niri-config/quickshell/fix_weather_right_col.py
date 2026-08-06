import sys

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "r") as f:
    lines = f.readlines()

start_idx = -1
for i, line in enumerate(lines):
    if "// Right Column (Stack 1 & 2)" in line:
        start_idx = i
        break

if start_idx == -1:
    print("Could not find start index")
    sys.exit(1)

new_content = """        // Right Column (Stack 1, 2, 3)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24

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

            // Parameters (Stack 2)
            WeatherParameters {
                Layout.fillWidth: true
                visible: root.hasWeather
            }

            // Moon Phase (Stack 3)
            WeatherMoonPhase {
                Layout.fillWidth: true
                visible: root.hasWeather
            }
        }
    }
}
"""

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "w") as f:
    f.writelines(lines[:start_idx])
    f.write(new_content)

print("Done")
