import QtQuick
import QtQuick.Layouts
import M3Shapes
import qs.Common
import qs.Components
import "../../../../Common/functions/SystemFormat.js" as Format

Rectangle {
    id: root

    property var network: ({})
    property var downloadHistory: []
    property var uploadHistory: []
    property bool chartActive: visible
    property int updateInterval: 1000

    radius: Appearance.rounding.extraLarge
    color: Appearance.colors.colSurfaceContainer
    clip: true
    Accessible.name: qsTr("Network, download ")
        + Format.bytesPerSecond(
            root.network.downloadBytesPerSecond
        )
        + qsTr(", upload ")
        + Format.bytesPerSecond(
            root.network.uploadBytesPerSecond
        )

    ColumnLayout {
        anchors {
            fill: parent
            margins: Appearance.spacing.small
        }
        spacing: Appearance.spacing.xSmall

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: Appearance.spacing.small

            MaterialShape {
                implicitSize: 36
                shape: MaterialShape.Gem
                color: Appearance.colors.colPrimary

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "swap_vert"
                    iconSize: 19
                    fill: 1
                    color: Appearance.colors.colOnPrimary
                }
            }

            ColumnLayout {
                Layout.preferredWidth: Math.min(
                    72,
                    root.width * 0.22
                )
                spacing: -1

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Network")
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.typeTitleSmall
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: root.network.defaultInterface
                        || qsTr("All interfaces")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeLabelSmall
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.preferredWidth: 78
                Layout.minimumWidth: 68
                spacing: -2

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Download")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignLeft
                }

                Text {
                    Layout.fillWidth: true
                    text: "↓ " + Format.bytesPerSecond(
                        root.network.downloadBytesPerSecond
                    )
                    color: Appearance.colors.colTertiary
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeLabelSmall
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 78
                Layout.minimumWidth: 68
                spacing: -2

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Upload")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignLeft
                }

                Text {
                    Layout.fillWidth: true
                    text: "↑ " + Format.bytesPerSecond(
                        root.network.uploadBytesPerSecond
                    )
                    color: Appearance.colors.colPrimary
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeLabelSmall
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                }
            }
        }

        SystemSparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 44
            Layout.maximumHeight: Math.max(
                54,
                root.height * 0.56
            )
            values: root.downloadHistory
            secondaryValues: root.uploadHistory
            historyLength: 60
            updateInterval: root.updateInterval
            active: root.chartActive
            accessibilityName: qsTr("Network trend over the last minute")
            accessibilityDescription: qsTr("Download ")
                + Format.bytesPerSecond(
                    root.network.downloadBytesPerSecond
                )
                + qsTr(", upload ")
                + Format.bytesPerSecond(
                    root.network.uploadBytesPerSecond
                )
            lineColor: Appearance.colors.colTertiary
            secondaryLineColor: Appearance.colors.colPrimary
            baselineColor: Appearance.colors.colOutlineVariant
            lineWidth: 2.2
            fillOpacity: 0.14
        }
    }
}
