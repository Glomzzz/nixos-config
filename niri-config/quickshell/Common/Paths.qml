pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string shellDir: Quickshell.shellDir
    readonly property string assetsDir: shellDir + "/assets"
    readonly property string fontsDir: assetsDir + "/fonts"
    readonly property string iconsDir: assetsDir + "/icons"
    readonly property string rcloneIconsDir: iconsDir + "/rclone"
    readonly property string imagesDir: assetsDir + "/images"

    readonly property string scriptsDir: shellDir + "/scripts"
    readonly property string systemScriptsDir: scriptsDir + "/system"

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string currentWallpaper: homeDir + "/.cache/wallpaper_rofi/current"
    readonly property string profileAvatar: homeDir + "/.face"
    readonly property string defaultAvatar: imagesDir + "/dino.png"

    function fileUrl(path) {
        const value = String(path);
        return value.startsWith("file://") ? value : "file://" + value;
    }

    function icon(name) {
        return fileUrl(iconsDir + "/" + name);
    }

    function scriptPath(group, name) {
        return scriptsDir + "/" + group + "/" + name;
    }
}
