pragma Singleton

import QtQuick
import Quickshell
import Clavis.I18n 1.0

Singleton {
    id: root

    readonly property var supportedLanguages: [
        ({ code: "en_US", label: "English" })
    ]
    readonly property string language: UiPreferences.language
    property bool ready: false
    property string lastError: ""

    function initialize() {
        const success = I18nManager.setLanguage(root.language);
        root.ready = success;
        root.lastError = success ? "" : I18nManager.lastError;
        if (success) {
            if (Qt.uiLanguage === root.language)
                Qt.uiLanguage = root.language + "_refresh";
            Qt.uiLanguage = root.language;
        }
        return success;
    }

    Component.onCompleted: initialize()

    Connections {
        target: UiPreferences

        function onLanguageChanged() {
            root.initialize();
        }
    }
}
