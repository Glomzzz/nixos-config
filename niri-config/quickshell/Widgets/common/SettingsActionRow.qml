import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

MaterialRippleButton {
    id: root

    property string iconName: ""
    property string trailingIconName: "open_in_new"

    implicitHeight: 56
    leftPadding: Appearance.spacing.small
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    buttonRadius: Appearance.rounding.full
    colBackground: Appearance.transparentize(
        Appearance.colors.colLayer2Hover, 1)
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colRipple: Appearance.colors.colLayer2Active

    contentItem: RowLayout {
        spacing: Appearance.spacing.medium

        MaterialSymbol {
            visible: root.iconName !== ""
            text: root.iconName
            iconSize: 22
            color: Appearance.colors.colOnSurfaceVariant
        }

        Text {
            Layout.fillWidth: true
            text: root.text
            color: Appearance.colors.colOnSurface
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeBodyMedium
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Item {
            Layout.preferredWidth: 48
            Layout.fillHeight: true
            visible: root.trailingIconName !== ""

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.trailingIconName
                iconSize: 20
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }
}
