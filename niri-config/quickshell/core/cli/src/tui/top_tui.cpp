#include "top_tui.h"
#include "top_tui_helpers.h"

#include "sysmon/sampler.h"
#include "sysmon/types.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>

#define NCURSES_NOMACROS 1
#include <curses.h>
#include <langinfo.h>
#include <locale.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <chrono>
#include <cmath>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <deque>
#include <functional>
#include <limits>
#include <optional>
#include <utility>
#include <vector>

using namespace Clavis::Sysmon;
using namespace Clavis::TopTuiDetail;

namespace {

using Clock = std::chrono::steady_clock;

volatile sig_atomic_t g_stopRequested = 0;
volatile sig_atomic_t g_resizeRequested = 0;

extern "C" void stopHandler(int)
{
    g_stopRequested = 1;
}

extern "C" void resizeHandler(int)
{
    g_resizeRequested = 1;
}

class SignalGuard {
public:
    SignalGuard()
    {
        install(SIGINT, stopHandler);
        install(SIGTERM, stopHandler);
        install(SIGHUP, stopHandler);
        install(SIGWINCH, resizeHandler);
    }

    ~SignalGuard()
    {
        for (int index = m_count - 1; index >= 0; --index)
            ::sigaction(m_entries.at(index).number, &m_entries.at(index).previous, nullptr);
    }

private:
    struct Entry {
        int number = 0;
        struct sigaction previous {};
    };

    void install(int number, void (*handler)(int))
    {
        struct sigaction action {};
        ::sigemptyset(&action.sa_mask);
        action.sa_handler = handler;
        action.sa_flags = 0;

        Entry entry;
        entry.number = number;
        if (::sigaction(number, &action, &entry.previous) == 0)
            m_entries.at(m_count++) = entry;
    }

    std::array<Entry, 4> m_entries {};
    int m_count = 0;
};

class CursesSession {
public:
    CursesSession()
    {
        ::setlocale(LC_ALL, "");
        if (::initscr() == nullptr)
            return;

        m_active = true;
        ::cbreak();
        ::noecho();
        ::nonl();
        ::intrflush(stdscr, FALSE);
        ::keypad(stdscr, TRUE);
        ::meta(stdscr, TRUE);
        ::mousemask(BUTTON1_CLICKED, nullptr);
        ::mouseinterval(0);
#if defined(NCURSES_VERSION)
        ::set_escdelay(25);
#endif
        m_previousCursor = ::curs_set(0);
    }

    ~CursesSession()
    {
        if (!m_active)
            return;

        ::timeout(-1);
        ::mousemask(0, nullptr);
        ::keypad(stdscr, FALSE);
        ::echo();
        ::nocbreak();
        if (m_previousCursor != ERR)
            ::curs_set(m_previousCursor);
        // ncurses' enter/exit_ca_mode capabilities own the alternate screen.
        ::endwin();
    }

    bool active() const
    {
        return m_active;
    }

    void resize()
    {
        struct winsize size {};
        if (::ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0
            && size.ws_row > 0 && size.ws_col > 0) {
            ::resizeterm(size.ws_row, size.ws_col);
        } else {
            ::resize_term(0, 0);
        }
        ::clearok(stdscr, TRUE);
        ::erase();
    }

private:
    bool m_active = false;
    int m_previousCursor = ERR;
};

struct Rgb {
    int red = 255;
    int green = 255;
    int blue = 255;
};

std::optional<Rgb> parseRgb(const QJsonObject &object, const QString &key)
{
    const QString value = object.value(key).toString();
    if (value.size() != 7 || !value.startsWith(QLatin1Char('#')))
        return std::nullopt;

    bool ok = false;
    const int packed = value.mid(1).toInt(&ok, 16);
    if (!ok)
        return std::nullopt;

    return Rgb{
        (packed >> 16) & 0xff,
        (packed >> 8) & 0xff,
        packed & 0xff,
    };
}

int nearestXtermColor(const Rgb &color)
{
    const auto cubeLevel = [](int component) {
        if (component < 48)
            return 0;
        if (component < 114)
            return 1;
        return std::min(5, (component - 35) / 40);
    };
    const auto cubeValue = [](int level) {
        return level == 0 ? 0 : 55 + level * 40;
    };

    const int redLevel = cubeLevel(color.red);
    const int greenLevel = cubeLevel(color.green);
    const int blueLevel = cubeLevel(color.blue);
    const int cubeIndex = 16 + 36 * redLevel + 6 * greenLevel + blueLevel;
    const int cubeRed = cubeValue(redLevel);
    const int cubeGreen = cubeValue(greenLevel);
    const int cubeBlue = cubeValue(blueLevel);
    const int cubeDistance =
        (color.red - cubeRed) * (color.red - cubeRed)
        + (color.green - cubeGreen) * (color.green - cubeGreen)
        + (color.blue - cubeBlue) * (color.blue - cubeBlue);

    const int average = (color.red + color.green + color.blue) / 3;
    const int grayLevel = std::clamp((average - 8 + 5) / 10, 0, 23);
    const int grayValue = 8 + grayLevel * 10;
    const int grayDistance =
        (color.red - grayValue) * (color.red - grayValue)
        + (color.green - grayValue) * (color.green - grayValue)
        + (color.blue - grayValue) * (color.blue - grayValue);

    return grayDistance < cubeDistance ? 232 + grayLevel : cubeIndex;
}

enum class Tone : int {
    Normal = 1,
    Primary,
    Muted,
    Outline,
    Warning,
    Critical,
    Selected,
    Good,
};

class TerminalTheme {
public:
    TerminalTheme()
    {
        initialize();
    }

    ~TerminalTheme()
    {
        restoreCustomColors();
    }

    attr_t attribute(Tone tone, attr_t extra = A_NORMAL) const
    {
        attr_t result = extra;
        if (m_colorEnabled)
            result |= COLOR_PAIR(static_cast<int>(tone));
        else if (tone == Tone::Selected)
            result |= A_REVERSE;
        else if (tone == Tone::Muted || tone == Tone::Outline)
            result |= A_DIM;
        else if (tone == Tone::Warning || tone == Tone::Critical)
            result |= A_BOLD;
        return result;
    }

    bool colorEnabled() const
    {
        return m_colorEnabled;
    }

private:
    struct SavedColor {
        short index = 0;
        short red = 0;
        short green = 0;
        short blue = 0;
    };

    static Rgb role(const QJsonObject &tokens, const QString &key, const Rgb &fallback)
    {
        return parseRgb(tokens, key).value_or(fallback);
    }

    void initialize()
    {
        if (qEnvironmentVariableIsSet("NO_COLOR") || !::has_colors())
            return;

        ::start_color();
        const int defaultBackground =
            ::use_default_colors() == OK ? -1 : COLOR_BLACK;
        m_colorEnabled = true;

        QJsonObject tokens;
        QFile file(QDir::homePath()
                   + QStringLiteral("/.cache/quickshell-dev-colorscheme/colors.json"));
        if (file.open(QIODevice::ReadOnly)) {
            QJsonParseError error;
            const QJsonDocument document =
                QJsonDocument::fromJson(file.readAll(), &error);
            if (error.error == QJsonParseError::NoError && document.isObject())
                tokens = document.object();
        }

        const Rgb surface = role(tokens, QStringLiteral("surface"), {16, 20, 19});
        const Rgb onSurface =
            role(tokens, QStringLiteral("on_surface"), {231, 235, 233});
        const Rgb primary = role(tokens, QStringLiteral("primary"), {92, 214, 185});
        const Rgb muted =
            role(tokens, QStringLiteral("on_surface_variant"), {177, 188, 184});
        const Rgb outline =
            role(tokens, QStringLiteral("outline_variant"), {76, 88, 84});
        const Rgb warning = role(tokens, QStringLiteral("tertiary"), {255, 196, 92});
        const Rgb critical = role(tokens, QStringLiteral("error"), {255, 180, 171});
        const Rgb selectedBackground =
            role(tokens, QStringLiteral("primary_container"), {0, 81, 68});
        const Rgb selectedForeground =
            role(tokens, QStringLiteral("on_primary_container"), {160, 242, 222});
        const Rgb good = role(tokens, QStringLiteral("secondary"), {177, 204, 196});

        const bool trueColorAdvertised =
            qEnvironmentVariable("COLORTERM").contains(QStringLiteral("truecolor"),
                                                        Qt::CaseInsensitive)
            || qEnvironmentVariable("COLORTERM").contains(QStringLiteral("24bit"),
                                                           Qt::CaseInsensitive);

        if (trueColorAdvertised && COLORS >= 26 && ::can_change_color()) {
            const std::array<Rgb, 10> colors{
                surface,
                onSurface,
                primary,
                muted,
                outline,
                warning,
                critical,
                selectedBackground,
                selectedForeground,
                good,
            };
            bool exact = true;
            for (int index = 0; index < static_cast<int>(colors.size()); ++index) {
                if (!setCustomColor(static_cast<short>(16 + index), colors.at(index))) {
                    exact = false;
                    break;
                }
            }
            if (exact) {
                initializePairs(
                    17, defaultBackground, 18, 19, 20, 21, 22, 24, 23, 25);
                return;
            }
            restoreCustomColors();
        }

        if (COLORS >= 256) {
            initializePairs(nearestXtermColor(onSurface),
                            defaultBackground,
                            nearestXtermColor(primary),
                            nearestXtermColor(muted),
                            nearestXtermColor(outline),
                            nearestXtermColor(warning),
                            nearestXtermColor(critical),
                            nearestXtermColor(selectedForeground),
                            nearestXtermColor(selectedBackground),
                            nearestXtermColor(good));
            return;
        }

        initializePairs(COLOR_WHITE,
                        defaultBackground,
                        COLOR_CYAN,
                        COLOR_WHITE,
                        COLOR_BLUE,
                        COLOR_YELLOW,
                        COLOR_RED,
                        COLOR_BLACK,
                        COLOR_CYAN,
                        COLOR_GREEN);
    }

    bool setCustomColor(short index, const Rgb &color)
    {
        SavedColor saved;
        saved.index = index;
        if (::color_content(index, &saved.red, &saved.green, &saved.blue) == ERR)
            return false;

        const auto scale = [](int component) {
            return static_cast<short>(std::lround(component * 1000.0 / 255.0));
        };
        if (::init_color(index, scale(color.red), scale(color.green), scale(color.blue))
            == ERR) {
            return false;
        }
        m_savedColors.push_back(saved);
        return true;
    }

    void restoreCustomColors()
    {
        for (auto iterator = m_savedColors.rbegin();
             iterator != m_savedColors.rend(); ++iterator) {
            ::init_color(iterator->index,
                         iterator->red,
                         iterator->green,
                         iterator->blue);
        }
        m_savedColors.clear();
    }

    void initializePairs(int normalForeground,
                         int background,
                         int primary,
                         int muted,
                         int outline,
                         int warning,
                         int critical,
                         int selectedForeground,
                         int selectedBackground,
                         int good)
    {
        ::init_pair(static_cast<short>(Tone::Normal),
                    static_cast<short>(normalForeground),
                    static_cast<short>(background));
        ::init_pair(static_cast<short>(Tone::Primary),
                    static_cast<short>(primary),
                    static_cast<short>(background));
        ::init_pair(static_cast<short>(Tone::Muted),
                    static_cast<short>(muted),
                    static_cast<short>(background));
        ::init_pair(static_cast<short>(Tone::Outline),
                    static_cast<short>(outline),
                    static_cast<short>(background));
        ::init_pair(static_cast<short>(Tone::Warning),
                    static_cast<short>(warning),
                    static_cast<short>(background));
        ::init_pair(static_cast<short>(Tone::Critical),
                    static_cast<short>(critical),
                    static_cast<short>(background));
        ::init_pair(static_cast<short>(Tone::Selected),
                    static_cast<short>(selectedForeground),
                    static_cast<short>(selectedBackground));
        ::init_pair(static_cast<short>(Tone::Good),
                    static_cast<short>(good),
                    static_cast<short>(background));
    }

