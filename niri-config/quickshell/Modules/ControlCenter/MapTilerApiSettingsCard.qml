import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Quickshell
import Clavis.WeatherMap 1.0
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    property bool revealApiKey: false
    property string feedbackText: ""
    property bool feedbackError: false

    readonly property bool statusError:
        WeatherMapPlugin.mapTilerStatus === "keychain_error"

    implicitHeight: serviceContent.implicitHeight + 48
    radius: Appearance.rounding.large
    color: Appearance.colors.colSurfaceContainer

    function applyApiKey() {
        const value = mapTilerApiKeyField.text.trim()
        if (value.length < 16) {
            feedbackError = true
            feedbackText = qsTr("Enter a valid MapTiler API key")
            mapTilerApiKeyField.forceActiveFocus()
            return
        }

        const result = WeatherMapPlugin.storeMapTilerApiKey(value)
        feedbackError = !result.ok
        feedbackText = result.message || qsTr("Could not update the MapTiler API key")
    }

    function clearApiKey() {
        const result = WeatherMapPlugin.clearMapTilerApiKey()
        feedbackError = !result.ok
        feedbackText = result.message || qsTr("Could not clear the MapTiler API key")
    }

    function notifyMainShell() {
        Quickshell.execDetached([
            "qs",
            "--path",
            Paths.shellDir + "/shell.qml",
            "ipc",
            "call",
            "weather-map",
            "reloadCredentials"
        ])
    }

    Connections {
        target: WeatherMapPlugin

        function onCredentialOperationFinished(operation, success, message) {
            if (operation !== "maptiler_store"
                && operation !== "maptiler_clear") {
                return
            }

            root.feedbackError = !success
            root.feedbackText = message
            if (success) {
                mapTilerApiKeyField.clear()
                root.revealApiKey = false
                root.notifyMainShell()
            }
        }
    }

    ColumnLayout {
        id: serviceContent

        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Appearance.rounding.full
                color: Appearance.colors.colPrimaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "map"
                    iconSize: 22
                    fill: 1
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: "MapTiler Dataviz"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Used for the Dataviz weather map base layer")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                    textFormat: Text.PlainText
                }
            }

            Rectangle {
                implicitWidth: statusContent.implicitWidth + 24
                implicitHeight: 34
                radius: Appearance.rounding.full
                color: root.statusError
                    ? Appearance.colors.colErrorContainer
                    : WeatherMapPlugin.mapTilerConfigured
                        ? Appearance.colors.colPrimaryContainer
                        : Appearance.colors.colSurfaceContainerHighest

                RowLayout {
                    id: statusContent

                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: !WeatherMapPlugin.credentialsReady
                            || WeatherMapPlugin.mapTilerStatus
                                === "loading_credentials"
                            || WeatherMapPlugin.credentialBusy
                            ? "sync"
                            : root.statusError
                                ? "error"
                                : WeatherMapPlugin.mapTilerConfigured
                                    ? "check_circle"
                                    : "key_off"
                        iconSize: 17
                        fill: WeatherMapPlugin.mapTilerConfigured ? 1 : 0
                        color: root.statusError
                            ? Appearance.colors.colOnErrorContainer
                            : WeatherMapPlugin.mapTilerConfigured
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurfaceVariant
                    }

                    Text {
                        text: !WeatherMapPlugin.credentialsReady
                            || WeatherMapPlugin.mapTilerStatus
                                === "loading_credentials"
                            ? qsTr("Checking")
                            : WeatherMapPlugin.credentialBusy
                                ? qsTr("Processing")
                                : root.statusError
                                    ? qsTr("Read failed")
                                    : WeatherMapPlugin.mapTilerConfigured
                                        ? qsTr("Configured")
                                        : qsTr("Not configured")
                        color: root.statusError
                            ? Appearance.colors.colOnErrorContainer
                            : WeatherMapPlugin.mapTilerConfigured
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurfaceVariant
                        font.family: Sizes.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Appearance.colors.colOutlineVariant
        }

        Text {
            Layout.fillWidth: true
            text: "MapTiler API key"
            color: Appearance.colors.colOnSurface
            font.family: Sizes.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
            textFormat: Text.PlainText
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56

            MaterialTextField {
                id: mapTilerApiKeyField

                anchors.fill: parent
                placeholderText: qsTr("Enter MapTiler API key")
                echoMode: root.revealApiKey
                    ? TextInput.Normal
                    : TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData
                    | Qt.ImhNoPredictiveText
                    | Qt.ImhNoAutoUppercase
                maximumLength: 128
                rightPadding: 52
                enabled: WeatherMapPlugin.credentialsReady
                    && !WeatherMapPlugin.credentialBusy
                color: Appearance.colors.colOnSurface
                placeholderTextColor: Appearance.colors.colOnSurfaceVariant
                Material.theme: PersonalizationConfig.themeMode === "light"
                    ? Material.Light
                    : Material.Dark
                Material.containerStyle: Material.Outlined
                Material.foreground: Appearance.colors.colOnSurface
                Accessible.name: "MapTiler API key"
                Accessible.description: qsTr("Saved securely in the system keyring")
                onTextChanged: {
                    if (root.feedbackError) {
                        root.feedbackError = false
                        root.feedbackText = ""
                    }
                }
                onAccepted: root.applyApiKey()
            }

            ToolButton {
                id: visibilityButton

                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.name: root.revealApiKey
                    ? qsTr("Hide API key")
                    : qsTr("Show API key")
                onClicked: root.revealApiKey = !root.revealApiKey

                background: Rectangle {
                    radius: Appearance.rounding.full
                    color: visibilityButton.down
                        ? Appearance.colors.colLayer3Active
                        : visibilityButton.hovered
                            || visibilityButton.activeFocus
                            ? Appearance.colors.colLayer3Hover
                            : "transparent"
                }

                contentItem: MaterialSymbol {
                    text: root.revealApiKey
                        ? "visibility_off"
                        : "visibility"
                    iconSize: 20
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledToolTip {
                    extraVisibleCondition: visibilityButton.hovered
                    text: root.revealApiKey
                        ? qsTr("Hide API key")
                        : qsTr("Show API key")
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("The key is stored in the system keyring and takes effect immediately after saving.")
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Sizes.fontFamily
            font.pixelSize: 12
            lineHeight: 1.35
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: feedbackRow.implicitHeight + 20
            radius: Appearance.rounding.small
            visible: root.feedbackText !== ""
            color: root.feedbackError
                ? Appearance.colors.colErrorContainer
                : Appearance.colors.colPrimaryContainer

            RowLayout {
                id: feedbackRow

                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                MaterialSymbol {
                    text: WeatherMapPlugin.credentialBusy
                        ? "sync"
                        : root.feedbackError
                            ? "error"
                            : "check_circle"
                    iconSize: 18
                    fill: WeatherMapPlugin.credentialBusy ? 0 : 1
                    color: root.feedbackError
                        ? Appearance.colors.colOnErrorContainer
                        : Appearance.colors.colOnPrimaryContainer
                }

                Text {
                    Layout.fillWidth: true
                    text: root.feedbackText
                    color: root.feedbackError
                        ? Appearance.colors.colOnErrorContainer
                        : Appearance.colors.colOnPrimaryContainer
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("Clear key")
                flat: true
                enabled: WeatherMapPlugin.mapTilerConfigured
                    && !WeatherMapPlugin.credentialBusy
                focusPolicy: Qt.StrongFocus
                Material.foreground: Appearance.colors.colOnSurfaceVariant
                Accessible.description: qsTr("Remove the MapTiler API key from the system keyring")
                onClicked: root.clearApiKey()
            }

            Button {
                id: saveButton

                text: qsTr("Save key")
                highlighted: true
                enabled: WeatherMapPlugin.credentialsReady
                    && !WeatherMapPlugin.credentialBusy
                    && mapTilerApiKeyField.text.trim().length >= 16
                focusPolicy: Qt.StrongFocus
                Material.background: Appearance.colors.colPrimary
                Material.foreground: Appearance.colors.colOnPrimary
                Material.elevation: 2
                Accessible.description: qsTr("Save securely and apply immediately without restarting")
                onClicked: root.applyApiKey()

                contentItem: Text {
                    text: saveButton.text
                    color: saveButton.enabled
                        ? Appearance.colors.colOnPrimary
                        : Appearance.applyAlpha(
                            Appearance.colors.colOnSurface,
                            0.72
                        )
                    font: saveButton.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
