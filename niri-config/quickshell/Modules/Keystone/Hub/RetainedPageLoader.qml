import QtQuick

Loader {
    id: root

    property bool presented: false
    property bool retained: false

    active: presented || retained
    asynchronous: true
    visible: status === Loader.Ready && (presented || opacity > 0.01)
    opacity: presented && status === Loader.Ready ? 1 : 0

    onLoaded: retained = true

    Behavior on opacity {
        NumberAnimation { duration: 300 }
    }
}