    bool m_colorEnabled = false;
    std::vector<SavedColor> m_savedColors;
};

int displayWidth(const QString &text)
{
    int width = 0;
    for (const wchar_t character : text.toStdWString()) {
        const int characterWidth = ::wcwidth(character);
        width += characterWidth > 0 ? characterWidth : 1;
    }
    return width;
}

QString leftByWidth(const QString &text, int maximumWidth)
{
    if (maximumWidth <= 0)
        return {};

    std::wstring output;
    int width = 0;
    for (const wchar_t character : text.toStdWString()) {
        const int characterWidth = std::max(1, ::wcwidth(character));
        if (width + characterWidth > maximumWidth)
            break;
        output.push_back(character);
        width += characterWidth;
    }
    return QString::fromStdWString(output);
}

QString rightByWidth(const QString &text, int maximumWidth)
{
    if (maximumWidth <= 0)
        return {};

    std::wstring reversed;
    int width = 0;
    const std::wstring source = text.toStdWString();
    for (auto iterator = source.rbegin(); iterator != source.rend(); ++iterator) {
        const int characterWidth = std::max(1, ::wcwidth(*iterator));
        if (width + characterWidth > maximumWidth)
            break;
        reversed.push_back(*iterator);
        width += characterWidth;
    }
    std::reverse(reversed.begin(), reversed.end());
    return QString::fromStdWString(reversed);
}

QString fitText(const QString &text, int width, bool alignRight = false)
{
    if (width <= 0)
        return {};

    QString result = leftByWidth(text, width);
    const int padding = std::max(0, width - displayWidth(result));
    return alignRight ? QString(padding, QLatin1Char(' ')) + result
                      : result + QString(padding, QLatin1Char(' '));
}

QString terminalSafeText(QString text, bool asciiOnly)
{
    // Process names and command lines are untrusted display data. Keep their
    // visible text, but never pass terminal control characters to ncurses.
    for (qsizetype index = 0; index < text.size(); ++index) {
        const ushort value = text.at(index).unicode();
        if (value < 0x20 || value == 0x7f
            || (value >= 0x80 && value <= 0x9f)) {
            text[index] = QLatin1Char(' ');
        }
    }

    if (asciiOnly) {
        for (qsizetype index = 0; index < text.size(); ++index) {
            const ushort value = text.at(index).unicode();
            if (value <= 0x7e)
                continue;
            if (value == 0x00b7)
                text[index] = QLatin1Char('|');
            else if (value == 0x00b0)
                text[index] = QLatin1Char(' ');
            else
                text[index] = QLatin1Char('?');
        }
    }
    return text;
}

void putText(int row,
             int column,
             const QString &text,
             int maximumWidth,
             attr_t attributes,
             bool asciiOnly)
{
    if (row < 0 || row >= LINES || column < 0 || column >= COLS
        || maximumWidth <= 0) {
        return;
    }

    const int available = std::min(maximumWidth, COLS - column);
    const std::wstring output =
        leftByWidth(terminalSafeText(text, asciiOnly), available)
            .toStdWString();
    if (output.empty())
        return;

    ::attrset(static_cast<int>(attributes));
    ::mvaddnwstr(row,
                 column,
                 output.c_str(),
                 static_cast<int>(output.size()));
}

QString formatBytes(long double bytes)
{
    static const std::array<const char *, 6> units{
        "B", "KiB", "MiB", "GiB", "TiB", "PiB",
    };
    long double value = std::max(0.0L, bytes);
    int unit = 0;
    while (value >= 1024.0 && unit + 1 < static_cast<int>(units.size())) {
        value /= 1024.0;
        ++unit;
    }
    const int precision = unit == 0 ? 0 : (value < 10.0 ? 1 : 0);
    return QStringLiteral("%1 %2")
        .arg(static_cast<double>(value), 0, 'f', precision)
        .arg(QString::fromLatin1(units.at(unit)));
}

QString formatRate(const OptionalNumber &rate)
{
    return rate ? formatBytes(*rate) + QStringLiteral("/s")
                : QStringLiteral("--");
}

QString formatPercent(const OptionalNumber &percent, int precision = 1)
{
    return percent ? QStringLiteral("%1%").arg(*percent, 0, 'f', precision)
                   : QStringLiteral("--");
}

QString formatDuration(qint64 seconds)
{
    seconds = std::max<qint64>(0, seconds);
    const qint64 days = seconds / 86400;
    const qint64 hours = (seconds % 86400) / 3600;
    const qint64 minutes = (seconds % 3600) / 60;
    if (days > 0)
        return QStringLiteral("%1d %2h").arg(days).arg(hours);
    if (hours > 0)
        return QStringLiteral("%1h %2m").arg(hours).arg(minutes);
    return QStringLiteral("%1m %2s").arg(minutes).arg(seconds % 60);
}

QString optionalNumber(const OptionalNumber &number,
                       const QString &suffix,
                       int precision = 1)
{
    return number ? QStringLiteral("%1%2").arg(*number, 0, 'f', precision).arg(suffix)
                  : QStringLiteral("--");
}

bool unicodeAvailable(bool forceAscii)
{
    if (forceAscii)
        return false;
    const QByteArray codeset = QByteArray(::nl_langinfo(CODESET)).toLower();
    return codeset.contains("utf-8") || codeset.contains("utf8");
}

} // namespace

struct TopTui::Impl {
    enum class Panel {
        System,
        Compute,
        Memory,
        Network,
        Disk,
        Processes,
        Count,
    };

    enum class Modal {
        None,
        Help,
        Filter,
        Details,
        SignalChoice,
        SignalKillConfirm,
    };

    enum class SortField {
        Cpu,
        Memory,
        Pid,
        Name,
    };

    struct Rect {
        int x = 0;
        int y = 0;
        int width = 0;
        int height = 0;
    };

    struct ProcessRow {
        ProcessInfo process;
        int depth = 0;
        bool cycle = false;
        bool depthLimited = false;
    };

    explicit Impl(Sampler &sampler, const Options &options)
        : sampler(sampler)
        , options(options)
    {
    }

    int run()
    {
        g_stopRequested = 0;
        g_resizeRequested = 0;

        CursesSession terminal;
        if (!terminal.active()) {
            error = QStringLiteral("Unable to initialize ncurses for this terminal.");
            return 1;
        }

        SignalGuard signalGuard;
        TerminalTheme terminalTheme;
        theme = &terminalTheme;
        unicode = unicodeAvailable(options.forceAscii);
        queryTerminalSize();

        statusMessage = QStringLiteral("Collecting the first sample...");
        statusTone = Tone::Muted;
        statusUntil = Clock::now() + std::chrono::seconds(10);
        draw();
        ::refresh();

        collectSnapshot();
        nextSample = Clock::now()
            + std::chrono::milliseconds(options.refreshIntervalMs);

        while (!quit && !g_stopRequested) {
            if (g_resizeRequested) {
                g_resizeRequested = 0;
                terminal.resize();
                queryTerminalSize();
            }

            const auto now = Clock::now();
            if (forceRefresh || (!paused && now >= nextSample)) {
                forceRefresh = false;
                collectSnapshot();
                nextSample = Clock::now()
                    + std::chrono::milliseconds(options.refreshIntervalMs);
            }

            draw();
            ::refresh();

            int waitMs = 1000;
            if (!paused) {
                const auto remaining =
                    std::chrono::duration_cast<std::chrono::milliseconds>(
                        nextSample - Clock::now())
                        .count();
                waitMs = static_cast<int>(std::clamp<qint64>(remaining, 1, 1000));
            }
            ::timeout(waitMs);

            wint_t input = 0;
            const int inputType = ::get_wch(&input);
            if (inputType == KEY_CODE_YES && input == KEY_RESIZE) {
                // resizeterm() queues one KEY_RESIZE. Calling it again here
                // would continuously requeue resize events.
                g_resizeRequested = 0;
                queryTerminalSize();
                ::clearok(stdscr, TRUE);
                ::erase();
                continue;
            }
            if (inputType == OK || inputType == KEY_CODE_YES)
                handleInput(input, inputType == KEY_CODE_YES);
        }

        theme = nullptr;
        return 0;
    }

    void queryTerminalSize()
    {
        getmaxyx(stdscr, rows, columns);
        processPageRows = std::max(1, processPageRows);
    }

    void collectSnapshot()
    {
        try {
            snapshot = sampler.sample(allModules());
            hasSnapshot = true;
            appendHistory(cpuHistory, snapshot.cpu.usagePercent);
            QSet<QString> activeGpuKeys;
            for (int index = 0; index < snapshot.gpus.size(); ++index) {
                const GpuInfo &gpu = snapshot.gpus.at(index);
                const QString key = gpuKey(gpu, index);
                activeGpuKeys.insert(key);
                appendHistory(gpuHistories[key], gpu.utilizationPercent);
            }
            for (auto iterator = gpuHistories.begin();
                 iterator != gpuHistories.end();) {
                if (!activeGpuKeys.contains(iterator.key()))
                    iterator = gpuHistories.erase(iterator);
                else
                    ++iterator;
            }
            if (!computeGraphGpuKey.isEmpty()
                && !activeGpuKeys.contains(computeGraphGpuKey)) {
                computeGraphGpuKey.clear();
            }
            appendHistory(downloadHistory, snapshot.network.downloadBytesPerSecond);
            appendHistory(uploadHistory, snapshot.network.uploadBytesPerSecond);
            rebuildProcessView();

            if (statusMessage == QStringLiteral("Collecting the first sample...")) {
                statusMessage.clear();
                statusUntil = {};
            }
        } catch (const std::exception &exception) {
            setStatus(
                QStringLiteral("Sampling failed: %1")
                    .arg(QString::fromLocal8Bit(exception.what())),
                Tone::Critical,
                5);
        } catch (...) {
            setStatus(QStringLiteral("Sampling failed: unknown collector error"),
                      Tone::Critical,
                      5);
        }
    }

    static void appendHistory(std::deque<double> &history,
                              const OptionalNumber &value)
    {
        if (!value || !std::isfinite(*value))
            return;
        history.push_back(std::max(0.0, *value));
        while (history.size() > 120)
            history.pop_front();
    }

    void handleInput(wint_t input, bool keyCode)
    {
        if (modal != Modal::None) {
            handleModalInput(input, keyCode);
            return;
        }

        if (keyCode) {
            switch (input) {
            case KEY_UP:
                moveSelection(-1);
                return;
            case KEY_DOWN:
                moveSelection(1);
                return;
            case KEY_PPAGE:
                changeFocusedPage(-1);
                return;
            case KEY_NPAGE:
                changeFocusedPage(1);
                return;
            case KEY_BTAB:
                changePanel(-1);
                return;
            case KEY_ENTER:
                openDetails();
                return;
            case KEY_MOUSE:
                handleMouse();
                return;
            default:
                return;
            }
        }

        switch (input) {
        case L'q':
            quit = true;
            break;
        case 27:
            break;
        case L'?':
            modal = Modal::Help;
            break;
        case L'j':
            moveSelection(1);
            break;
        case L'k':
            moveSelection(-1);
            break;
        case L'\t':
            changePanel(1);
            break;
        case L'/':
        case L'f':
            beginFilter();
            break;
        case L's':
            cycleSort();
            break;
        case L't':
            treeMode = !treeMode;
            rebuildProcessView();
            setStatus(treeMode ? QStringLiteral("Process tree enabled")
                               : QStringLiteral("Flat process list enabled"),
                      Tone::Primary);
            break;
        case L'p':
        case L' ':
            paused = !paused;
            if (!paused) {
                forceRefresh = true;
                setStatus(QStringLiteral("Sampling resumed"), Tone::Good);
            } else {
                setStatus(QStringLiteral("Sampling paused"), Tone::Warning);
            }
            break;
        case L'r':
            forceRefresh = true;
            setStatus(QStringLiteral("Refreshing..."), Tone::Muted, 1);
            break;
        case L'g':
            cycleComputeGraph();
            break;
        case L'[':
            changeCorePage(-1);
            break;
        case L']':
            changeCorePage(1);
            break;
        case L'-':
            adjustRefreshInterval(-250);
            break;
        case L'+':
            adjustRefreshInterval(250);
            break;
        case L'\n':
        case L'\r':
            openDetails();
            break;
        case L'K':
            beginSignal();
            break;
        default:
            break;
        }
    }

    void handleModalInput(wint_t input, bool keyCode)
    {
        if (modal == Modal::Filter) {
            if (keyCode && input == KEY_BACKSPACE) {
                removeLastCodepoint(filterDraft);
                processFilter = filterDraft;
                rebuildProcessView();
                return;
            }
            if (keyCode && input == KEY_ENTER) {
                modal = Modal::None;
                ::curs_set(0);
                setStatus(processFilter.isEmpty()
                              ? QStringLiteral("Process filter cleared")
                              : QStringLiteral("Filter: %1").arg(processFilter),
                          Tone::Primary);
                return;
            }
            if (keyCode)
                return;

            if (input == 27) {
                processFilter = filterBeforeEdit;
                filterDraft = processFilter;
                rebuildProcessView();
                modal = Modal::None;
                ::curs_set(0);
                return;
            }
            if (input == L'\n' || input == L'\r') {
                modal = Modal::None;
                ::curs_set(0);
                setStatus(processFilter.isEmpty()
                              ? QStringLiteral("Process filter cleared")
                              : QStringLiteral("Filter: %1").arg(processFilter),
                          Tone::Primary);
                return;
            }
            if (input == 8 || input == 127) {
                removeLastCodepoint(filterDraft);
                processFilter = filterDraft;
                rebuildProcessView();
                return;
            }
            if (input == 21) {
                filterDraft.clear();
                processFilter.clear();
                rebuildProcessView();
                return;
            }
            if (::iswprint(input)) {
                const char32_t character = static_cast<char32_t>(input);
                filterDraft += QString::fromUcs4(&character, 1);
                processFilter = filterDraft;
                rebuildProcessView();
            }
            return;
        }

        if (keyCode && input == KEY_ENTER)
            input = L'\n';
        if (keyCode)
            return;

        if (input == L'q') {
            quit = true;
            modal = Modal::None;
            return;
        }

        if (modal == Modal::SignalChoice) {
            if (input == 27) {
                modal = Modal::None;
            } else if (input == L'\n' || input == L'\r' || input == L't') {
                sendSelectedSignal(SIGTERM);
            } else if (input == L'K') {
                modal = Modal::SignalKillConfirm;
            }
            return;
        }

        if (modal == Modal::SignalKillConfirm) {
            if (input == 27) {
                modal = Modal::None;
            } else if (input == L'K') {
                sendSelectedSignal(SIGKILL);
            }
            return;
        }

        if (input == 27 || input == L'\n' || input == L'\r'
            || (modal == Modal::Help && input == L'?')) {
            modal = Modal::None;
        }
    }

    static void removeLastCodepoint(QString &text)
    {
        if (text.isEmpty())
            return;
        int count = 1;
        if (text.size() >= 2 && text.at(text.size() - 1).isLowSurrogate()
            && text.at(text.size() - 2).isHighSurrogate()) {
            count = 2;
        }
        text.chop(count);
    }

    void beginFilter()
    {
        filterBeforeEdit = processFilter;
        filterDraft = processFilter;
        modal = Modal::Filter;
        ::curs_set(1);
    }

    void openDetails()
    {
        const ProcessInfo *process = selectedProcess();
        if (!process) {
            setStatus(QStringLiteral("No process is selected"), Tone::Warning);
            return;
        }
        modalProcess = *process;
        modal = Modal::Details;
    }

    void beginSignal()
    {
        const ProcessInfo *process = selectedProcess();
        if (!process) {
            setStatus(QStringLiteral("No process is selected"), Tone::Warning);
            return;
        }
        signalPid = process->pid;
        signalName = process->name;
        signalStartTimeMs = process->startTimeMs;
        signalStartTicks = process->processStartTicks;
        modal = Modal::SignalChoice;
    }

