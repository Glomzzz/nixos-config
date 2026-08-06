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
            "label": qsTr("温度"),
            "tooltip": qsTr("温度热力图")
        }),
        ({
            "value": "rain",
            "label": qsTr("降水"),
            "tooltip": qsTr("当前降水地图")
        }),
        ({
            "value": "clouds",
            "label": qsTr("云量"),
            "tooltip": qsTr("当前云量地图")
        }),
        ({
            "value": "wind",
            "label": qsTr("风速"),
            "tooltip": qsTr("当前风速地图")
        }),
        ({
            "value": "pressure",
            "label": qsTr("气压"),
            "tooltip": qsTr("当前大气压地图")
        })
    ]

    Accessible.name: qsTr("天气地图图层")
    onValueSelected: value => root.modeSelected(value)
}
