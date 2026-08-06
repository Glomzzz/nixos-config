import QtQuick
import M3Shapes

Item {
    width: 240
    height: 120

    MaterialShape {
        anchors.fill: parent
        shape: MaterialShape.Cookie12Sided
        fromShape: MaterialShape.Pill
        toShape: MaterialShape.Gem
        morphProgress: 0.5
        color: "#ff6750a4"
    }
}