    void sendSelectedSignal(int signal)
    {
        if (signalPid <= 1 || signalPid == static_cast<qint64>(::getpid())) {
            setStatus(
                QStringLiteral("Refusing to signal protected PID %1").arg(signalPid),
                Tone::Critical,
                6);
            modal = Modal::None;
            return;
        }

        Snapshot verification;
        try {
            // Confirmation can remain open indefinitely. Re-read /proc now so
            // a PID that exited and was reused cannot receive the signal.
            verification = sampler.sample(
                ModuleSet{QStringLiteral("processes")});
        } catch (...) {
            setStatus(
                QStringLiteral("Could not revalidate the selected process"),
                Tone::Critical,
                6);
            modal = Modal::None;
            return;
        }

        const ProcessInfo *current = nullptr;
        for (const ProcessInfo &process :
             std::as_const(verification.processes)) {
            if (process.pid == signalPid) {
                current = &process;
                break;
            }
        }
        if (!current) {
            setStatus(
                QStringLiteral("PID %1 already exited (ESRCH)").arg(signalPid),
                Tone::Warning,
                6);
            modal = Modal::None;
            forceRefresh = true;
            return;
        }
        const bool identityChanged =
            signalStartTicks > 0 && current->processStartTicks > 0
            ? signalStartTicks != current->processStartTicks
            : (signalStartTimeMs > 0 && current->startTimeMs > 0
               && signalStartTimeMs != current->startTimeMs);
        if (identityChanged) {
            setStatus(
                QStringLiteral("PID %1 was reused; signal refused").arg(signalPid),
                Tone::Critical,
                6);
            modal = Modal::None;
            forceRefresh = true;
            return;
        }

        errno = 0;
        if (::kill(static_cast<pid_t>(signalPid), signal) == 0) {
            setStatus(
                QStringLiteral("Sent %1 to %2 (%3)")
                    .arg(signal == SIGTERM ? QStringLiteral("SIGTERM")
                                           : QStringLiteral("SIGKILL"),
                         signalName)
                    .arg(signalPid),
                signal == SIGTERM ? Tone::Warning : Tone::Critical,
                5);
            forceRefresh = true;
        } else if (errno == EPERM) {
            setStatus(
                QStringLiteral("Permission denied for PID %1 (EPERM)").arg(signalPid),
                Tone::Critical,
                6);
        } else if (errno == ESRCH) {
            setStatus(
                QStringLiteral("PID %1 already exited (ESRCH)").arg(signalPid),
                Tone::Warning,
                6);
            forceRefresh = true;
        } else {
            setStatus(
                QStringLiteral("Signal failed for PID %1: %2")
                    .arg(signalPid)
                    .arg(QString::fromLocal8Bit(std::strerror(errno))),
                Tone::Critical,
                6);
        }
        modal = Modal::None;
    }

    void changePanel(int direction)
    {
        const int count = static_cast<int>(Panel::Count);
        int value = static_cast<int>(focusedPanel);
        value = (value + direction + count) % count;
        focusedPanel = static_cast<Panel>(value);
    }

    void cycleSort()
    {
        switch (sortField) {
        case SortField::Cpu:
            sortField = SortField::Memory;
            break;
        case SortField::Memory:
            sortField = SortField::Pid;
            break;
        case SortField::Pid:
            sortField = SortField::Name;
            break;
        case SortField::Name:
            sortField = SortField::Cpu;
            break;
        }
        rebuildProcessView();
        setStatus(QStringLiteral("Process sort: %1").arg(sortName()), Tone::Primary);
    }

    QString sortName() const
    {
        switch (sortField) {
        case SortField::Cpu:
            return QStringLiteral("CPU");
        case SortField::Memory:
            return QStringLiteral("memory");
        case SortField::Pid:
            return QStringLiteral("PID");
        case SortField::Name:
            return QStringLiteral("name");
        }
        return {};
    }

    QString panelName(Panel panel) const
    {
        switch (panel) {
        case Panel::System:
            return QStringLiteral("System");
        case Panel::Compute:
            return QStringLiteral("Compute");
        case Panel::Memory:
            return QStringLiteral("Memory");
        case Panel::Network:
            return QStringLiteral("Network");
        case Panel::Disk:
            return QStringLiteral("Disk");
        case Panel::Processes:
            return QStringLiteral("Processes");
        case Panel::Count:
            break;
        }
        return {};
    }

    bool processLess(const ProcessInfo &left, const ProcessInfo &right) const
    {
        switch (sortField) {
        case SortField::Cpu: {
            const double leftCpu = left.cpuUsagePercent.value_or(-1.0);
            const double rightCpu = right.cpuUsagePercent.value_or(-1.0);
            if (leftCpu != rightCpu)
                return leftCpu > rightCpu;
            break;
        }
        case SortField::Memory:
            if (left.memoryBytes != right.memoryBytes)
                return left.memoryBytes > right.memoryBytes;
            break;
        case SortField::Pid:
            if (left.pid != right.pid)
                return left.pid < right.pid;
            break;
        case SortField::Name: {
            const int comparison =
                QString::compare(left.name, right.name, Qt::CaseInsensitive);
            if (comparison != 0)
                return comparison < 0;
            break;
        }
        }
        return left.pid < right.pid;
    }

    void rebuildProcessView()
    {
        const qint64 previousPid = selectedPid;
        const int previousIndex = selectedIndex;

        QVector<ProcessInfo> filtered;
        filtered.reserve(snapshot.processes.size());
        for (const ProcessInfo &process : std::as_const(snapshot.processes)) {
            if (!processFilter.isEmpty()) {
                const QString pid = QString::number(process.pid);
                const bool matches =
                    process.name.contains(processFilter, Qt::CaseInsensitive)
                    || process.command.contains(processFilter, Qt::CaseInsensitive)
                    || process.user.contains(processFilter, Qt::CaseInsensitive)
                    || pid.contains(processFilter, Qt::CaseInsensitive);
                if (!matches)
                    continue;
            }
            filtered.push_back(process);
        }

        processRows.clear();
        if (!treeMode) {
            std::sort(filtered.begin(),
                      filtered.end(),
                      [this](const ProcessInfo &left, const ProcessInfo &right) {
                          return processLess(left, right);
                      });
            processRows.reserve(filtered.size());
            for (const ProcessInfo &process : std::as_const(filtered))
                processRows.push_back({process, 0, false, false});
        } else {
            buildProcessTree(filtered);
        }

        if (processRows.isEmpty()) {
            selectedIndex = 0;
            selectedPid = 0;
            scrollOffset = 0;
            return;
        }

        std::vector<long long> orderedPids;
        orderedPids.reserve(processRows.size());
        for (const ProcessRow &row : std::as_const(processRows))
            orderedPids.push_back(row.process.pid);
        selectedIndex =
            resolveProcessSelection(processSelectionExplicit,
                                    previousPid,
                                    previousIndex,
                                    orderedPids);
        selectedPid = processRows.at(selectedIndex).process.pid;
        ensureSelectionVisible();
    }

    void buildProcessTree(const QVector<ProcessInfo> &processes)
    {
        QHash<qint64, ProcessInfo> byPid;
        QHash<qint64, QVector<qint64>> children;
        QVector<qint64> roots;
        byPid.reserve(processes.size());

        for (const ProcessInfo &process : processes) {
            if (process.pid > 0)
                byPid.insert(process.pid, process);
        }
        for (const ProcessInfo &process : processes) {
            if (process.pid <= 0)
                continue;
            if (process.ppid <= 0 || process.ppid == process.pid
                || !byPid.contains(process.ppid)) {
                roots.push_back(process.pid);
            } else {
                children[process.ppid].push_back(process.pid);
            }
        }

        const auto idLess = [this, &byPid](qint64 left, qint64 right) {
            return processLess(byPid.value(left), byPid.value(right));
        };
        std::sort(roots.begin(), roots.end(), idLess);
        for (auto iterator = children.begin(); iterator != children.end(); ++iterator)
            std::sort(iterator.value().begin(), iterator.value().end(), idLess);

        QSet<qint64> visited;
        QSet<qint64> active;
        QHash<qint64, int> rowByPid;

        std::function<void(qint64, int)> append =
            [&](qint64 pid, int depth) {
                if (active.contains(pid)) {
                    const auto row = rowByPid.constFind(pid);
                    if (row != rowByPid.constEnd())
                        processRows[(*row)].cycle = true;
                    return;
                }
                if (visited.contains(pid) || !byPid.contains(pid))
                    return;

                visited.insert(pid);
                active.insert(pid);
                const int rowIndex = static_cast<int>(processRows.size());
                rowByPid.insert(pid, rowIndex);
                processRows.push_back({byPid.value(pid), depth, false, false});

                const QVector<qint64> processChildren = children.value(pid);
                if (depth >= 63 && !processChildren.isEmpty()) {
                    processRows[rowIndex].depthLimited = true;
                } else {
                    for (qint64 child : processChildren)
                        append(child, depth + 1);
                }
                active.remove(pid);
            };

        for (qint64 root : std::as_const(roots))
            append(root, 0);

        QVector<qint64> unresolved;
        unresolved.reserve(byPid.size());
        for (auto iterator = byPid.constBegin(); iterator != byPid.constEnd(); ++iterator) {
            if (!visited.contains(iterator.key()))
                unresolved.push_back(iterator.key());
        }
        std::sort(unresolved.begin(), unresolved.end(), idLess);
        for (qint64 pid : std::as_const(unresolved))
            append(pid, 0);
    }

    void moveSelection(int delta)
    {
        if (processRows.isEmpty())
            return;
        processSelectionExplicit = true;
        selectedIndex =
            std::clamp(selectedIndex + delta,
                       0,
                       static_cast<int>(processRows.size()) - 1);
        selectedPid = processRows.at(selectedIndex).process.pid;
        focusedPanel = Panel::Processes;
        ensureSelectionVisible();
    }

    void ensureSelectionVisible()
    {
        if (selectedIndex < scrollOffset)
            scrollOffset = selectedIndex;
        if (selectedIndex >= scrollOffset + processPageRows)
            scrollOffset = selectedIndex - processPageRows + 1;
        const int maximumOffset =
            std::max(0,
                     static_cast<int>(processRows.size())
                         - std::max(1, processPageRows));
        scrollOffset = std::clamp(scrollOffset, 0, maximumOffset);
    }

    const ProcessInfo *selectedProcess() const
    {
        if (selectedIndex < 0 || selectedIndex >= processRows.size())
            return nullptr;
        return &processRows.at(selectedIndex).process;
    }

    void setStatus(const QString &message,
                   Tone tone,
                   int seconds = 3)
    {
        statusMessage = message;
        statusTone = tone;
        statusUntil = Clock::now() + std::chrono::seconds(seconds);
    }

    Sampler &sampler;
    Options options;
    QString error;
    TerminalTheme *theme = nullptr;
    Snapshot snapshot;
    bool hasSnapshot = false;
    bool unicode = true;
    bool quit = false;
    bool paused = false;
    bool forceRefresh = false;
    bool treeMode = false;
    bool processSelectionExplicit = false;
    int rows = 0;
    int columns = 0;
    int refreshMinusColumn = -1;
    int refreshPlusColumn = -1;
    Clock::time_point nextSample {};

    Panel focusedPanel = Panel::Processes;
    Modal modal = Modal::None;
    SortField sortField = SortField::Cpu;
    QVector<ProcessRow> processRows;
    QString processFilter;
    QString filterDraft;
    QString filterBeforeEdit;
    int selectedIndex = 0;
    qint64 selectedPid = 0;
    int scrollOffset = 0;
    int processPageRows = 1;
    int corePage = 0;
    int corePageCount = 1;
    int diskPage = 0;
    int diskPageCount = 1;
    QString computeGraphGpuKey;

    ProcessInfo modalProcess;
    qint64 signalPid = 0;
    QString signalName;
    qint64 signalStartTimeMs = 0;
    quint64 signalStartTicks = 0;

    std::deque<double> cpuHistory;
    QHash<QString, std::deque<double>> gpuHistories;
    std::deque<double> downloadHistory;
    std::deque<double> uploadHistory;

    QString statusMessage;
    Tone statusTone = Tone::Normal;
    Clock::time_point statusUntil {};

    void draw();
    void drawHeader();
    void drawFooter();
    void drawTooSmall();
    void drawWide(const Rect &content);
    void drawMedium(const Rect &content);
    void drawCompact(const Rect &content);
    void drawOverview(const Rect &rect);
    void drawPanelFor(Panel panel, const Rect &rect);
    void drawResourcePane(const Rect &rect);
    void drawSystem(const Rect &rect);
    void drawCompute(const Rect &rect);
    void drawMemory(const Rect &rect);
    void drawNetwork(const Rect &rect);
    void drawDisk(const Rect &rect);
    void drawResources(const Rect &rect);
    void drawProcesses(const Rect &rect);
    void drawModal();
    void drawHelpModal();
    void drawFilterModal();
    void drawDetailsModal();
    void drawSignalModal(bool killConfirmation);
    void drawBox(const Rect &rect, const QString &title, bool focused);
    void clearInside(const Rect &rect, Tone tone = Tone::Normal);
    void writeInside(const Rect &rect,
                     int line,
                     const QString &text,
                     Tone tone = Tone::Normal,
                     attr_t extra = A_NORMAL,
                     bool fill = false);
    void writeAtInside(const Rect &rect,
                       int line,
                       int column,
                       const QString &text,
                       Tone tone = Tone::Normal,
                       attr_t extra = A_NORMAL);
    void drawHistoryGraph(const Rect &plot,
                          const std::deque<double> &history,
                          double fixedMaximum,
                          Tone tone,
                          bool invert = false,
                          bool peakBuckets = false);
    void drawLineHistoryGraph(const Rect &plot,
                              const std::deque<double> &history,
                              double maximum,
                              Tone tone);
    void drawSplitHistoryGraph(const Rect &plot);
    CoreGridLayout drawCoreGrid(const Rect &plot,
                                const QVector<int> &ids,
                                const QVector<OptionalNumber> &values);
    void drawMetricRow(const Rect &rect,
                       int line,
                       const QString &label,
                       const OptionalNumber &percent,
                       const QString &detail,
                       int labelWidth,
                       int detailWidth,
                       Tone meterTone,
                       Tone valueTone = Tone::Normal);
    QString gpuKey(const GpuInfo &gpu, int index) const;
    QVector<QString> graphGpuKeys() const;
    const GpuInfo *gpuForKey(const QString &key) const;
    void cycleComputeGraph();
    void changeFocusedPage(int direction);
    void changeCorePage(int direction);
    void changeDiskPage(int direction);
    void adjustRefreshInterval(int deltaMs);
    void handleMouse();
    QStringList distroMark(const QString &distroId) const;
    QString meter(const OptionalNumber &percent, int width) const;
    QString sparkline(const std::deque<double> &history,
                      int width,
                      double fixedMaximum = 0.0) const;
    QString processLine(const ProcessRow &row, int width) const;
};

