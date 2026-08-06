import QtQuick
import qs.Common

Item {
    id: root

    property var screen: null
    property bool foreground: false

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "network"

        NetworkContent {
            anchors.fill: parent
            foreground: root.foreground
                && WidgetState.qsView === "network"
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "bluetooth"

        BluetoothContent {
            anchors.fill: parent
            foreground: root.foreground
                && WidgetState.qsView === "bluetooth"
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "idle"

        IdleContent {
            anchors.fill: parent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "audio"

        AudioContent {
            anchors.fill: parent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "microphone"

        MicrophoneContent {
            anchors.fill: parent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "settings"
        hubPage: true

        SettingsContent {
            anchors.fill: parent
            screen: root.screen
        }
    }
}
