import QtQuick
import qs.Common
import "../../Common/functions/WallpaperMath.js" as WallpaperMath

Item {
    id: root

    property string sourcePath: ""
    property int imageFillMode: Image.PreserveAspectCrop
    property bool panoramaEnabled: false
    property real horizontalProgress: 0.5
    property int textureWidth:
        Math.min(Math.max(1, Math.round(width)), 8192)
    property int textureHeight:
        Math.min(Math.max(1, Math.round(height)), 8192)
    property string lastReadySourcePath: ""
    property real lastReadyImageWidth: 0
    property real lastReadyImageHeight: 0

    readonly property bool sourceIsColor:
        root.isColorSource(root.sourcePath)
    readonly property bool ready: root.sourcePath === ""
        || root.sourceIsColor
        || (image.status === Image.Ready
            && root.lastReadySourcePath === root.sourcePath)
    readonly property int imageStatus: image.status
    readonly property real imagePixelWidth:
        Math.max(1, root.lastReadyImageWidth)
    readonly property real imagePixelHeight:
        Math.max(1, root.lastReadyImageHeight)
    readonly property var panoramaGeometry:
        WallpaperMath.panoramaGeometry(
            width, height,
            lastReadyImageWidth, lastReadyImageHeight,
            panoramaEnabled && !sourceIsColor)
    readonly property real wallpaperX:
        panoramaGeometry.active
            ? WallpaperMath.wallpaperPosition(
                panoramaGeometry.overflowX, horizontalProgress)
            : 0

    signal loadFailed(string source)

    clip: true

    function imageUrl(path) {
        return path && path !== "" ? Paths.fileUrl(path) : "";
    }

    function isColorSource(path) {
        return /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/
            .test(String(path || ""));
    }

    function rememberReadyImageSize() {
        if (image.status !== Image.Ready)
            return;
        const sourceWidth = Number(image.sourceSize.width);
        const sourceHeight = Number(image.sourceSize.height);
        const imageWidth = sourceWidth > 0
            ? sourceWidth : Number(image.implicitWidth);
        const imageHeight = sourceHeight > 0
            ? sourceHeight : Number(image.implicitHeight);
        if (isFinite(imageWidth) && imageWidth > 0
                && isFinite(imageHeight) && imageHeight > 0) {
            root.lastReadySourcePath = root.sourcePath;
            root.lastReadyImageWidth = imageWidth;
            root.lastReadyImageHeight = imageHeight;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.sourcePath
        visible: root.sourceIsColor
    }

    Item {
        id: imageCanvas

        x: root.wallpaperX
        y: 0
        width: root.panoramaGeometry.canvasWidth
        height: root.panoramaGeometry.canvasHeight
        visible: root.sourcePath !== "" && !root.sourceIsColor

        Image {
            id: image

            anchors.fill: parent
            source: !root.sourceIsColor
                ? root.imageUrl(root.sourcePath) : ""
            fillMode: root.panoramaGeometry.active
                ? Image.PreserveAspectCrop : root.imageFillMode
            asynchronous: true
            cache: true
            retainWhileLoading: true
            smooth: true
            sourceSize: root.panoramaEnabled
                ? Qt.size(0, root.textureHeight)
                : Qt.size(root.textureWidth, root.textureHeight)

            onStatusChanged: {
                if (status === Image.Ready) {
                    root.rememberReadyImageSize();
                } else if (status === Image.Error
                        && root.sourcePath !== "") {
                    root.loadFailed(root.sourcePath);
                }
            }
        }
    }
}
