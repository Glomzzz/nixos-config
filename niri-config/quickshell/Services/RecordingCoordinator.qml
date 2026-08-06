pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Clavis 自己的会话始终优先于外部 niri Cast；屏幕捕获语义保持独立。
    readonly property bool ownScreenSessionPresent: RecordingService.isActive
    readonly property bool ownAudioSessionPresent: AudioRecordingService.isActive
    readonly property bool ownSessionPresent: ownScreenSessionPresent
        || ownAudioSessionPresent
    readonly property bool ownRecordingActive: RecordingService.isRecording
        || AudioRecordingService.isRecording
    readonly property bool externalCapturePresent: ScreencastService.anyCastPresent
    readonly property bool externalCaptureActive: ScreencastService.anyCastActive
    readonly property bool capturePresent: ownScreenSessionPresent
        || externalCapturePresent
    readonly property bool captureActive: RecordingService.isRecording
        || externalCaptureActive
    readonly property string source: ownScreenSessionPresent
        ? "clavis-screen"
        : (ownAudioSessionPresent
            ? "clavis-audio"
            : (externalCapturePresent ? "external" : "none"))
    readonly property string state: ownScreenSessionPresent
        ? RecordingService.state
        : (ownAudioSessionPresent
            ? AudioRecordingService.state
            : (externalCaptureActive ? "capturing" : "idle"))
    readonly property var ownScreenStatusTexts: ({
        "selecting": qsTr("Selecting a recording region"),
        "starting": qsTr("Starting screen recording"),
        "recording": qsTr("Recording screen"),
        "finalizing": qsTr("Processing the screen recording")
    })
    readonly property var ownAudioStatusTexts: ({
        "starting": qsTr("Starting audio recording"),
        "recording": qsTr("Recording audio"),
        "stopping": qsTr("Stopping audio recording"),
        "finalizing": qsTr("Finalizing the audio recording")
    })
    readonly property string statusText: ownScreenSessionPresent
        ? (ownScreenStatusTexts[RecordingService.state] || "")
        : (ownAudioSessionPresent
            ? (ownAudioStatusTexts[AudioRecordingService.state] || "")
            : ScreencastService.statusText)
    readonly property bool canStop: RecordingService.isRecording
        || RecordingService.isFinalizing
        || AudioRecordingService.isRecording
}
