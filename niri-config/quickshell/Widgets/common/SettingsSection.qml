import QtQuick
import QtQuick.Layouts
import qs.Common

Rectangle {
    id: root

    property string title: ""
    property string supportingText: ""
    default property alias content: body.data

    implicitHeight: sectionLayout.implicitHeight + Appearance.spacing.medium * 2
    radius: Appearance.rounding.large
    color: Appearance.colors.colLayer1

    ColumnLayout {
        id: sectionLayout

        anchors {
            fill: parent
            margins: Appearance.spacing.medium
        }
        spacing: Appearance.spacing.small

        Text {
            Layout.fillWidth: true
            visible: root.title.length > 0
            text: root.title
            color: Appearance.colors.colOnLayer2
            font.family: Sizes.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.supportingText.length > 0
            text: root.supportingText
            color: Appearance.colors.colOnLayer1
            font.family: Sizes.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            spacing: Appearance.spacing.xSmall
        }
    }
}
