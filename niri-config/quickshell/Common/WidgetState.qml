pragma Singleton

import QtQuick

QtObject {
    id: root

    property bool qsOpen: false
    property string qsView: "settings"
    property string qsScreenName: ""

    property bool leftSidebarOpen: false
    property string leftSidebarView: "info"

    onQsOpenChanged: {
        if (!qsOpen)
            qsScreenName = "";
    }

    function closeAllPopups() {
        qsOpen = false;
        leftSidebarOpen = false;
    }
}
