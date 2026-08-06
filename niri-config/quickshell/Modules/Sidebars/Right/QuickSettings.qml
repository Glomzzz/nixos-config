import QtQuick
import qs.Common

Item {
    id: root

    property var screen: null
    property bool foreground: false
    property var retainedViews: ({ "settings": true })

    function retainView(view) {
        if (root.retainedViews[view])
            return;
        const next = {};
        for (const key in root.retainedViews)
            next[key] = root.retainedViews[key];
        next[view] = true;
        root.retainedViews = next;
    }

    Component.onCompleted: root.retainView(WidgetState.qsView)

    Connections {
        target: WidgetState

        function onQsViewChanged() {
            root.retainView(WidgetState.qsView);
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "network"

        Loader {
            anchors.fill: parent
            active: !!root.retainedViews.network
            asynchronous: true
            sourceComponent: networkContentComponent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "bluetooth"

        Loader {
            anchors.fill: parent
            active: !!root.retainedViews.bluetooth
            asynchronous: true
            sourceComponent: bluetoothContentComponent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "idle"

        Loader {
            anchors.fill: parent
            active: !!root.retainedViews.idle
            asynchronous: true
            sourceComponent: idleContentComponent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "audio"

        Loader {
            anchors.fill: parent
            active: !!root.retainedViews.audio
            asynchronous: true
            sourceComponent: audioContentComponent
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: WidgetState.qsView === "microphone"

        Loader {
            anchors.fill: parent
            active: !!root.retainedViews.microphone
            asynchronous: true
            sourceComponent: microphoneContentComponent
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

    Component {
        id: networkContentComponent

        NetworkContent {
            foreground: root.foreground
                && WidgetState.qsView === "network"
        }
    }

    Component {
        id: bluetoothContentComponent

        BluetoothContent {
            foreground: root.foreground
                && WidgetState.qsView === "bluetooth"
        }
    }

    Component {
        id: idleContentComponent

        IdleContent {}
    }

    Component {
        id: audioContentComponent

        AudioContent {}
    }

    Component {
        id: microphoneContentComponent

        MicrophoneContent {}
    }
}