void TopTui::Impl::draw()
{
    if (!theme)
        return;

    ::attrset(static_cast<int>(theme->attribute(Tone::Normal)));
    ::bkgdset(static_cast<chtype>(' ') | theme->attribute(Tone::Normal));
    ::erase();
    drawHeader();
    drawFooter();

    if (columns < 54 || rows < 16) {
        drawTooSmall();
    } else {
        const Rect content{0, 1, columns, rows - 2};
        if (columns >= 150 && content.height >= 38)
            drawWide(content);
        else if (columns >= 96 && content.height >= 26)
            drawMedium(content);
        else
            drawCompact(content);
    }

    if (modal != Modal::None)
        drawModal();
    if (modal != Modal::Filter)
        ::curs_set(0);
}

void TopTui::Impl::adjustRefreshInterval(int deltaMs)
{
    const int previous = options.refreshIntervalMs;
    options.refreshIntervalMs =
        adjustedRefreshInterval(previous, deltaMs);
    if (options.refreshIntervalMs == previous) {
        setStatus(
            QStringLiteral("Refresh interval limit: %1 ms")
                .arg(options.refreshIntervalMs),
            Tone::Muted);
        return;
    }

    if (!paused) {
        nextSample =
            Clock::now()
            + std::chrono::milliseconds(options.refreshIntervalMs);
    }
    setStatus(
        QStringLiteral("Refresh interval: %1 ms")
            .arg(options.refreshIntervalMs),
        Tone::Primary);
}

void TopTui::Impl::handleMouse()
{
    MEVENT event{};
    if (::getmouse(&event) != OK
        || !(event.bstate & BUTTON1_CLICKED)
        || event.y != 0) {
        return;
    }

    if (event.x == refreshMinusColumn)
        adjustRefreshInterval(-250);
    else if (event.x == refreshPlusColumn)
        adjustRefreshInterval(250);
}

void TopTui::Impl::drawHeader()
{
    if (rows <= 0 || columns <= 0)
        return;

    refreshMinusColumn = -1;
    refreshPlusColumn = -1;

    const SystemInfo &system = snapshot.system;
    const QString host =
        hasSnapshot && !system.hostName.isEmpty() ? system.hostName
                                                  : QStringLiteral("Clavis");
    const QString os =
        hasSnapshot && !system.osName.isEmpty() ? system.osName
                                                : QStringLiteral("system monitor");
    const QString uptime =
        hasSnapshot ? formatDuration(system.uptimeSeconds) : QStringLiteral("--");
    const QString pausedState =
        paused ? QStringLiteral("PAUSED  ") : QString{};
    const QString intervalControl =
        QStringLiteral("- %1 ms +").arg(options.refreshIntervalMs);
    const QString clock = QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss"));

    QString line;
    QString left;
    if (columns >= 92) {
        left = QStringLiteral(" CLAVIS TOP  %1 · %2  uptime %3")
                   .arg(host, os, uptime);
    } else {
        left = QStringLiteral(" CLAVIS TOP  %1").arg(host);
    }
    const QString right =
        QStringLiteral("%1%2  %3 ")
            .arg(pausedState, intervalControl, clock);
    const int rightStart =
        std::max(0, columns - displayWidth(right));
    const int controlStart =
        rightStart + displayWidth(pausedState);
    refreshMinusColumn = controlStart;
    refreshPlusColumn =
        controlStart
        + displayWidth(
            QStringLiteral("- %1 ms ").arg(options.refreshIntervalMs));
    line = fitText(
               left, std::max(0, columns - displayWidth(right)))
        + right;

    ::attrset(static_cast<int>(
        theme->attribute(Tone::Selected, A_BOLD)));
    ::mvhline(0, 0, static_cast<chtype>(' '), columns);
    putText(0,
            0,
            fitText(line, columns),
            columns,
            theme->attribute(Tone::Selected, A_BOLD),
            !unicode);
}

void TopTui::Impl::drawFooter()
{
    if (rows < 2 || columns <= 0)
        return;

    QString text;
    Tone tone = Tone::Muted;
    const auto now = Clock::now();
    if (!statusMessage.isEmpty() && now < statusUntil) {
        text = statusMessage;
        tone = statusTone;
    } else {
        statusMessage.clear();
        if (columns >= 112) {
            text = QStringLiteral(
                " q Quit  ? Help  +/- Interval  Tab Panel  g Graph"
                "  [/] Cores  j/k Move"
                "  PgUp/PgDn Focused page  / Filter  s Sort  t Tree  p Pause"
                "  Enter Details  K Signal");
        } else if (columns >= 76) {
            text = QStringLiteral(
                " q Quit  ? Help  +/- Rate  Tab Panel  g Graph  PgUp/PgDn Page"
                "  j/k Move  / Filter  p Pause");
        } else {
            text = QStringLiteral(
                " q Quit  ? Help  +/- Interval  g Graph  [/] Cores  j/k Move");
        }
        if (hasSnapshot && !snapshot.errors.isEmpty()) {
            text += QStringLiteral("  [%1 unavailable]")
                        .arg(snapshot.errors.size());
            tone = Tone::Warning;
        }
    }

    ::attrset(static_cast<int>(theme->attribute(tone)));
    ::mvhline(rows - 1, 0, static_cast<chtype>(' '), columns);
    putText(rows - 1,
            0,
            fitText(text, columns),
            columns,
            theme->attribute(tone),
            !unicode);
}

void TopTui::Impl::drawTooSmall()
{
    const QString size =
        QStringLiteral("Terminal too small: %1 x %2").arg(columns).arg(rows);
    const QString hint =
        QStringLiteral("Resize to at least 54 x 16. Press q to quit.");
    const int center = std::max(1, rows / 2);
    putText(center - 1,
            std::max(0, (columns - displayWidth(size)) / 2),
            size,
            columns,
            theme->attribute(Tone::Warning, A_BOLD),
            !unicode);
    putText(center + 1,
            std::max(0, (columns - displayWidth(hint)) / 2),
            hint,
            columns,
            theme->attribute(Tone::Muted),
            !unicode);
}

void TopTui::Impl::drawWide(const Rect &content)
{
    const int gap = 1;
    const int computeHeight =
        std::clamp(static_cast<int>(std::lround(content.height * 0.38)),
                   14,
                   std::max(12, content.height - 20));
    drawCompute({content.x, content.y, content.width, computeHeight});

    const int lowerY = content.y + computeHeight + gap;
    const int lowerHeight =
        content.y + content.height - lowerY;
    const int leftWidth =
        std::clamp(content.width * 45 / 100,
                   58,
                   std::max(58, content.width - 58 - gap));
    const int rightX = content.x + leftWidth + gap;
    const int rightWidth =
        content.x + content.width - rightX;

    const int infoHeight =
        std::clamp(static_cast<int>(std::lround(lowerHeight * 0.36)),
                   9,
                   std::max(9, lowerHeight - 9));
    const int systemWidth =
        std::clamp(leftWidth * 48 / 100,
                   32,
                   std::max(32, leftWidth - 28 - gap));
    drawSystem({
        content.x,
        lowerY,
        systemWidth,
        infoHeight,
    });
    drawResourcePane({
        content.x + systemWidth + gap,
        lowerY,
        leftWidth - systemWidth - gap,
        infoHeight,
    });

    const int networkY = lowerY + infoHeight + gap;
    drawNetwork({
        content.x,
        networkY,
        leftWidth,
        lowerY + lowerHeight - networkY,
    });
    drawProcesses({
        rightX,
        lowerY,
        rightWidth,
        lowerHeight,
    });
}

void TopTui::Impl::drawMedium(const Rect &content)
{
    const int gap = 1;
    const int leftWidth =
        std::clamp(content.width * 40 / 100,
                   36,
                   std::max(36, content.width - 48 - gap));
    const int rightX = content.x + leftWidth + gap;
    const int rightWidth =
        content.x + content.width - rightX;

    const int systemHeight =
        std::clamp(content.height / 3, 7, 9);
    const int resourcesHeight =
        std::clamp(content.height / 4, 6, 8);
    const int networkY =
        content.y + systemHeight + gap + resourcesHeight + gap;

    drawSystem({
        content.x,
        content.y,
        leftWidth,
        systemHeight,
    });
    drawResourcePane({
        content.x,
        content.y + systemHeight + gap,
        leftWidth,
        resourcesHeight,
    });
    drawNetwork({
        content.x,
        networkY,
        leftWidth,
        content.y + content.height - networkY,
    });

    const int computeHeight =
        std::clamp(static_cast<int>(std::lround(content.height * 0.50)),
                   12,
                   std::max(10, content.height - 8));
    drawCompute({
        rightX,
        content.y,
        rightWidth,
        computeHeight,
    });
    drawProcesses({
        rightX,
        content.y + computeHeight + gap,
        rightWidth,
        content.height - computeHeight - gap,
    });
}

void TopTui::Impl::drawCompact(const Rect &content)
{
    int cursor = content.y;
    if (columns >= 82 && content.height >= 22) {
        const Rect overview{content.x, cursor, content.width, 4};
        drawOverview(overview);
        cursor += overview.height + 1;
    }

    const int remaining = content.y + content.height - cursor;
    const int detailHeight =
        std::clamp(remaining / 2, 6, std::max(6, remaining - 5));
    Panel detailPanel =
        focusedPanel == Panel::Processes ? Panel::System : focusedPanel;
    const Rect detail{content.x, cursor, content.width, detailHeight};
    drawPanelFor(detailPanel, detail);
    cursor += detail.height + 1;

    drawProcesses({
        content.x,
        cursor,
        content.width,
        content.y + content.height - cursor,
    });
}

void TopTui::Impl::drawOverview(const Rect &rect)
{
    drawBox(rect,
            QStringLiteral("Overview · Tab: %1").arg(panelName(focusedPanel)),
            false);
    if (!hasSnapshot) {
        writeInside(rect, 0, QStringLiteral("Waiting for system data..."), Tone::Muted);
        return;
    }

    const OptionalNumber gpuUsage =
        snapshot.gpus.isEmpty() ? OptionalNumber{}
                                : snapshot.gpus.first().utilizationPercent;
    QString diskUsage = QStringLiteral("--");
    if (!snapshot.disks.isEmpty())
        diskUsage = formatPercent(snapshot.disks.first().usagePercent, 0);

    writeInside(
        rect,
        0,
        QStringLiteral("CPU %1   RAM %2   GPU %3   Disk %4")
            .arg(formatPercent(snapshot.cpu.usagePercent),
                 formatPercent(snapshot.memory.usagePercent),
                 formatPercent(gpuUsage),
                 diskUsage),
        Tone::Primary,
        A_BOLD);
    writeInside(
        rect,
        1,
        QStringLiteral("Net %1 down · %2 up   panel %3")
            .arg(formatRate(snapshot.network.downloadBytesPerSecond),
                 formatRate(snapshot.network.uploadBytesPerSecond),
                 panelName(focusedPanel)),
        Tone::Muted);
}

void TopTui::Impl::drawPanelFor(Panel panel, const Rect &rect)
{
    switch (panel) {
    case Panel::System:
        drawSystem(rect);
        break;
    case Panel::Compute:
        drawCompute(rect);
        break;
    case Panel::Memory:
        drawMemory(rect);
        break;
    case Panel::Network:
        drawNetwork(rect);
        break;
    case Panel::Disk:
        drawDisk(rect);
        break;
    case Panel::Processes:
        drawProcesses(rect);
        break;
    case Panel::Count:
        break;
    }
}

void TopTui::Impl::drawResourcePane(const Rect &rect)
{
    if (focusedPanel == Panel::Memory || focusedPanel == Panel::Disk) {
        drawPanelFor(focusedPanel, rect);
        return;
    }
    drawResources(rect);
}

void TopTui::Impl::drawBox(const Rect &rect,
                           const QString &title,
                           bool focused)
{
    if (rect.width < 2 || rect.height < 2)
        return;

    clearInside(rect);
    const attr_t border =
        theme->attribute(focused ? Tone::Primary : Tone::Outline,
                         focused ? A_BOLD : A_NORMAL);
    const chtype horizontal =
        unicode ? ACS_HLINE : static_cast<chtype>('-');
    const chtype vertical =
        unicode ? ACS_VLINE : static_cast<chtype>('|');
    const chtype upperLeft =
        unicode ? ACS_ULCORNER : static_cast<chtype>('+');
    const chtype upperRight =
        unicode ? ACS_URCORNER : static_cast<chtype>('+');
    const chtype lowerLeft =
        unicode ? ACS_LLCORNER : static_cast<chtype>('+');
    const chtype lowerRight =
        unicode ? ACS_LRCORNER : static_cast<chtype>('+');

    ::attrset(static_cast<int>(border));
    ::mvhline(rect.y, rect.x + 1, horizontal, std::max(0, rect.width - 2));
    ::mvhline(rect.y + rect.height - 1,
              rect.x + 1,
              horizontal,
              std::max(0, rect.width - 2));
    ::mvvline(rect.y + 1,
              rect.x,
              vertical,
              std::max(0, rect.height - 2));
    ::mvvline(rect.y + 1,
              rect.x + rect.width - 1,
              vertical,
              std::max(0, rect.height - 2));
    ::mvaddch(rect.y, rect.x, upperLeft);
    ::mvaddch(rect.y, rect.x + rect.width - 1, upperRight);
    ::mvaddch(rect.y + rect.height - 1, rect.x, lowerLeft);
    ::mvaddch(rect.y + rect.height - 1,
              rect.x + rect.width - 1,
              lowerRight);

    const QString label = QStringLiteral(" %1 ").arg(title);
    putText(rect.y,
            rect.x + 2,
            label,
            std::max(0, rect.width - 4),
            theme->attribute(focused ? Tone::Primary : Tone::Muted,
                             focused ? A_BOLD : A_NORMAL),
            !unicode);
}

