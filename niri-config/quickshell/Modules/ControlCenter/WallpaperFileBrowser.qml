import QtQuick
import qs.Modules.FilePicker

FilePickerWindow {
    id: root

    selectionMode: FilePickerWindow.FilesAndFolders
    acceptFilesOnSingleClick: true
    dialogTitle: qsTr("Choose wallpaper or folder")
    description: qsTr("Choose an image as the wallpaper, or choose a folder as the wallpaper directory")
    windowIconName: "wallpaper"
    emptyStateText: qsTr("No selectable wallpapers in this folder")
    selectionPrompt: qsTr("Choose a wallpaper or folder")
    acceptLabel: qsTr("Apply")
    formatSummary: "JPG · PNG · WebP\nBMP · GIF"

    signal fileSelected(string path)
    signal folderSelected(string path)

    onAccepted: (path, isDirectory) => {
        if (isDirectory)
            root.folderSelected(path);
        else
            root.fileSelected(path);
    }
}
