.pragma library

function getRelativeTime(timestampMs) {
    if (!timestampMs) return qsTr("Just now");

    var now = Date.now();
    var diffSeconds = Math.floor((now - timestampMs) / 1000);

    if (diffSeconds < 60) {
        return qsTr("Just now");
    }

    var diffMinutes = Math.floor(diffSeconds / 60);
    if (diffMinutes < 60) {
        return diffMinutes === 1
            ? qsTr("1 minute ago")
            : qsTr("%1 minutes ago").arg(diffMinutes);
    }

    var diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) {
        return diffHours === 1
            ? qsTr("1 hour ago")
            : qsTr("%1 hours ago").arg(diffHours);
    }

    return qsTr("More than a day ago");
}
