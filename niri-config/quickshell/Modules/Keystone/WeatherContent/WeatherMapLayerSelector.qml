import QtQuick
import qs.Widgets.common

StyledButtonGroup {
    id: root

    property string currentMode: "temp"
    signal modeSelected(string mode)

    currentValue: currentMode
    style: StyledButtonGroup.Style.Primary
    buttonHeight: 34
    horizontalPadding: 11
    buttonMinWidth: 42
    pressedExpansion: 4
    textPixelSize: 11
    model: [
        ({
            "value": "temp",
            "label": qsTr("Temp"),
            "tooltip": qsTr("Temperature heat map")
        }),
        ({
            "value": "rain",
            "label": qsTr("Rain"),
            "tooltip": qsTr("Current precipitation map")
        }),
        ({
            "value": "clouds",
            "label": qsTr("Cloud"),
            "tooltip": qsTr("Current cloud-cover map")
        }),
        ({
            "value": "wind",
            "label": qsTr("Wind"),
            "tooltip": qsTr("Current wind-speed map")
        }),
        ({
            "value": "pressure",
            "label": qsTr("Pressure"),
            "tooltip": qsTr("Current atmospheric-pressure map")
        })
    ]

    Accessible.name: qsTr("Weather map layer")
    onValueSelected: value => root.modeSelected(value)
}
