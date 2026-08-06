import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 24

    readonly property real pageContentWidth: 600
    readonly property var templatePrograms: [
        ({
            "id": "btop",
            "title": "btop",
            "icon": "monitoring"
        }),
        ({
            "id": "kitty",
            "title": "Kitty",
            "icon": "terminal"
        }),
        ({
            "id": "fcitx5",
            "title": "Fcitx5",
            "icon": "keyboard"
        }),
        ({
            "id": "niri",
            "title": "Niri",
            "icon": "window"
        })
    ]

    ColumnLayout {
        id: contentColumn

        width: Math.min(root.pageContentWidth,
            Math.max(0, root.width - 48))
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: Appearance.spacing.medium

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: ThemeService.generating
            message: qsTr("Generating Matugen colors for enabled applications…")
            iconName: "progress_activity"
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Matugen templates")
            supportingText: qsTr("Wallpaper and theme changes update only enabled applications. Quickshell colors are always generated, and disabling an entry keeps its existing files.")

            Repeater {
                model: root.templatePrograms

                SettingsRow {
                    required property var modelData

                    Layout.fillWidth: true
                    iconName: modelData.icon
                    title: modelData.title
                    supportingText:
                        PersonalizationConfig
                            .isMatugenTemplateEnabled(modelData.id)
                        ? qsTr("Generate and update Matugen colors")
                        : qsTr("Generation disabled; existing files are kept")

                    trailing: StyledSwitch {
                        enabled: !ThemeService.generating
                        checked: PersonalizationConfig
                            .isMatugenTemplateEnabled(modelData.id)
                        Accessible.name:
                            qsTr("Enable the %1 Matugen template")
                                .arg(modelData.title)
                        onToggled:
                            ThemeService.setMatugenTemplateEnabled(
                                modelData.id, checked)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }
}
