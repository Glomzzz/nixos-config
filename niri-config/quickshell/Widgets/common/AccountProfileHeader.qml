import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root

    property string wallpaperPath: ""
    property bool colorWallpaper: false
    property string avatarUrl: ""
    property string fallbackAvatarUrl: ""
    property string accountIdentity: ""
    property string distroId: "linux"
    property string distroName: "Linux"
    property string uptimeText: ""
    property int totalPackageCount: -1
    property int pendingUpdateCount: -1
    property bool showPackageStats: true
    property string avatarActionLabel: qsTr("更改头像")
    property real coverHeight: Math.max(150, Math.min(220, width * 0.23))
    property real profileAreaHeight: 120
    property real avatarSize: 104
    property real avatarCoverFraction: 0.42

    signal avatarActivated()

    readonly property color profileSurfaceColor:
        Appearance.m3colors.m3surfaceContainerHigh
    readonly property string wallpaperUrl: wallpaperPath !== "" && !colorWallpaper
        ? Paths.fileUrl(wallpaperPath) : ""

    function distroLogo() {
        const logos = {
            "arch": "󰣇",
            "archlinux": "󰣇",
            "cachyos": "󰣇",
            "endeavouros": "",
            "manjaro": "",
            "fedora": "",
            "ubuntu": "",
            "debian": "",
            "opensuse": "",
            "nixos": "",
            "gentoo": "",
            "void": "",
            "alpine": ""
        };
        return logos[String(root.distroId || "").toLowerCase()] || "";
    }

    implicitHeight: coverHeight + profileAreaHeight
    radius: Appearance.rounding.extraLarge
    color: profileSurfaceColor
    antialiasing: true
    clip: true

    Rectangle {
        id: cover

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.coverHeight
        topLeftRadius: root.radius
        topRightRadius: root.radius
        color: root.colorWallpaper
            ? root.wallpaperPath : Appearance.colors.colPrimaryContainer

        gradient: root.wallpaperUrl === "" && !root.colorWallpaper
            ? fallbackGradient : null

        Gradient {
            id: fallbackGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Appearance.colors.colPrimaryContainer }
            GradientStop { position: 1; color: Appearance.colors.colTertiaryContainer }
        }

        Image {
            id: wallpaperImage

            anchors.fill: parent
            source: root.wallpaperUrl
            sourceSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            visible: false
        }

        Rectangle {
            id: coverMask

            anchors.fill: parent
            topLeftRadius: root.radius
            topRightRadius: root.radius
            color: "black"
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaperImage
            maskEnabled: true
            maskSource: coverMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
            opacity: wallpaperImage.status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve:
                        Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            topLeftRadius: root.radius
            topRightRadius: root.radius
            color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.08)
        }
    }

    Rectangle {
        id: avatarFrame

        x: Appearance.spacing.panelPadding
        y: root.coverHeight - root.avatarSize * root.avatarCoverFraction
        z: 2
        width: root.avatarSize
        height: root.avatarSize
        radius: Appearance.rounding.full
        color: "transparent"

        Rectangle {
            id: avatarSurface

            anchors.fill: parent
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimaryContainer

            Image {
                id: fallbackAvatar
                anchors.fill: parent
                source: root.fallbackAvatarUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            Image {
                id: profileAvatar
                anchors.fill: parent
                source: root.avatarUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: false
            }

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: Appearance.rounding.full
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: profileAvatar.status === Image.Ready
                    ? profileAvatar : fallbackAvatar
                maskEnabled: true
                maskSource: avatarMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
                visible: profileAvatar.status === Image.Ready
                    || fallbackAvatar.status === Image.Ready
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: profileAvatar.status !== Image.Ready
                    && fallbackAvatar.status !== Image.Ready
                text: "account_circle"
                iconSize: 42
                color: Appearance.colors.colOnPrimaryContainer
            }

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.full
                color: Appearance.applyAlpha(Appearance.m3colors.m3scrim, 0.68)
                opacity: avatarButton.pointerHovered ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 160 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "edit"
                    iconSize: 28
                    fill: 1
                    color: Appearance.colors.colOnImage
                }
            }
        }

        MaterialRippleButton {
            id: avatarButton

            anchors.fill: parent
            padding: 0
            focusPolicy: Qt.StrongFocus
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.transparentize(
                Appearance.colors.colOnImage, 1)
            colBackgroundHover: Appearance.transparentize(
                Appearance.colors.colOnImage, 1)
            colRipple: Appearance.colors.colOnImage
            rippleOpacity: 0.22
            Accessible.name: root.avatarActionLabel
            onClicked: {
                focus = false
                root.avatarActivated()
            }
            contentItem: Item {}
        }
    }

    RowLayout {
        anchors.left: avatarFrame.right
        anchors.leftMargin: Appearance.spacing.large
        anchors.right: parent.right
        anchors.rightMargin: Appearance.spacing.large
        anchors.top: cover.bottom
        height: root.profileAreaHeight
        spacing: Appearance.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Appearance.spacing.xSmall

            Text {
                Layout.fillWidth: true
                text: root.accountIdentity
                color: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.typeTitleLarge
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Text {
                    text: root.distroLogo()
                    color: Appearance.colors.colPrimary
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 18
                }

                Text {
                    Layout.maximumWidth: parent.width * 0.44
                    text: root.distroName
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeBodyMedium
                    elide: Text.ElideRight
                }

                MaterialSymbol {
                    text: "schedule"
                    iconSize: 18
                    color: Appearance.colors.colOnSurfaceVariant
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("已运行 %1").arg(root.uptimeText)
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeBodyMedium
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            visible: root.showPackageStats
            spacing: Appearance.spacing.small

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Appearance.spacing.small

                MaterialSymbol {
                    text: "inventory_2"
                    iconSize: 18
                    color: Appearance.colors.colOnSurfaceVariant
                }

                Text {
                    text: qsTr("软件包")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeBodyMedium
                }

                Text {
                    Layout.minimumWidth: 34
                    text: root.totalPackageCount >= 0
                        ? root.totalPackageCount : "—"
                    horizontalAlignment: Text.AlignRight
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeBodyMedium
                    font.weight: Font.DemiBold
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Appearance.spacing.small

                MaterialSymbol {
                    text: "system_update_alt"
                    iconSize: 18
                    color: root.pendingUpdateCount > 0
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnSurfaceVariant
                }

                Text {
                    text: qsTr("待更新")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeBodyMedium
                }

                Text {
                    Layout.minimumWidth: 34
                    text: root.pendingUpdateCount >= 0
                        ? root.pendingUpdateCount : "—"
                    horizontalAlignment: Text.AlignRight
                    color: root.pendingUpdateCount > 0
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeBodyMedium
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
