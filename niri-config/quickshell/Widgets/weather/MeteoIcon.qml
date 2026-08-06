import QtQuick
import qs.Common
import qs.Components

Item {
    id: root

    property int weatherCode: -1
    property string iconName: ""
    property bool night: false
    property string style: "flat"
    property bool animated: true
    property bool playing: visible
    property real baseSize: 128
    property color iconColor: normalizedStyle() === "flat"
        ? Appearance.colors.colOnImage
        : Appearance.colors.colPrimary
    readonly property string resolvedIcon: materialIcon()

    function normalizedStyle() {
        if (style === "fill" || style === "line" || style === "monochrome" || style === "flat") return style
        return "flat"
    }

    function iconForCode(code, isNight) {
        if (code === 0 || code === 1)
            return isNight ? "clear_night" : "clear_day"
        if (code === 2)
            return isNight ? "partly_cloudy_night" : "partly_cloudy_day"
        if (code === 3)
            return "cloud"
        if (code === 45 || code === 48)
            return "foggy"
        if (code >= 51 && code <= 65)
            return "rainy"
        if (code === 66 || code === 67)
            return "weather_mix"
        if (code >= 71 && code <= 77)
            return "snowing"
        if (code >= 80 && code <= 82)
            return "rainy"
        if (code === 85 || code === 86)
            return "weather_mix"
        if (code === 95)
            return "thunderstorm"
        if (code === 96 || code === 99)
            return "weather_hail"
        return ""
    }

    function iconFromName(name, isNight) {
        if (!name || name.length === 0) return ""
        if (name.indexOf("clear_night") >= 0) return "clear_night"
        if (name.indexOf("sun") >= 0) return "clear_day"
        if (name.indexOf("partly") >= 0)
            return isNight ? "partly_cloudy_night" : "partly_cloudy_day"
        if (name.indexOf("cloud") >= 0) return "cloud"
        if (name.indexOf("fog") >= 0) return "foggy"
        if (name.indexOf("drizzle") >= 0) return "rainy"
        if (name.indexOf("sleet") >= 0) return "weather_mix"
        if (name.indexOf("rain") >= 0) return "rainy"
        if (name.indexOf("snow") >= 0) return "snowing"
        if (name.indexOf("thunder") >= 0) return "thunderstorm"
        if (name.indexOf("hail") >= 0) return "weather_hail"
        return ""
    }

    function materialIcon() {
        const byCode = iconForCode(weatherCode, night)
        if (byCode.length > 0) return byCode
        const byName = iconFromName(iconName, night)
        return byName.length > 0 ? byName : "cloud_off"
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.resolvedIcon
        iconSize: Math.max(1, Math.min(root.width, root.height))
        fill: root.normalizedStyle() === "line" ? 0 : 1
        color: root.iconColor
    }
}