void TopTui::Impl::clearInside(const Rect &rect, Tone tone)
{
    if (rect.width <= 2 || rect.height <= 2)
        return;
    ::attrset(static_cast<int>(theme->attribute(tone)));
    for (int line = 1; line < rect.height - 1; ++line) {
        if (rect.y + line >= 0 && rect.y + line < rows)
            ::mvhline(rect.y + line,
                      rect.x + 1,
                      static_cast<chtype>(' '),
                      std::max(0, rect.width - 2));
    }
}

void TopTui::Impl::writeInside(const Rect &rect,
                               int line,
                               const QString &text,
                               Tone tone,
                               attr_t extra,
                               bool fill)
{
    if (line < 0 || line >= rect.height - 2)
        return;
    const int width = std::max(0, rect.width - 2);
    putText(rect.y + 1 + line,
            rect.x + 1,
            fill ? fitText(text, width) : text,
            width,
            theme->attribute(tone, extra),
            !unicode);
}

void TopTui::Impl::writeAtInside(const Rect &rect,
                                 int line,
                                 int column,
                                 const QString &text,
                                 Tone tone,
                                 attr_t extra)
{
    if (line < 0 || line >= rect.height - 2 || column < 0)
        return;

    const int available = rect.width - 2 - column;
    if (available <= 0)
        return;
    putText(rect.y + 1 + line,
            rect.x + 1 + column,
            text,
            available,
            theme->attribute(tone, extra),
            !unicode);
}

void TopTui::Impl::drawMetricRow(const Rect &rect,
                                 int line,
                                 const QString &label,
                                 const OptionalNumber &percent,
                                 const QString &detail,
                                 int labelWidth,
                                 int detailWidth,
                                 Tone meterTone,
                                 Tone valueTone)
{
    if (line < 0 || line >= rect.height - 2)
        return;

    const int innerWidth = std::max(0, rect.width - 2);
    constexpr int percentWidth = 5;
    constexpr int gapCount = 3;
    labelWidth = std::clamp(labelWidth, 1, innerWidth);
    detailWidth = std::clamp(detailWidth, 0, innerWidth);
    int meterWidth =
        innerWidth - labelWidth - percentWidth - detailWidth - gapCount;
    if (meterWidth < 3) {
        detailWidth = 0;
        meterWidth =
            innerWidth - labelWidth - percentWidth - 2;
    }
    if (meterWidth < 1) {
        writeInside(rect,
                    line,
                    QStringLiteral("%1 %2")
                        .arg(label, formatPercent(percent, 0)),
                    valueTone,
                    A_BOLD,
                    true);
        return;
    }

    const int row = rect.y + 1 + line;
    int column = rect.x + 1;
    putText(row,
            column,
            fitText(label, labelWidth),
            labelWidth,
            theme->attribute(Tone::Muted, A_BOLD),
            !unicode);
    column += labelWidth + 1;
    putText(row,
            column,
            meter(percent, meterWidth),
            meterWidth,
            theme->attribute(meterTone),
            !unicode);
    column += meterWidth + 1;
    putText(row,
            column,
            fitText(formatPercent(percent, 0), percentWidth, true),
            percentWidth,
            theme->attribute(valueTone, A_BOLD),
            !unicode);
    column += percentWidth;
    if (detailWidth > 0) {
        ++column;
        putText(row,
                column,
                fitText(detail, detailWidth),
                detailWidth,
                theme->attribute(Tone::Muted),
                !unicode);
    }
}

void TopTui::Impl::drawHistoryGraph(const Rect &plot,
                                    const std::deque<double> &history,
                                    double fixedMaximum,
                                    Tone tone,
                                    bool invert,
                                    bool peakBuckets)
{
    if (plot.width <= 0 || plot.height <= 0 || history.empty())
        return;

    std::vector<double> samples;
    int startColumn = 0;
    if (static_cast<int>(history.size()) <= plot.width) {
        samples.assign(history.begin(), history.end());
        startColumn = plot.width - static_cast<int>(samples.size());
    } else {
        samples.reserve(plot.width);
        const int count = static_cast<int>(history.size());
        for (int column = 0; column < plot.width; ++column) {
            int begin =
                static_cast<int>((static_cast<long long>(column) * count)
                                 / plot.width);
            int end =
                static_cast<int>((static_cast<long long>(column + 1) * count)
                                 / plot.width);
            end = std::clamp(end, begin + 1, count);

            double aggregated = peakBuckets ? 0.0 : 0.0;
            for (int index = begin; index < end; ++index) {
                const double value = history.at(index);
                if (peakBuckets)
                    aggregated = std::max(aggregated, value);
                else
                    aggregated += value;
            }
            if (!peakBuckets)
                aggregated /= std::max(1, end - begin);
            samples.push_back(std::max(0.0, aggregated));
        }
    }

    double maximum = fixedMaximum;
    if (maximum <= 0.0) {
        for (const double value : samples)
            maximum = std::max(maximum, value);
    }
    maximum = std::max(maximum, 0.000001);

    const QString lowerLevels = QStringLiteral(" ▁▂▃▄▅▆▇█");
    const QString upperLevels = QStringLiteral(" ▔▔▀▀▀███");
    for (int column = 0; column < static_cast<int>(samples.size()); ++column) {
        const double ratio =
            std::clamp(samples.at(column) / maximum, 0.0, 1.0);
        const double units = ratio * plot.height * 8.0;

        for (int layer = 0; layer < plot.height; ++layer) {
            const int level =
                std::clamp(static_cast<int>(std::lround(units - layer * 8.0)),
                           0,
                           8);
            if (level <= 0)
                continue;

            const int row = invert ? layer : plot.height - 1 - layer;
            QString glyph;
            if (unicode) {
                glyph = QString((invert ? upperLevels : lowerLevels).at(level));
            } else {
                glyph = level >= 4 ? QStringLiteral("#")
                                   : QStringLiteral(".");
            }
            putText(plot.y + row,
                    plot.x + startColumn + column,
                    glyph,
                    1,
                    theme->attribute(tone),
                    !unicode);
        }
    }
}

void TopTui::Impl::drawLineHistoryGraph(const Rect &plot,
                                        const std::deque<double> &history,
                                        double maximum,
                                        Tone tone)
{
    if (plot.width <= 0 || plot.height <= 0 || history.empty())
        return;

    const LineRaster raster =
        rasterizeLine(history, plot.width, plot.height, maximum);
    const auto glyphFor = [this](unsigned char connection, bool point) {
        if (!unicode) {
            const bool horizontal =
                connection & (ConnectLeft | ConnectRight);
            const bool vertical =
                connection & (ConnectUp | ConnectDown);
            if (horizontal && vertical)
                return static_cast<chtype>('+');
            if (vertical)
                return static_cast<chtype>('|');
            if (horizontal || point)
                return static_cast<chtype>('-');
            return static_cast<chtype>(' ');
        }

        switch (connection) {
        case ConnectLeft | ConnectRight:
            return static_cast<chtype>(ACS_HLINE);
        case ConnectUp | ConnectDown:
            return static_cast<chtype>(ACS_VLINE);
        case ConnectRight | ConnectDown:
            return static_cast<chtype>(ACS_ULCORNER);
        case ConnectLeft | ConnectDown:
            return static_cast<chtype>(ACS_URCORNER);
        case ConnectRight | ConnectUp:
            return static_cast<chtype>(ACS_LLCORNER);
        case ConnectLeft | ConnectUp:
            return static_cast<chtype>(ACS_LRCORNER);
        case ConnectUp | ConnectRight | ConnectDown:
            return static_cast<chtype>(ACS_LTEE);
        case ConnectUp | ConnectLeft | ConnectDown:
            return static_cast<chtype>(ACS_RTEE);
        case ConnectLeft | ConnectRight | ConnectDown:
            return static_cast<chtype>(ACS_TTEE);
        case ConnectLeft | ConnectRight | ConnectUp:
            return static_cast<chtype>(ACS_BTEE);
        case ConnectUp | ConnectRight | ConnectDown | ConnectLeft:
            return static_cast<chtype>(ACS_PLUS);
        case ConnectUp:
        case ConnectDown:
            return static_cast<chtype>(ACS_VLINE);
        case ConnectLeft:
        case ConnectRight:
            return static_cast<chtype>(ACS_HLINE);
        default:
            return point ? static_cast<chtype>(ACS_HLINE)
                         : static_cast<chtype>(' ');
        }
    };

    ::attrset(static_cast<int>(theme->attribute(tone, A_BOLD)));
    for (int y = 0; y < raster.height; ++y) {
        for (int x = 0; x < raster.width; ++x) {
            const unsigned char connection = raster.connectionAt(x, y);
            const bool point = raster.pointAt(x, y);
            if (connection == ConnectNone && !point)
                continue;
            ::mvaddch(plot.y + y,
                      plot.x + x,
                      glyphFor(connection, point));
        }
    }
}

void TopTui::Impl::drawSplitHistoryGraph(const Rect &plot)
{
    if (plot.width <= 0 || plot.height <= 0)
        return;
    if (plot.height < 3) {
        drawHistoryGraph(
            plot, downloadHistory, 0.0, Tone::Primary, false, true);
        return;
    }

    const int topHeight = (plot.height - 1) / 2;
    const int axisY = plot.y + topHeight;
    const int bottomHeight = plot.height - topHeight - 1;
    drawHistoryGraph(
        {plot.x, plot.y, plot.width, topHeight},
        downloadHistory,
        0.0,
        Tone::Primary,
        false,
        true);
    drawHistoryGraph(
        {plot.x, axisY + 1, plot.width, bottomHeight},
        uploadHistory,
        0.0,
        Tone::Good,
        true,
        true);

    ::attrset(static_cast<int>(theme->attribute(Tone::Outline)));
    ::mvhline(axisY,
              plot.x,
              unicode ? ACS_HLINE : static_cast<chtype>('-'),
              plot.width);
    const QString label =
        unicode ? QStringLiteral(" ↓ download  ↑ upload ")
                : QStringLiteral(" D download  U upload ");
    putText(axisY,
            plot.x + 1,
            label,
            std::max(0, plot.width - 2),
            theme->attribute(Tone::Muted),
            !unicode);
}

CoreGridLayout TopTui::Impl::drawCoreGrid(
    const Rect &plot,
    const QVector<int> &ids,
    const QVector<OptionalNumber> &values)
{
    int largestCoreId =
        std::max(0, static_cast<int>(values.size()) - 1);
    for (const int id : ids)
        largestCoreId = std::max(largestCoreId, id);

    CoreGridLayout layout =
        calculateCoreGridLayout(plot.width,
                                plot.height,
                                values.size(),
                                largestCoreId,
                                corePage);
    corePage = layout.page;
    corePageCount = std::max(1, layout.pageCount);
    if (layout.visibleCount <= 0)
        return layout;

    constexpr int percentWidth = 4;
    for (int offset = 0; offset < layout.visibleCount; ++offset) {
        const int index = layout.firstIndex + offset;
        const int row = offset / layout.columns;
        const int columnIndex = offset % layout.columns;
        const int cellX = plot.x + columnIndex * layout.cellWidth;
        const int renderedWidth =
            std::max(1, layout.cellWidth - 1);
        const int coreId = index < ids.size() ? ids.at(index) : index;
        const QString label =
            QStringLiteral("C%1")
                .arg(coreId,
                     layout.labelWidth - 1,
                     10,
                     QLatin1Char('0'));
        const QString percent = formatPercent(values.at(index), 0);

        putText(plot.y + row,
                cellX,
                fitText(label, layout.labelWidth),
                std::min(layout.labelWidth, renderedWidth),
                theme->attribute(Tone::Muted),
                !unicode);

        int cursor = cellX + layout.labelWidth;
        if (layout.meterWidth > 0) {
            ++cursor;
            putText(plot.y + row,
                    cursor,
                    meter(values.at(index), layout.meterWidth),
                    layout.meterWidth,
                    theme->attribute(Tone::Primary),
                    !unicode);
            cursor += layout.meterWidth;
        }

        ++cursor;
        Tone valueTone = Tone::Normal;
        if (values.at(index) && *values.at(index) >= 90.0)
            valueTone = Tone::Critical;
        else if (values.at(index) && *values.at(index) >= 75.0)
            valueTone = Tone::Warning;
        putText(plot.y + row,
                cursor,
                fitText(percent, percentWidth, true),
                std::max(0,
                         std::min(percentWidth,
                                  cellX + renderedWidth - cursor)),
                theme->attribute(valueTone, A_BOLD),
                !unicode);
    }
    return layout;
}

