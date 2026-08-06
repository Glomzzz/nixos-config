.pragma library

function shortWeekdays(language) {
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
}

function compactDate(date, language, locale, fallbackPattern) {
    return date.toLocaleDateString(Qt.locale("en_US"), fallbackPattern);
}

function calendarWeekdays(language) {
    return ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
}

function monthTitle(date, language, locale) {
    return date.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy");
}
