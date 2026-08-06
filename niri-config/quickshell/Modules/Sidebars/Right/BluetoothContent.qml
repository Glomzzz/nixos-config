import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

WidgetPanel {
    id: root

    title: qsTr("Bluetooth")
    icon: "bluetooth"
    showBackButton: true
    backAction: () => WidgetState.qsView = "settings"

    property bool foreground: false
    readonly property bool isActive: root.foreground
        && WidgetState.qsView === "bluetooth"
    property bool discoveryLeaseAcquired: false
    property bool initialLoadAttempted: false
    property bool initialLoading: false
    property bool refreshLoading: false
    property var pendingForgetDevice: null
    readonly property bool linearLoading: refreshLoading || BluetoothService.busy
    readonly property string stateMessage: {
        if (BluetoothService.lastError.length > 0)
            return BluetoothService.lastError;
        if (!BluetoothService.available)
            return qsTr("No Bluetooth adapter detected or BlueZ is unavailable");
        if (!BluetoothService.enabled)
            return qsTr("Bluetooth is off");
        if (!root.initialLoading
                && !root.refreshLoading
                && BluetoothService.devices.length === 0)
            return qsTr("No Bluetooth devices discovered yet");
        return "";
    }

    function beginInitialLoad() {
        if (!root.isActive
                || !BluetoothService.available
                || !BluetoothService.enabled
                || root.initialLoadAttempted)
            return;

        initialLoadTimer.stop();
        root.initialLoadAttempted = true;
        root.initialLoading = BluetoothService.availableDevices.length === 0;
        if (root.initialLoading)
            initialLoadTimer.restart();
    }

    function finishInitialLoad() {
        initialLoading = false;
        initialLoadTimer.stop();
    }

    function finishTransientLoading() {
        finishInitialLoad();
        refreshLoading = false;
        refreshTimer.stop();
    }

    function updateDiscoveryLease() {
        if (isActive && !discoveryLeaseAcquired) {
            BluetoothService.acquireDiscovery("right-sidebar-bluetooth");
            discoveryLeaseAcquired = true;
            Qt.callLater(root.beginInitialLoad);
        } else if (!isActive && discoveryLeaseAcquired) {
            BluetoothService.releaseDiscovery("right-sidebar-bluetooth");
            discoveryLeaseAcquired = false;
            finishTransientLoading();
        }
    }

    function restartDiscoveryLease() {
        if (!root.discoveryLeaseAcquired
                || !BluetoothService.enabled
                || root.refreshLoading)
            return;
        finishInitialLoad();
        BluetoothService.releaseDiscovery("right-sidebar-bluetooth");
        BluetoothService.acquireDiscovery("right-sidebar-bluetooth");
        refreshLoading = true;
        refreshTimer.restart();
    }

    function iconForDevice(device) {
        const icon = String(device && device.icon || "").toLowerCase();
        if (icon.indexOf("head") >= 0 || icon.indexOf("audio") >= 0)
            return "headphones";
        if (icon.indexOf("speaker") >= 0)
            return "speaker";
        if (icon.indexOf("keyboard") >= 0)
            return "keyboard";
        if (icon.indexOf("mouse") >= 0 || icon.indexOf("input") >= 0)
            return "mouse";
        if (icon.indexOf("phone") >= 0)
            return "smartphone";
        if (icon.indexOf("computer") >= 0)
            return "computer";
        return "bluetooth";
    }

    function deviceSupportingText(device) {
        const states = [];
        if (device.blocked)
            states.push(qsTr("Blocked"));
        else if (device.pairing)
            states.push(qsTr("Pairing"));
        else if (device.connected)
            states.push(qsTr("Connected"));
        else if (device.paired || device.bonded)
            states.push(qsTr("Paired"));
        else
            states.push(qsTr("Available devices"));
        if (device.trusted)
            states.push(qsTr("Trusted"));
        if (device.batteryAvailable)
            states.push(qsTr("Battery ") + device.batteryLevel + "%");
        return states.join(" · ");
    }

    onIsActiveChanged: updateDiscoveryLease()
    Component.onCompleted: updateDiscoveryLease()
    Component.onDestruction: {
        if (discoveryLeaseAcquired)
            BluetoothService.releaseDiscovery("right-sidebar-bluetooth");
    }

    Connections {
        target: BluetoothService

        function onAvailableDevicesChanged() {
            if (BluetoothService.availableDevices.length > 0)
                root.finishInitialLoad();
        }

        function onEnabledChanged() {
            if (!BluetoothService.enabled)
                root.finishTransientLoading();
            else if (root.isActive)
                Qt.callLater(root.beginInitialLoad);
        }

        function onOperationFailed(operation, message) {
            if (operation === "discovery") {
                root.refreshLoading = false;
                refreshTimer.stop();
            }
        }
    }

    Timer {
        id: initialLoadTimer
        interval: 4000
        repeat: false
        onTriggered: root.initialLoading = false
    }

    Timer {
        id: refreshTimer
        interval: 1600
        repeat: false
        onTriggered: root.refreshLoading = false
    }

    headerTools: RowLayout {
        spacing: Appearance.spacing.xSmall

        ToolButton {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            enabled: BluetoothService.available
                && BluetoothService.enabled
                && !BluetoothService.busy
                && !root.refreshLoading
            hoverEnabled: true
            Accessible.name: qsTr("Scan for Bluetooth devices again")
            onClicked: root.restartDiscoveryLease()

            background: Rectangle {
                radius: Appearance.rounding.full
                color: parent.down
                    ? Appearance.colors.colLayer2Active
                    : parent.hovered ? Appearance.colors.colLayer2Hover : "transparent"
            }

            contentItem: MaterialSymbol {
                text: "refresh"
                iconSize: 21
                color: Appearance.colors.colOnLayer2

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: root.refreshLoading
                }
            }
        }

        StyledSwitch {
            scale: 0.8
            checked: BluetoothService.enabled
            enabled: BluetoothService.available && !BluetoothService.busy
            Accessible.name: qsTr("Bluetooth switch")
            onToggled: BluetoothService.setBluetoothEnabled(checked)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.small

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: root.linearLoading ? 4 : 0
            opacity: root.linearLoading ? 1 : 0
            indeterminate: true
            Material.accent: Appearance.colors.colPrimary

            Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
            Behavior on opacity { ElementMoveAnimation {} }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.stateMessage.length > 0
            tone: BluetoothService.lastError.length > 0 ? "error" : "info"
            message: root.stateMessage
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: bluetoothContent.implicitHeight

            ColumnLayout {
                id: bluetoothContent

                width: parent.width - Appearance.spacing.small
                spacing: Appearance.spacing.small

                DeviceSection {
                    Layout.fillWidth: true
                    visible: BluetoothService.enabled && BluetoothService.connectedDevices.length > 0
                    sectionTitle: qsTr("Connected")
                    devicesModel: BluetoothService.connectedDevices
                    category: "connected"
                }

                DeviceSection {
                    Layout.fillWidth: true
                    visible: BluetoothService.enabled && BluetoothService.pairedDevices.length > 0
                    sectionTitle: qsTr("Paired")
                    devicesModel: BluetoothService.pairedDevices
                    category: "paired"
                }

                SettingsSection {
                    Layout.fillWidth: true
                    visible: BluetoothService.enabled
                    title: qsTr("Available devices")

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.initialLoading
                            && BluetoothService.availableDevices.length === 0 ? 116 : 0
                        opacity: root.initialLoading ? 1 : 0
                        clip: true

                        Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
                        Behavior on opacity { ElementMoveAnimation {} }

                        Column {
                            anchors.centerIn: parent
                            spacing: Appearance.spacing.small

                            MaterialLoadingIndicator {
                                anchors.horizontalCenter: parent.horizontalCenter
                                running: root.initialLoading
                                accessibleName: qsTr("Searching for available Bluetooth devices")
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Searching for nearby devices")
                                color: Appearance.colors.colOnLayer1
                                font.family: Sizes.fontFamily
                                font.pixelSize: 12
                            }
                        }
                    }

                    StyledListView {
                        id: availableDeviceList

                        readonly property real baseContentHeight: count * 56
                            + Math.max(0, count - 1) * spacing

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(
                            Sizes.sidebarScrollableListMaxHeight,
                            Math.max(baseContentHeight, contentHeight)
                        )
                        visible: count > 0
                        spacing: Appearance.spacing.xSmall
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        smoothWheelEnabled: interactive
                        model: BluetoothService.availableDevices

                        delegate: BluetoothDeviceRow {
                            required property var modelData

                            width: ListView.view.width
                            deviceData: modelData
                            deviceCategory: "available"
                        }

                        Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: !root.initialLoading
                            && !root.refreshLoading
                            && BluetoothService.availableDevices.length === 0
                        iconName: "search_off"
                        title: qsTr("No available devices found")
                    }
                }

                SettingsSection {
                    Layout.fillWidth: true
                    title: qsTr("Adapters")
                    supportingText: BluetoothService.discovering
                        ? qsTr("Searching for nearby devices")
                        : BluetoothService.enabled ? qsTr("Device discovery is paused") : qsTr("Turn on Bluetooth to start discovery")

                    Repeater {
                        model: BluetoothService.adapters

                        SettingsRow {
                            required property var modelData

                            Layout.fillWidth: true
                            iconName: modelData.blocked ? "bluetooth_disabled" : "settings_bluetooth"
                            title: modelData.name || modelData.id || qsTr("Bluetooth adapter")
                            supportingText: modelData.blocked
                                ? qsTr("Blocked by rfkill")
                                : modelData.enabled ? modelData.state : qsTr("Off")
                            highlighted: modelData.enabled

                            trailing: StyledSwitch {
                                scale: 0.72
                                checked: modelData.enabled
                                enabled: !modelData.blocked && !BluetoothService.busy
                                Accessible.name: qsTr("Toggle adapter ") + (modelData.name || modelData.id)
                                onToggled: BluetoothService.setAdapterEnabled(modelData, checked)
                            }
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: BluetoothService.available
                        iconName: "visibility"
                        title: qsTr("Allow discovery")
                        supportingText: qsTr("Let nearby devices find this computer")
                        enabled: BluetoothService.enabled

                        trailing: StyledSwitch {
                            scale: 0.72
                            checked: BluetoothService.discoverable
                            enabled: BluetoothService.enabled && !BluetoothService.busy
                            Accessible.name: qsTr("Bluetooth discoverability")
                            onToggled: BluetoothService.setDiscoverable(checked)
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: BluetoothService.available
                        iconName: "handshake"
                        title: qsTr("Allow pairing")
                        supportingText: qsTr("Accept pairing requests supported by the official module")
                        enabled: BluetoothService.enabled

                        trailing: StyledSwitch {
                            scale: 0.72
                            checked: BluetoothService.pairable
                            enabled: BluetoothService.enabled && !BluetoothService.busy
                            Accessible.name: qsTr("Bluetooth pairing")
                            onToggled: BluetoothService.setPairable(checked)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.spacing.small
                }
            }
        }
    }

    Dialog {
        id: forgetDialog

        modal: true
        width: Math.min(320, root.width - 48)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        padding: Appearance.spacing.medium
        Material.theme: Material.System
        Material.accent: Appearance.colors.colPrimary

        background: Rectangle {
            radius: Appearance.rounding.veryLarge
            color: Appearance.colors.colSurfaceContainerHigh
        }

        header: Text {
            text: qsTr("Forget Bluetooth device")
            color: Appearance.colors.colOnLayer2
            font.family: Sizes.fontFamily
            font.pixelSize: 18
            font.weight: Font.DemiBold
            leftPadding: Appearance.spacing.medium
            rightPadding: Appearance.spacing.medium
            topPadding: Appearance.spacing.medium
        }

        contentItem: Text {
            text: root.pendingForgetDevice
                ? qsTr("This will delete the pairing information for “") + root.pendingForgetDevice.name + qsTr("”.")
                : ""
            color: Appearance.colors.colOnLayer1
            font.family: Sizes.fontFamily
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }

        footer: RowLayout {
            spacing: Appearance.spacing.small

            Item { Layout.fillWidth: true }
            DialogActionButton {
                text: qsTr("Cancel")
                onClicked: {
                    forgetDialog.close();
                    root.pendingForgetDevice = null;
                }
            }
            DialogActionButton {
                text: qsTr("Forget")
                filled: true
                onClicked: {
                    const target = root.pendingForgetDevice;
                    forgetDialog.close();
                    root.pendingForgetDevice = null;
                    if (target)
                        BluetoothService.forgetDevice(target);
                }
            }
        }
    }

    component DeviceSection: SettingsSection {
        id: deviceSection

        property string sectionTitle: ""
        property var devicesModel: []
        property string category: ""

        title: sectionTitle

        Repeater {
            model: deviceSection.devicesModel

            BluetoothDeviceRow {
                required property var modelData

                Layout.fillWidth: true
                deviceData: modelData
                deviceCategory: deviceSection.category
            }
        }
    }

    component BluetoothDeviceRow: SettingsRow {
        id: deviceRow

        required property var deviceData
        property string deviceCategory: ""

        iconName: root.iconForDevice(deviceData)
        title: deviceData.name
        supportingText: root.deviceSupportingText(deviceData)
        highlighted: deviceData.connected
        enabled: !deviceData.blocked

        trailing: RowLayout {
            spacing: Appearance.spacing.xSmall

            MaterialSymbol {
                visible: deviceRow.deviceData.batteryAvailable
                text: deviceRow.deviceData.batteryLevel > 80
                    ? "battery_full"
                    : deviceRow.deviceData.batteryLevel > 30 ? "battery_4_bar" : "battery_1_bar"
                iconSize: 18
                color: Appearance.colors.colOnLayer1
            }

            DialogActionButton {
                visible: !deviceRow.deviceData.blocked
                enabled: !BluetoothService.busy
                text: deviceRow.deviceCategory === "connected"
                    ? qsTr("Disconnect")
                    : deviceRow.deviceCategory === "paired" ? qsTr("Connect") : qsTr("Pair")
                filled: deviceRow.deviceCategory !== "connected"
                onClicked: {
                    if (deviceRow.deviceCategory === "connected")
                        BluetoothService.disconnectDevice(deviceRow.deviceData);
                    else if (deviceRow.deviceCategory === "paired")
                        BluetoothService.connectDevice(deviceRow.deviceData);
                    else
                        BluetoothService.pairDevice(deviceRow.deviceData);
                }
            }

            ToolButton {
                visible: deviceRow.deviceData.paired
                    || deviceRow.deviceData.bonded
                    || deviceRow.deviceData.trusted
                implicitWidth: 34
                implicitHeight: 34
                enabled: !BluetoothService.busy
                Accessible.name: qsTr("Bluetooth device action")
                onClicked: deviceMenu.open()

                background: Rectangle {
                    radius: Appearance.rounding.full
                    color: parent.down
                        ? Appearance.colors.colLayer3Active
                        : parent.hovered ? Appearance.colors.colLayer3Hover : "transparent"
                }

                contentItem: MaterialSymbol {
                    text: "more_vert"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer2
                }

                Menu {
                    id: deviceMenu

                    Material.theme: Material.System
                    Material.accent: Appearance.colors.colPrimary

                    MenuItem {
                        text: qsTr("Forget device")
                        onTriggered: {
                            root.pendingForgetDevice = deviceRow.deviceData;
                            forgetDialog.open();
                        }
                    }
                }
            }
        }
    }
}