QStringList TopTui::Impl::distroMark(const QString &distroId) const
{
    const QString id = distroId.toLower();
    if (id.contains(QStringLiteral("arch"))
        || id.contains(QStringLiteral("manjaro"))
        || id.contains(QStringLiteral("endeavour"))) {
        return {
            QStringLiteral("      /\\"),
            QStringLiteral("     /  \\"),
            QStringLiteral("    /\\   \\"),
            QStringLiteral("   /      \\"),
            QStringLiteral("  /   ,,   \\"),
            QStringLiteral(" /   |  |   \\"),
            QStringLiteral("/_-''    ''-_\\"),
        };
    }
    if (id.contains(QStringLiteral("nixos"))
        || id == QStringLiteral("nix")) {
        return {
            QStringLiteral("  \\\\  //  "),
            QStringLiteral(" ==\\\\//== "),
            QStringLiteral(" ===><=== "),
            QStringLiteral(" ==//\\\\== "),
            QStringLiteral("  //  \\\\  "),
        };
    }
    if (id.contains(QStringLiteral("ubuntu"))) {
        return {
            QStringLiteral("   .---.   "),
            QStringLiteral("  /  o  \\  "),
            QStringLiteral(" o   O   o "),
            QStringLiteral("  \\  o  /  "),
            QStringLiteral("   '---'   "),
        };
    }
    return {
        QStringLiteral("   .----.   "),
        QStringLiteral("  / /\\  \\  "),
        QStringLiteral(" | |  | |  "),
        QStringLiteral("  \\ \\/ /  "),
        QStringLiteral("   '----'   "),
    };
}

QString TopTui::Impl::meter(const OptionalNumber &percent, int width) const
{
    return borderlessMeter(percent, width, unicode);
}

QString TopTui::Impl::sparkline(const std::deque<double> &history,
                                int width,
                                double fixedMaximum) const
{
    if (width <= 0 || history.empty())
        return {};

    const int count = std::min(width, static_cast<int>(history.size()));
    const auto begin = history.end() - count;
    double maximum = fixedMaximum;
    if (maximum <= 0.0) {
        for (auto iterator = begin; iterator != history.end(); ++iterator)
            maximum = std::max(maximum, *iterator);
    }
    maximum = std::max(maximum, 0.000001);

    const QString levels =
        unicode ? QStringLiteral("▁▂▃▄▅▆▇█")
                : QStringLiteral(".:-=+*#%");
    QString result;
    result.reserve(count);
    for (auto iterator = begin; iterator != history.end(); ++iterator) {
        const double ratio = std::clamp(*iterator / maximum, 0.0, 1.0);
        const int index =
            std::clamp(static_cast<int>(std::lround(
                           ratio
                           * static_cast<double>(levels.size() - 1))),
                       0,
                       static_cast<int>(levels.size()) - 1);
        result.append(levels.at(index));
    }
    return QString(std::max(0, width - displayWidth(result)), QLatin1Char(' '))
        + result;
}

void TopTui::Impl::drawSystem(const Rect &rect)
{
    const QString distro =
        hasSnapshot && !snapshot.system.distroId.isEmpty()
        ? snapshot.system.distroId
        : QStringLiteral("linux");
    drawBox(rect,
            QStringLiteral("System · %1").arg(distro),
            focusedPanel == Panel::System);
    if (!hasSnapshot || !snapshot.system.available) {
        writeInside(rect,
                    0,
                    hasSnapshot ? QStringLiteral("System information unavailable")
                                : QStringLiteral("Waiting for system data..."),
                    Tone::Muted);
        return;
    }

    const SystemInfo &system = snapshot.system;
    const QStringList mark = distroMark(system.distroId);
    int markWidth = 0;
    for (const QString &line : mark)
        markWidth = std::max(markWidth, displayWidth(line));
    const bool showMark =
        rect.width >= 36 && rect.height >= 7
        && markWidth + 15 < rect.width - 2;
    const int textColumn = showMark ? markWidth + 2 : 0;

    if (showMark) {
        const int visibleLines =
            std::min(static_cast<int>(mark.size()),
                     std::max(0, rect.height - 2));
        for (int line = 0; line < visibleLines; ++line) {
            writeAtInside(
                rect, line, 0, mark.at(line), Tone::Primary, A_BOLD);
        }
    }

    int line = 0;
    writeAtInside(
        rect,
        line++,
        textColumn,
        system.osName.isEmpty() ? system.distroId : system.osName,
        Tone::Primary,
        A_BOLD);
    writeAtInside(rect,
                  line++,
                  textColumn,
                  system.hostName.isEmpty()
                      ? QStringLiteral("unknown host")
                      : system.hostName,
                  Tone::Normal);
    writeAtInside(rect,
                  line++,
                  textColumn,
                  QStringLiteral("%1 · %2")
                      .arg(system.kernel, system.architecture),
                  Tone::Muted);
    writeAtInside(rect,
                  line++,
                  textColumn,
                  QStringLiteral("up %1")
                      .arg(formatDuration(system.uptimeSeconds)),
                  Tone::Normal);
    writeAtInside(rect,
                  line++,
                  textColumn,
                  QStringLiteral("%1C / %2T")
                      .arg(system.physicalCoreCount)
                      .arg(system.logicalCpuCount),
                  Tone::Normal);

    if (line < rect.height - 2) {
        const QString device =
            (system.vendor + QLatin1Char(' ')
             + (system.productName.isEmpty()
                    ? system.boardName
                    : system.productName))
                .trimmed();
        if (!device.isEmpty()) {
            writeAtInside(
                rect, line, textColumn, device, Tone::Muted);
        } else if (!snapshot.errors.isEmpty()) {
            const Error &last = snapshot.errors.last();
            writeAtInside(rect,
                          line,
                          textColumn,
                          QStringLiteral("%1 unavailable")
                              .arg(last.module),
                          Tone::Warning);
        }
    }
}

QString TopTui::Impl::gpuKey(const GpuInfo &gpu, int index) const
{
    if (!gpu.pciId.isEmpty())
        return QStringLiteral("pci:") + gpu.pciId;
    if (!gpu.id.isEmpty())
        return QStringLiteral("id:") + gpu.id;
    return QStringLiteral("gpu:%1:%2:%3")
        .arg(gpu.vendor, gpu.name)
        .arg(index);
}

QVector<QString> TopTui::Impl::graphGpuKeys() const
{
    QVector<QString> keys;
    for (int index = 0; index < snapshot.gpus.size(); ++index) {
        const GpuInfo &gpu = snapshot.gpus.at(index);
        if (!gpu.utilizationPercent)
            continue;
        keys.push_back(gpuKey(gpu, index));
    }
    return keys;
}

const GpuInfo *TopTui::Impl::gpuForKey(const QString &key) const
{
    for (int index = 0; index < snapshot.gpus.size(); ++index) {
        const GpuInfo &gpu = snapshot.gpus.at(index);
        if (gpuKey(gpu, index) == key)
            return &gpu;
    }
    return nullptr;
}

void TopTui::Impl::cycleComputeGraph()
{
    const QVector<QString> keys = graphGpuKeys();
    int currentSource = 0;
    if (!computeGraphGpuKey.isEmpty()) {
        const int currentGpu = keys.indexOf(computeGraphGpuKey);
        currentSource = currentGpu >= 0 ? currentGpu + 1 : 0;
    }
    const int nextSource =
        nextGraphSource(currentSource, keys.size());
    computeGraphGpuKey =
        nextSource == 0 ? QString{} : keys.at(nextSource - 1);
    focusedPanel = Panel::Compute;

    if (computeGraphGpuKey.isEmpty()) {
        setStatus(QStringLiteral("Compute graph: CPU"), Tone::Primary);
        return;
    }

    const GpuInfo *gpu = gpuForKey(computeGraphGpuKey);
    const QString name =
        gpu && !gpu->name.isEmpty() ? gpu->name : QStringLiteral("GPU");
    setStatus(
        QStringLiteral("Compute graph: GPU %1 · %2")
            .arg(nextSource - 1)
            .arg(name),
        Tone::Good);
}

void TopTui::Impl::changeFocusedPage(int direction)
{
    switch (focusedPanel) {
    case Panel::Compute:
        changeCorePage(direction);
        return;
    case Panel::Disk:
        changeDiskPage(direction);
        return;
    case Panel::Processes:
        moveSelection(
            direction * std::max(1, processPageRows));
        return;
    case Panel::System:
    case Panel::Memory:
    case Panel::Network:
    case Panel::Count:
        setStatus(
            QStringLiteral("%1 panel has no paged content")
                .arg(panelName(focusedPanel)),
            Tone::Muted);
        return;
    }
}

void TopTui::Impl::changeCorePage(int direction)
{
    if (corePageCount <= 1) {
        corePage = 0;
        setStatus(QStringLiteral("All CPU cores fit on one page"), Tone::Muted);
        return;
    }
    corePage =
        std::clamp(corePage + direction, 0, corePageCount - 1);
    focusedPanel = Panel::Compute;
    setStatus(
        QStringLiteral("CPU core page %1/%2")
            .arg(corePage + 1)
            .arg(corePageCount),
        Tone::Primary);
}

void TopTui::Impl::changeDiskPage(int direction)
{
    if (diskPageCount <= 1) {
        diskPage = 0;
        setStatus(QStringLiteral("All disks fit on one page"), Tone::Muted);
        return;
    }
    diskPage =
        std::clamp(diskPage + direction, 0, diskPageCount - 1);
    focusedPanel = Panel::Disk;
    setStatus(
        QStringLiteral("Disk page %1/%2")
            .arg(diskPage + 1)
            .arg(diskPageCount),
        Tone::Primary);
}

void TopTui::Impl::drawCompute(const Rect &rect)
{
    const int innerWidth = std::max(0, rect.width - 2);
    const int innerHeight = std::max(0, rect.height - 2);
    const int summaryRows = innerHeight >= 4 ? 2 : 1;
    const int contentTop = rect.y + 1 + summaryRows;
    const int remainingHeight = innerHeight - summaryRows;

    Rect graphRect{
        rect.x + 1,
        contentTop,
        innerWidth,
        std::max(0, remainingHeight),
    };
    Rect coreRect{};
    const bool sideBySide =
        innerWidth >= 72 && remainingHeight >= 5
        && hasSnapshot && !snapshot.cpu.coreUsagePercent.isEmpty();
    if (sideBySide) {
        const int coreWidth =
            std::clamp(innerWidth * 32 / 100,
                       30,
                       std::min(80, innerWidth - 32));
        const int graphWidth = innerWidth - coreWidth - 1;
        graphRect.width = graphWidth;
        coreRect = {
            rect.x + 1 + graphWidth + 1,
            contentTop,
            coreWidth,
            remainingHeight,
        };
    } else if (hasSnapshot
               && !snapshot.cpu.coreUsagePercent.isEmpty()
               && remainingHeight >= 4) {
        const int coreHeight = std::max(2, remainingHeight / 2);
        coreRect = {
            rect.x + 1,
            contentTop,
            innerWidth,
            coreHeight,
        };
        graphRect.y += coreHeight;
        graphRect.height -= coreHeight;
    }

    CoreGridLayout coreLayout;
    if (coreRect.width > 0 && coreRect.height > 0) {
        int largestCoreId =
            std::max(0,
                     static_cast<int>(
                         snapshot.cpu.coreUsagePercent.size()) - 1);
        for (const int id : snapshot.cpu.coreIds)
            largestCoreId = std::max(largestCoreId, id);
        coreLayout =
            calculateCoreGridLayout(
                coreRect.width,
                coreRect.height,
                snapshot.cpu.coreUsagePercent.size(),
                largestCoreId,
                corePage);
        corePage = coreLayout.page;
        corePageCount = std::max(1, coreLayout.pageCount);
    } else {
        corePage = 0;
        corePageCount = 1;
    }

    const QVector<QString> gpuKeys = graphGpuKeys();
    const int activeGpuIndex =
        computeGraphGpuKey.isEmpty()
        ? -1
        : gpuKeys.indexOf(computeGraphGpuKey);
    QString graphLabel =
        activeGpuIndex >= 0
        ? QStringLiteral("GPU %1").arg(activeGpuIndex)
        : QStringLiteral("CPU");
    if (activeGpuIndex < 0)
        computeGraphGpuKey.clear();

    QString title =
        QStringLiteral("Compute · graph %1 [g]").arg(graphLabel);
    if (coreLayout.pageCount > 1) {
        title += QStringLiteral(" · cores %1–%2/%3 [/]")
                     .arg(coreLayout.firstIndex + 1)
                     .arg(coreLayout.firstIndex + coreLayout.visibleCount)
                     .arg(snapshot.cpu.coreUsagePercent.size());
    }
    drawBox(rect, title, focusedPanel == Panel::Compute);

    if (!hasSnapshot || !snapshot.cpu.available) {
        writeInside(rect,
                    0,
                    hasSnapshot ? QStringLiteral("CPU metrics unavailable")
                                : QStringLiteral("Waiting for compute data..."),
                    Tone::Muted);
        return;
    }

    const CpuInfo &cpu = snapshot.cpu;
    Tone cpuTone = Tone::Primary;
    if (cpu.usagePercent && *cpu.usagePercent >= 90.0)
        cpuTone = Tone::Critical;
    else if (cpu.usagePercent && *cpu.usagePercent >= 75.0)
        cpuTone = Tone::Warning;

    constexpr int summaryLabelWidth = 4;
    constexpr int summaryPercentWidth = 5;
    constexpr int summaryGapWidth = 3;
    const int summaryMeterWidth =
        std::clamp(innerWidth / 5, 12, 32);
    const int detailWidth =
        std::max(0,
                 innerWidth - summaryLabelWidth - summaryPercentWidth
                     - summaryGapWidth - summaryMeterWidth);
    const QString cpuName =
        snapshot.system.cpuModelName.isEmpty()
        ? QStringLiteral("CPU")
        : snapshot.system.cpuModelName;
    const QString cpuDetail =
        QStringLiteral("PWR %1 · %2 · %3 · %4")
            .arg(optionalNumber(cpu.powerWatts, QStringLiteral(" W"), 1),
                 optionalNumber(cpu.frequencyCurrentMHz,
                                QStringLiteral(" MHz"),
                                0),
                 optionalNumber(cpu.packageTemperatureCelsius
                                    ? cpu.packageTemperatureCelsius
                                    : cpu.temperatureCelsius,
                                QStringLiteral("°C"),
                                0),
                 cpuName);
    drawMetricRow(rect,
                  0,
                  QStringLiteral("CPU"),
                  cpu.usagePercent,
                  cpuDetail,
                  summaryLabelWidth,
                  detailWidth,
                  Tone::Primary,
                  cpuTone);

    const GpuInfo *summaryGpu = nullptr;
    if (activeGpuIndex >= 0)
        summaryGpu = gpuForKey(computeGraphGpuKey);
    if (!summaryGpu && !snapshot.gpus.isEmpty())
        summaryGpu = &snapshot.gpus.first();

    if (summaryRows > 1) {
        if (summaryGpu) {
            Tone gpuTone = Tone::Good;
            if (summaryGpu->temperatureCelsius
                && *summaryGpu->temperatureCelsius >= 90.0) {
                gpuTone = Tone::Critical;
            } else if (summaryGpu->temperatureCelsius
                       && *summaryGpu->temperatureCelsius >= 80.0) {
                gpuTone = Tone::Warning;
            }
            const QString name =
                summaryGpu->name.isEmpty()
                ? (summaryGpu->id.isEmpty() ? QStringLiteral("GPU")
                                            : summaryGpu->id)
                : summaryGpu->name;
            const QString vram =
                summaryGpu->vramUsedBytes && summaryGpu->vramTotalBytes
                ? QStringLiteral("%1/%2")
                      .arg(formatBytes(
                               static_cast<double>(
                                   *summaryGpu->vramUsedBytes)),
                           formatBytes(
                               static_cast<double>(
                                   *summaryGpu->vramTotalBytes)))
                : QStringLiteral("--");
            const QString gpuDetail =
                QStringLiteral("PWR %1 · %2 · VRAM %3 · %4")
                    .arg(optionalNumber(summaryGpu->powerWatts,
                                        QStringLiteral(" W"),
                                        1),
                         optionalNumber(summaryGpu->temperatureCelsius,
                                        QStringLiteral("°C"),
                                        0),
                         vram,
                         name);
            drawMetricRow(rect,
                          1,
                          QStringLiteral("GPU"),
                          summaryGpu->utilizationPercent,
                          gpuDetail,
                          summaryLabelWidth,
                          detailWidth,
                          Tone::Good,
                          gpuTone);
        } else {
            writeInside(
                rect, 1, QStringLiteral("GPU metrics unavailable"), Tone::Muted);
        }
    }

    const std::deque<double> *graphHistory = &cpuHistory;
    Tone graphTone = cpuTone;
    if (activeGpuIndex >= 0) {
        const auto history = gpuHistories.constFind(computeGraphGpuKey);
        if (history != gpuHistories.constEnd())
            graphHistory = &history.value();
        if (summaryGpu && summaryGpu->utilizationPercent
            && *summaryGpu->utilizationPercent >= 90.0) {
            graphTone = Tone::Critical;
        } else if (summaryGpu && summaryGpu->utilizationPercent
                   && *summaryGpu->utilizationPercent >= 75.0) {
            graphTone = Tone::Warning;
        } else {
            graphTone = Tone::Good;
        }
    }

    if (graphRect.height > 0)
        drawLineHistoryGraph(graphRect, *graphHistory, 100.0, graphTone);

    if (sideBySide) {
        const int dividerX = coreRect.x - 1;
        ::attrset(static_cast<int>(theme->attribute(Tone::Outline)));
        ::mvvline(contentTop,
                  dividerX,
                  unicode ? ACS_VLINE : static_cast<chtype>('|'),
                  remainingHeight);
    }
    if (coreRect.width > 0 && coreRect.height > 0)
        drawCoreGrid(coreRect, cpu.coreIds, cpu.coreUsagePercent);
}

void TopTui::Impl::drawMemory(const Rect &rect)
{
    drawBox(rect, QStringLiteral("Memory"), focusedPanel == Panel::Memory);
    if (!hasSnapshot || !snapshot.memory.available) {
        writeInside(rect,
                    0,
                    hasSnapshot ? QStringLiteral("Memory metrics unavailable")
                                : QStringLiteral("Waiting for memory data..."),
                    Tone::Muted);
        return;
    }

    const MemoryInfo &memory = snapshot.memory;
    Tone utilizationTone = Tone::Primary;
    if (memory.usagePercent && *memory.usagePercent >= 92.0)
        utilizationTone = Tone::Critical;
    else if (memory.usagePercent && *memory.usagePercent >= 80.0)
        utilizationTone = Tone::Warning;

    const auto percentOfTotal = [&memory](quint64 value) -> OptionalNumber {
        if (memory.totalBytes == 0)
            return std::nullopt;
        return 100.0 * static_cast<double>(value)
            / static_cast<double>(memory.totalBytes);
    };
    const QString total = formatBytes(memory.totalBytes);
    const int detailWidth = rect.width >= 52 ? 21 : 0;
    const int labelWidth = rect.width >= 34 ? 10 : 6;
    int line = 0;
    drawMetricRow(rect,
                  line++,
                  QStringLiteral("Used"),
                  memory.usagePercent,
                  QStringLiteral("%1 / %2")
                      .arg(formatBytes(memory.usedBytes), total),
                  labelWidth,
                  detailWidth,
                  utilizationTone,
                  utilizationTone);
    drawMetricRow(rect,
                  line++,
                  QStringLiteral("Available"),
                  percentOfTotal(memory.availableBytes),
                  QStringLiteral("%1 / %2")
                      .arg(formatBytes(memory.availableBytes), total),
                  labelWidth,
                  detailWidth,
                  Tone::Good);
    drawMetricRow(rect,
                  line++,
                  QStringLiteral("Cached"),
                  percentOfTotal(memory.cachedBytes),
                  QStringLiteral("%1 / %2")
                      .arg(formatBytes(memory.cachedBytes), total),
                  labelWidth,
                  detailWidth,
                  Tone::Primary);
    drawMetricRow(rect,
                  line++,
                  QStringLiteral("Free"),
                  percentOfTotal(memory.freeBytes),
                  QStringLiteral("%1 / %2")
                      .arg(formatBytes(memory.freeBytes), total),
                  labelWidth,
                  detailWidth,
                  Tone::Good);

    if (line < rect.height - 2) {
        if (memory.swapTotalBytes > 0) {
            const double swapPercent =
                100.0 * static_cast<double>(memory.swapUsedBytes)
                / static_cast<double>(memory.swapTotalBytes);
            writeInside(
                rect,
                line,
                QStringLiteral("Swap %1 / %2 · %3%")
                    .arg(formatBytes(memory.swapUsedBytes),
                         formatBytes(memory.swapTotalBytes))
                    .arg(swapPercent, 0, 'f', 1),
                Tone::Muted);
        } else {
            writeInside(
                rect, line, QStringLiteral("Swap not configured"), Tone::Muted);
        }
    }
}

void TopTui::Impl::drawNetwork(const Rect &rect)
{
    QString title = QStringLiteral("Network");
    if (hasSnapshot && !snapshot.network.defaultInterface.isEmpty())
        title += QStringLiteral(" · ") + snapshot.network.defaultInterface;
    drawBox(rect, title, focusedPanel == Panel::Network);
    if (!hasSnapshot || !snapshot.network.available) {
        writeInside(rect,
                    0,
                    hasSnapshot ? QStringLiteral("Network metrics unavailable")
                                : QStringLiteral("Waiting for network data..."),
                    Tone::Muted);
        return;
    }

    const QString down = unicode ? QStringLiteral("↓") : QStringLiteral("D");
    const QString up = unicode ? QStringLiteral("↑") : QStringLiteral("U");
    writeInside(
        rect,
        0,
        QStringLiteral("%1 %2  %3 %4")
            .arg(down,
                 formatRate(snapshot.network.downloadBytesPerSecond),
                 up,
                 formatRate(snapshot.network.uploadBytesPerSecond)),
        Tone::Primary,
        A_BOLD);
    writeInside(
        rect,
        1,
        QStringLiteral("total %1 %2 · %3 %4")
            .arg(down,
                 formatBytes(snapshot.network.downloadTotalBytes),
                 up,
                 formatBytes(snapshot.network.uploadTotalBytes)),
        Tone::Muted);

    const Rect graph{
        rect.x + 1,
        rect.y + 3,
        std::max(0, rect.width - 2),
        std::max(0, rect.height - 4),
    };
    if (graph.height >= 3) {
        drawSplitHistoryGraph(graph);
    } else if (graph.height > 0) {
        writeInside(
            rect,
            2,
            down + QStringLiteral(" ")
                + sparkline(downloadHistory,
                            std::max(0, rect.width - 4)),
            Tone::Primary);
    }
}

void TopTui::Impl::drawDisk(const Rect &rect)
{
    const int availableRows = std::max(0, rect.height - 2);
    const int rowsPerDisk = availableRows >= 2 ? 2 : 1;
    const int disksPerPage =
        std::max(1, availableRows / rowsPerDisk);
    const PageLayout page =
        calculatePageLayout(snapshot.disks.size(),
                            disksPerPage,
                            diskPage);
    diskPage = page.page;
    diskPageCount = page.pageCount;

    QString title = QStringLiteral("Disk");
    if (page.pageCount > 1) {
        title += QStringLiteral(" · %1–%2/%3 · PgUp/PgDn")
                     .arg(page.firstIndex + 1)
                     .arg(page.firstIndex + page.visibleCount)
                     .arg(snapshot.disks.size());
    }
    drawBox(rect, title, focusedPanel == Panel::Disk);
    if (!hasSnapshot) {
        writeInside(rect, 0, QStringLiteral("Waiting for disk data..."), Tone::Muted);
        return;
    }
    if (snapshot.disks.isEmpty()) {
        writeInside(rect,
                    0,
                    QStringLiteral("No mounted disk metrics"),
                    Tone::Muted);
        return;
    }

    const int innerWidth = std::max(0, rect.width - 2);
    const int labelWidth =
        std::clamp(innerWidth / 5, 5, 14);
    const int detailWidth = rect.width >= 48 ? 17 : 0;
    int line = 0;
    const int end = page.firstIndex + page.visibleCount;
    for (int index = page.firstIndex; index < end; ++index) {
        const DiskInfo &disk = snapshot.disks.at(index);
        Tone tone = Tone::Primary;
        if (disk.usagePercent && *disk.usagePercent >= 95.0)
            tone = Tone::Critical;
        else if (disk.usagePercent && *disk.usagePercent >= 85.0)
            tone = Tone::Warning;
        drawMetricRow(
            rect,
            line++,
            disk.mountPoint.isEmpty() ? disk.device : disk.mountPoint,
            disk.usagePercent,
            QStringLiteral("%1/%2")
                .arg(formatBytes(disk.usedBytes),
                     formatBytes(disk.totalBytes)),
            labelWidth,
            detailWidth,
            tone,
            tone);
        if (rowsPerDisk > 1 && line < availableRows) {
            writeInside(
                rect,
                line++,
                QStringLiteral("R %1 · W %2 · %3")
                    .arg(formatRate(disk.readBytesPerSecond),
                         formatRate(disk.writeBytesPerSecond),
                         disk.filesystem.isEmpty() ? disk.device : disk.filesystem),
                Tone::Muted);
        }
    }
}

void TopTui::Impl::drawResources(const Rect &rect)
{
    const bool focused =
        focusedPanel == Panel::Memory || focusedPanel == Panel::Disk;
    drawBox(rect, QStringLiteral("Resources"), focused);
    if (!hasSnapshot) {
        writeInside(
            rect, 0, QStringLiteral("Waiting for resource data..."), Tone::Muted);
        return;
    }

    const int detailWidth = rect.width >= 48 ? 17 : 0;
    constexpr int labelWidth = 6;
    int line = 0;

    if (snapshot.memory.available && line < rect.height - 2) {
        Tone tone = Tone::Primary;
        if (snapshot.memory.usagePercent
            && *snapshot.memory.usagePercent >= 92.0) {
            tone = Tone::Critical;
        } else if (snapshot.memory.usagePercent
                   && *snapshot.memory.usagePercent >= 80.0) {
            tone = Tone::Warning;
        }
        drawMetricRow(
            rect,
            line++,
            QStringLiteral("RAM"),
            snapshot.memory.usagePercent,
            QStringLiteral("%1/%2")
                .arg(formatBytes(snapshot.memory.usedBytes),
                     formatBytes(snapshot.memory.totalBytes)),
            labelWidth,
            detailWidth,
            tone,
            tone);
    }

    const DiskInfo *primaryDisk = nullptr;
    for (const DiskInfo &disk : std::as_const(snapshot.disks)) {
        if (!primaryDisk)
            primaryDisk = &disk;
        if (disk.mountPoint == QStringLiteral("/")) {
            primaryDisk = &disk;
            break;
        }
    }
    if (primaryDisk && line < rect.height - 2) {
        Tone tone = Tone::Primary;
        if (primaryDisk->usagePercent && *primaryDisk->usagePercent >= 95.0)
            tone = Tone::Critical;
        else if (primaryDisk->usagePercent
                 && *primaryDisk->usagePercent >= 85.0)
            tone = Tone::Warning;
        drawMetricRow(
            rect,
            line++,
            primaryDisk->mountPoint.isEmpty()
                ? QStringLiteral("Disk")
                : primaryDisk->mountPoint,
            primaryDisk->usagePercent,
            QStringLiteral("%1/%2")
                .arg(formatBytes(primaryDisk->usedBytes),
                     formatBytes(primaryDisk->totalBytes)),
            labelWidth,
            detailWidth,
            tone,
            tone);
    }

    if (snapshot.battery.present && line < rect.height - 2) {
        drawMetricRow(
            rect,
            line++,
            QStringLiteral("BAT"),
            snapshot.battery.chargePercent,
            snapshot.battery.status.isEmpty()
                ? QStringLiteral("--")
                : snapshot.battery.status,
            labelWidth,
            detailWidth,
            Tone::Good,
            Tone::Good);
    }
}

QString TopTui::Impl::processLine(const ProcessRow &row, int width) const
{
    const ProcessInfo &process = row.process;
    QString prefix;
    if (treeMode && row.depth > 0) {
        const int visibleDepth = std::min(row.depth, 12);
        prefix = QString(static_cast<qsizetype>(visibleDepth) * 2,
                         QLatin1Char(' '))
            + (unicode ? QStringLiteral("↳ ") : QStringLiteral("`-"));
    }
    if (row.cycle)
        prefix += unicode ? QStringLiteral("⟳ ") : QStringLiteral("! ");
    if (row.depthLimited)
        prefix += unicode ? QStringLiteral("… ") : QStringLiteral("... ");

    QString command = prefix + process.name;
    if (!process.command.isEmpty() && process.command != process.name)
        command += QStringLiteral("  ") + process.command;

    const QString cpu = process.cpuUsagePercent
        ? QString::number(*process.cpuUsagePercent, 'f', 1)
        : QStringLiteral("--");
    const QString memory = process.memoryPercent
        ? QString::number(*process.memoryPercent, 'f', 1)
        : QStringLiteral("--");

    if (width >= 104) {
        const int commandWidth = std::max(8, width - 66);
        return QStringLiteral("%1 %2 %3 %4 %5 %6 %7 %8 %9")
            .arg(fitText(QString::number(process.pid), 7, true),
                 fitText(process.user, 10),
                 fitText(cpu, 6, true),
                 fitText(memory, 6, true),
                 fitText(formatBytes(process.memoryBytes), 9, true),
                 fitText(process.state, 5),
                 fitText(QString::number(process.threadCount), 4, true),
                 fitText(formatDuration(process.runtimeSeconds), 9, true),
                 fitText(command, commandWidth));
    }
    if (width >= 76) {
        const int commandWidth = std::max(8, width - 41);
        return QStringLiteral("%1 %2 %3 %4 %5 %6 %7")
            .arg(fitText(QString::number(process.pid), 7, true),
                 fitText(process.user, 9),
                 fitText(cpu, 6, true),
                 fitText(memory, 6, true),
                 fitText(process.state, 3),
                 fitText(QString::number(process.threadCount), 3, true),
                 fitText(command, commandWidth));
    }

    const int commandWidth = std::max(6, width - 24);
    return QStringLiteral("%1 %2 %3 %4")
        .arg(fitText(QString::number(process.pid), 7, true),
             fitText(cpu, 6, true),
             fitText(memory, 6, true),
             fitText(command, commandWidth));
}

void TopTui::Impl::drawProcesses(const Rect &rect)
{
    if (rect.height < 3 || rect.width < 12)
        return;

    QString title =
        QStringLiteral("Processes %1/%2 · sort %3")
            .arg(processRows.size())
            .arg(hasSnapshot ? snapshot.processes.size() : 0)
            .arg(sortName());
    if (treeMode)
        title += QStringLiteral(" · tree");
    if (!processFilter.isEmpty())
        title += QStringLiteral(" · filter \"%1\"").arg(processFilter);
    drawBox(rect, title, focusedPanel == Panel::Processes);

    const int width = rect.width - 2;
    QString header;
    if (width >= 104) {
        header = QStringLiteral(
            "    PID USER         CPU%   MEM%       RSS STATE  THR      TIME COMMAND");
    } else if (width >= 76) {
        header = QStringLiteral(
            "    PID USER        CPU%   MEM%  S  THR COMMAND");
    } else {
        header = QStringLiteral("    PID   CPU%   MEM% COMMAND");
    }
    writeInside(rect, 0, header, Tone::Muted, A_BOLD, true);

    processPageRows = std::max(1, rect.height - 3);
    ensureSelectionVisible();
    if (processRows.isEmpty()) {
        writeInside(rect,
                    1,
                    processFilter.isEmpty()
                        ? QStringLiteral("No process data available")
                        : QStringLiteral("No processes match the filter"),
                    Tone::Muted);
        return;
    }

    const int end =
        std::min(static_cast<int>(processRows.size()),
                 scrollOffset + processPageRows);
    int outputLine = 1;
    for (int index = scrollOffset; index < end; ++index, ++outputLine) {
        const bool selected = index == selectedIndex;
        const QString marker =
            selected ? (unicode ? QStringLiteral("›") : QStringLiteral(">"))
                     : QStringLiteral(" ");
        const QString line =
            marker + processLine(processRows.at(index), std::max(0, width - 1));
        writeInside(rect,
                    outputLine,
                    line,
                    selected ? Tone::Selected : Tone::Normal,
                    selected ? A_BOLD : A_NORMAL,
                    true);
    }
}

void TopTui::Impl::drawModal()
{
    switch (modal) {
    case Modal::Help:
        drawHelpModal();
        break;
    case Modal::Filter:
        drawFilterModal();
        break;
    case Modal::Details:
        drawDetailsModal();
        break;
    case Modal::SignalChoice:
        drawSignalModal(false);
        break;
    case Modal::SignalKillConfirm:
        drawSignalModal(true);
        break;
    case Modal::None:
        break;
    }
}

void TopTui::Impl::drawHelpModal()
{
    const int width = std::max(20, std::min(columns - 4, 92));
    const int height = std::max(5, std::min(rows - 2, 30));
    const Rect rect{
        std::max(0, (columns - width) / 2),
        std::max(0, (rows - height) / 2),
        std::min(width, columns),
        std::min(height, rows),
    };
    drawBox(rect, QStringLiteral("Help"), true);

    const QStringList lines{
        QStringLiteral("Navigation"),
        QStringLiteral("  Up/Down or k/j       move process selection"),
        QStringLiteral("  PageUp/PageDown      page focused CPU cores, disks, or processes"),
        QStringLiteral("  Tab/Shift+Tab        next/previous metric panel"),
        QStringLiteral("  + / - or header click adjust refresh interval by 250 ms"),
        QStringLiteral(""),
        QStringLiteral("Compute view"),
        QStringLiteral("  g                     cycle CPU and every GPU graph"),
        QStringLiteral("  [ / ]                 previous/next CPU core page"),
        QStringLiteral(""),
        QStringLiteral("Process view"),
        QStringLiteral("  / or f               live process filter; Enter accepts"),
        QStringLiteral("  s sort CPU/memory/PID/name · t toggle process tree"),
        QStringLiteral("  p/Space pause/resume · r sample immediately"),
        QStringLiteral("  Enter                selected process details"),
        QStringLiteral(""),
        QStringLiteral("Signals"),
        QStringLiteral("  K (uppercase)        open confirmation; lowercase k moves up"),
        QStringLiteral("  Enter in confirmation sends the default SIGTERM"),
        QStringLiteral("  K chooses SIGKILL; press uppercase K again to confirm"),
        QStringLiteral(""),
        QStringLiteral("General"),
        QStringLiteral("  ? help   Esc close dialog/mode   q quit (outside filter input)"),
        QStringLiteral(""),
        QStringLiteral("The terminal default background is preserved for transparency."),
        QStringLiteral("NO_COLOR disables color; --ascii disables Unicode glyphs."),
    };

    for (int line = 0;
         line < lines.size() && line < rect.height - 2;
         ++line) {
        Tone tone = Tone::Normal;
        attr_t extra = A_NORMAL;
        if (lines.at(line) == QStringLiteral("Navigation")
            || lines.at(line) == QStringLiteral("Process view")
            || lines.at(line) == QStringLiteral("Compute view")
            || lines.at(line) == QStringLiteral("Signals")
            || lines.at(line) == QStringLiteral("General")) {
            tone = Tone::Primary;
            extra = A_BOLD;
        } else if (lines.at(line).contains(QStringLiteral("SIGKILL"))
                   || lines.at(line).contains(QStringLiteral("uppercase"))) {
            tone = Tone::Warning;
        } else if (lines.at(line).startsWith(QStringLiteral("NO_COLOR"))) {
            tone = Tone::Muted;
        }
        writeInside(rect, line, lines.at(line), tone, extra);
    }
}

void TopTui::Impl::drawFilterModal()
{
    const int width = std::max(20, std::min(columns - 4, 78));
    const int height = std::min(5, rows);
    const Rect rect{
        std::max(0, (columns - width) / 2),
        std::max(0, (rows - height) / 2),
        std::min(width, columns),
        height,
    };
    drawBox(rect, QStringLiteral("Filter processes"), true);

    const QString label = QStringLiteral("Filter: ");
    const int fieldWidth =
        std::max(0, rect.width - 2 - displayWidth(label));
    const QString visible = rightByWidth(filterDraft, fieldWidth);
    writeInside(rect,
                0,
                label + visible,
                Tone::Primary,
                A_BOLD,
                true);
    writeInside(rect,
                1,
                QStringLiteral("Enter apply · Esc restore · Ctrl+U clear"),
                Tone::Muted);

    const int cursorColumn =
        std::clamp(rect.x + 1 + displayWidth(label) + displayWidth(visible),
                   0,
                   std::max(0, columns - 1));
    const int cursorRow =
        std::clamp(rect.y + 1, 0, std::max(0, rows - 1));
    ::move(cursorRow, cursorColumn);
    ::curs_set(1);
}

void TopTui::Impl::drawDetailsModal()
{
    const int width = std::max(24, std::min(columns - 4, 94));
    const int height = std::max(7, std::min(rows - 2, 18));
    const Rect rect{
        std::max(0, (columns - width) / 2),
        std::max(0, (rows - height) / 2),
        std::min(width, columns),
        std::min(height, rows),
    };
    drawBox(rect,
            QStringLiteral("Process %1 · %2")
                .arg(modalProcess.pid)
                .arg(modalProcess.name),
            true);

    int line = 0;
    writeInside(rect,
                line++,
                QStringLiteral("PID %1 · parent %2 · user %3 · state %4")
                    .arg(modalProcess.pid)
                    .arg(modalProcess.ppid)
                    .arg(modalProcess.user, modalProcess.state),
                Tone::Primary,
                A_BOLD);
    writeInside(
        rect,
        line++,
        QStringLiteral("CPU %1 · memory %2 (%3) · threads %4")
            .arg(formatPercent(modalProcess.cpuUsagePercent),
                 formatPercent(modalProcess.memoryPercent),
                 formatBytes(modalProcess.memoryBytes))
            .arg(modalProcess.threadCount));
    writeInside(rect,
                line++,
                QStringLiteral("Runtime %1 · started %2")
                    .arg(formatDuration(modalProcess.runtimeSeconds),
                         modalProcess.startTimeMs > 0
                             ? QDateTime::fromMSecsSinceEpoch(
                                   modalProcess.startTimeMs)
                                   .toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"))
                             : QStringLiteral("--")));
    writeInside(rect,
                line++,
                QStringLiteral("Executable: %1")
                    .arg(modalProcess.executablePath.isEmpty()
                             ? QStringLiteral("--")
                             : modalProcess.executablePath),
                Tone::Muted);
    writeInside(rect, line++, QStringLiteral("Command:"), Tone::Muted, A_BOLD);

    QString remaining =
        modalProcess.command.isEmpty() ? modalProcess.name : modalProcess.command;
    const int commandWidth = std::max(1, rect.width - 4);
    while (!remaining.isEmpty() && line < rect.height - 3) {
        const QString chunk = leftByWidth(remaining, commandWidth);
        if (chunk.isEmpty())
            break;
        writeInside(rect, line++, QStringLiteral("  ") + chunk);
        remaining.remove(0, chunk.size());
    }
    if (!remaining.isEmpty() && line < rect.height - 2)
        writeInside(rect, line++, QStringLiteral("  ..."), Tone::Muted);
    writeInside(rect,
                rect.height - 3,
                QStringLiteral("Esc or Enter closes · q quits key top"),
                Tone::Muted);
}

void TopTui::Impl::drawSignalModal(bool killConfirmation)
{
    const int width = std::max(24, std::min(columns - 4, 74));
    const int height = std::max(7, std::min(rows - 2, 10));
    const Rect rect{
        std::max(0, (columns - width) / 2),
        std::max(0, (rows - height) / 2),
        std::min(width, columns),
        std::min(height, rows),
    };

    if (!killConfirmation) {
        drawBox(rect, QStringLiteral("Confirm process signal"), true);
        writeInside(
            rect,
            0,
            QStringLiteral("Target: %1 (PID %2)").arg(signalName).arg(signalPid),
            Tone::Primary,
            A_BOLD);
        writeInside(rect,
                    2,
                    QStringLiteral("Enter  Send SIGTERM (default, graceful)"),
                    Tone::Warning,
                    A_BOLD);
        writeInside(rect,
                    3,
                    QStringLiteral("K      Choose forceful SIGKILL"),
                    Tone::Critical);
        writeInside(rect,
                    5,
                    QStringLiteral("Esc cancels · q quits key top"),
                    Tone::Muted);
    } else {
        drawBox(rect, QStringLiteral("Confirm SIGKILL · second step"), true);
        writeInside(
            rect,
            0,
            QStringLiteral("Target: %1 (PID %2)").arg(signalName).arg(signalPid),
            Tone::Critical,
            A_BOLD);
        writeInside(rect,
                    2,
                    QStringLiteral("SIGKILL cannot be handled or cleaned up."),
                    Tone::Critical);
        writeInside(rect,
                    3,
                    QStringLiteral("Press uppercase K again to send SIGKILL."),
                    Tone::Critical,
                    A_BOLD);
        writeInside(rect,
                    5,
                    QStringLiteral("Esc cancels · q quits key top"),
                    Tone::Muted);
    }
}

TopTui::TopTui(Sampler &sampler)
    : TopTui(sampler, Options{})
{
}

TopTui::TopTui(Sampler &sampler, const Options &options)
    : m_impl(std::make_unique<Impl>(sampler, options))
{
}

TopTui::~TopTui() = default;

int TopTui::run()
{
    return m_impl->run();
}

QString TopTui::errorMessage() const
{
    return m_impl->error;
}
