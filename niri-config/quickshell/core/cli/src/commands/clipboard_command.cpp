#include "clipboard_command.h"

#include <QBuffer>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStringDecoder>
#include <QUrl>

#include <algorithm>
#include <cstdio>

namespace {

constexpr int Success = 0;
constexpr int UsageError = 2;
constexpr int DependencyFailure = 3;
constexpr int RuntimeFailure = 1;
constexpr int DefaultLimit = 100;
constexpr int MaximumLimit = 500;
constexpr qsizetype MaximumPayloadBytes = 64 * 1024 * 1024;
constexpr qsizetype MaximumSearchTextCharacters = 256 * 1024;
constexpr int MaximumImageDimension = 16384;
constexpr int ThumbnailExtent = 384;

struct ProcessResult {
    bool started = false;
    bool finished = false;
    int exitCode = -1;
    QByteArray standardOutput;
    QByteArray standardError;
};

struct PayloadInspection {
    bool ok = true;
    QString errorCode;
    QString errorMessage;
    QString mimeType;
    QJsonObject json;
    QByteArray restoreBytes;
};

ProcessResult runProcess(const QString &program,
                         const QStringList &arguments,
                         const QByteArray &input = {})
{
    QProcess process;
    process.setProgram(program);
    process.setArguments(arguments);
    process.start();

    ProcessResult result;
    result.started = process.waitForStarted(3000);
    if (!result.started)
        return result;

    if (!input.isNull())
        process.write(input);
    process.closeWriteChannel();
    result.finished = process.waitForFinished(10000);
    if (!result.finished) {
        process.kill();
        process.waitForFinished(1000);
    }

    result.exitCode = process.exitCode();
    result.standardOutput = process.readAllStandardOutput();
    result.standardError = process.readAllStandardError();
    return result;
}

void drainStandardInput()
{
    QFile input;
    if (!input.open(stdin, QIODevice::ReadOnly))
        return;
    QByteArray buffer(64 * 1024, Qt::Uninitialized);
    while (input.read(buffer.data(), buffer.size()) > 0) {
    }
}

QString preferredSelectionMime(const QByteArray &rawTypes)
{
    QStringList types;
    for (const QByteArray &rawType : rawTypes.split('\n')) {
        const QString type = QString::fromUtf8(rawType).trimmed();
        if (!type.isEmpty() && !types.contains(type))
            types.append(type);
    }

    const QStringList preferredImages{
        QStringLiteral("image/png"),
        QStringLiteral("image/jpeg"),
        QStringLiteral("image/webp"),
        QStringLiteral("image/gif"),
    };
    for (const QString &mime : preferredImages) {
        if (types.contains(mime, Qt::CaseInsensitive))
            return mime;
    }

    QStringList supportedImages;
    for (const QByteArray &mime : QImageReader::supportedMimeTypes())
        supportedImages.append(QString::fromLatin1(mime));
    for (const QString &type : types) {
        if (type.startsWith(QStringLiteral("image/"), Qt::CaseInsensitive)
            && supportedImages.contains(type, Qt::CaseInsensitive)) {
            return type;
        }
    }

    const QStringList preferredPlainText{
        QStringLiteral("text/plain;charset=utf-8"),
        QStringLiteral("text/plain;charset=UTF-8"),
        QStringLiteral("text/plain"),
        QStringLiteral("UTF8_STRING"),
    };
    for (const QString &mime : preferredPlainText) {
        if (types.contains(mime, Qt::CaseInsensitive))
            return mime;
    }
    for (const QString &type : types) {
        if (type.startsWith(QStringLiteral("text/plain"),
                            Qt::CaseInsensitive)) {
            return type;
        }
    }
    if (types.contains(QStringLiteral("text/html"), Qt::CaseInsensitive))
        return QStringLiteral("text/html");
    return {};
}

QJsonObject dependencyObject(const QString &cliphist,
                             const QString &wlCopy,
                             const QString &wlPaste = {})
{
    QJsonObject dependencies{
        {QStringLiteral("cliphist"), !cliphist.isEmpty()},
        {QStringLiteral("wlCopy"), !wlCopy.isEmpty()},
    };
    if (!wlPaste.isNull())
        dependencies.insert(QStringLiteral("wlPaste"), !wlPaste.isEmpty());
    return dependencies;
}

QJsonObject errorObject(const QString &code, const QString &message)
{
    return {
        {QStringLiteral("code"), code},
        {QStringLiteral("message"), message},
    };
}

CommandResult resultFor(const QString &command,
                        bool jsonRequested,
                        int exitCode,
                        const QJsonObject &extra,
                        const QString &text,
                        bool textIsError)
{
    QJsonObject json{
        {QStringLiteral("command"), command},
        {QStringLiteral("ok"), exitCode == Success},
    };
    for (auto iterator = extra.constBegin(); iterator != extra.constEnd(); ++iterator)
        json.insert(iterator.key(), iterator.value());
    if (!json.contains(QStringLiteral("error")))
        json.insert(QStringLiteral("error"), QJsonValue(QJsonValue::Null));
    return {exitCode, jsonRequested, json, text, textIsError};
}

CommandResult usageFailure(const QString &message, bool jsonRequested)
{
    return resultFor(
        QStringLiteral("clipboard"),
        jsonRequested,
        UsageError,
        {{QStringLiteral("available"), false},
         {QStringLiteral("error"),
          errorObject(QStringLiteral("usage_error"), message)}},
        message,
        true);
}

bool parseId(const QString &value, QString *normalized)
{
    static const QRegularExpression expression(QStringLiteral("^[1-9][0-9]*$"));
    if (!expression.match(value).hasMatch())
        return false;
    bool ok = false;
    const qulonglong id = value.toULongLong(&ok);
    if (!ok || id == 0)
        return false;
    *normalized = QString::number(id);
    return true;
}

QString dependencyMessage(bool cliphistAvailable, bool wlCopyAvailable)
{
    if (!cliphistAvailable && !wlCopyAvailable)
        return QStringLiteral("cliphist and wl-copy are unavailable");
    if (!cliphistAvailable)
        return QStringLiteral("cliphist is unavailable");
    if (!wlCopyAvailable)
        return QStringLiteral("wl-copy is unavailable");
    return {};
}

bool clipboardWatcherRunning()
{
    const QString overrideValue =
        qEnvironmentVariable("CLAVIS_CLIPBOARD_WATCHER_RUNNING").trimmed();
    if (overrideValue == QStringLiteral("1")
        || overrideValue.compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0)
        return true;
    if (overrideValue == QStringLiteral("0")
        || overrideValue.compare(QStringLiteral("false"), Qt::CaseInsensitive) == 0)
        return false;

    const QDir proc(QStringLiteral("/proc"));
    const QStringList processDirectories =
        proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    static const QRegularExpression numericName(QStringLiteral("^[0-9]+$"));
    for (const QString &directory : processDirectories) {
        if (!numericName.match(directory).hasMatch())
            continue;
        QFile commandLine(proc.filePath(directory + QStringLiteral("/cmdline")));
        if (!commandLine.open(QIODevice::ReadOnly))
            continue;
        const QList<QByteArray> arguments = commandLine.readAll().split('\0');
        bool hasCliphist = false;
        bool hasKey = false;
        bool hasClipboard = false;
        bool hasStore = false;
        for (const QByteArray &argument : arguments) {
            const QString value = QString::fromLocal8Bit(argument);
            hasCliphist = hasCliphist
                || QFileInfo(value).fileName() == QStringLiteral("cliphist");
            hasKey = hasKey || QFileInfo(value).fileName() == QStringLiteral("key");
            hasClipboard = hasClipboard || value == QStringLiteral("clipboard");
            hasStore = hasStore || value == QStringLiteral("store");
        }
        if ((hasCliphist && hasStore)
            || (hasKey && hasClipboard && hasStore))
            return true;
    }
    return false;
}

QString humanBytes(qint64 bytes)
{
    if (bytes < 1024)
        return QStringLiteral("%1 B").arg(bytes);
    if (bytes < 1024 * 1024)
        return QStringLiteral("%1 KB").arg(bytes / 1024.0, 0, 'f', 1);
    return QStringLiteral("%1 MB").arg(bytes / (1024.0 * 1024.0), 0, 'f', 1);
}

QString displayDirectory(const QString &path)
{
    const QString home = QDir::homePath();
    if (path == home)
        return QStringLiteral("~");
    if (path.startsWith(home + QDir::separator()))
        return QStringLiteral("~") + path.sliced(home.size());
    return path;
}

QString sourceLanguage(const QString &suffix)
{
    static const QHash<QString, QString> languages{
        {QStringLiteral("c"), QStringLiteral("C")},
        {QStringLiteral("h"), QStringLiteral("C/C++")},
        {QStringLiteral("cc"), QStringLiteral("C++")},
        {QStringLiteral("cpp"), QStringLiteral("C++")},
        {QStringLiteral("cxx"), QStringLiteral("C++")},
        {QStringLiteral("hpp"), QStringLiteral("C++")},
        {QStringLiteral("rs"), QStringLiteral("Rust")},
        {QStringLiteral("go"), QStringLiteral("Go")},
        {QStringLiteral("py"), QStringLiteral("Python")},
        {QStringLiteral("js"), QStringLiteral("JavaScript")},
        {QStringLiteral("ts"), QStringLiteral("TypeScript")},
        {QStringLiteral("qml"), QStringLiteral("QML")},
        {QStringLiteral("java"), QStringLiteral("Java")},
        {QStringLiteral("kt"), QStringLiteral("Kotlin")},
        {QStringLiteral("sh"), QStringLiteral("Shell")},
    };
    return languages.value(suffix.toLower());
}

QJsonObject fileMetadata(const QUrl &url)
{
    QJsonObject result{
        {QStringLiteral("uri"), url.toString(QUrl::FullyEncoded)},
        {QStringLiteral("local"), url.isLocalFile()},
        {QStringLiteral("exists"), false},
        {QStringLiteral("readable"), false},
        {QStringLiteral("directory"), false},
        {QStringLiteral("byteSize"), 0},
        {QStringLiteral("mimeType"), QString()},
        {QStringLiteral("category"), QStringLiteral("file")},
        {QStringLiteral("icon"), QStringLiteral("file_present")},
        {QStringLiteral("previewUrl"), QString()},
    };
    if (!url.isLocalFile()) {
        result.insert(QStringLiteral("name"),
                      QFileInfo(url.path()).fileName().isEmpty()
                          ? url.fileName() : QFileInfo(url.path()).fileName());
        result.insert(QStringLiteral("parent"), url.adjusted(QUrl::RemoveFilename).toString());
        return result;
    }

    const QFileInfo info(url.toLocalFile());
    result.insert(QStringLiteral("name"), info.fileName());
    result.insert(QStringLiteral("parent"), displayDirectory(info.absolutePath()));
    result.insert(QStringLiteral("exists"), info.exists());
    result.insert(QStringLiteral("readable"), info.isReadable());
    result.insert(QStringLiteral("directory"), info.isDir());
    result.insert(QStringLiteral("byteSize"), info.isFile() ? info.size() : 0);
    if (!info.exists())
        return result;

    if (info.isDir()) {
        result.insert(QStringLiteral("category"), QStringLiteral("folder"));
        result.insert(QStringLiteral("icon"), QStringLiteral("folder"));
        result.insert(QStringLiteral("mimeType"), QStringLiteral("inode/directory"));
        return result;
    }

    const QMimeType mime = QMimeDatabase().mimeTypeForFile(info);
    const QString mimeName = mime.name();
    result.insert(QStringLiteral("mimeType"), mimeName);
    QString category = QStringLiteral("file");
    QString icon = QStringLiteral("file_present");
    if (mimeName.startsWith(QStringLiteral("image/"))) {
        category = QStringLiteral("image");
        icon = QStringLiteral("image");
        if (info.isReadable() && !info.isSymLink())
            result.insert(QStringLiteral("previewUrl"),
                          QUrl::fromLocalFile(info.absoluteFilePath()).toString());
    } else if (mimeName.startsWith(QStringLiteral("video/"))) {
        category = QStringLiteral("video");
        icon = QStringLiteral("video_file");
    } else if (mimeName.startsWith(QStringLiteral("audio/"))) {
        category = QStringLiteral("audio");
        icon = QStringLiteral("audio_file");
    } else if (mimeName == QStringLiteral("application/pdf")) {
        category = QStringLiteral("pdf");
        icon = QStringLiteral("picture_as_pdf");
    } else if (mime.inherits(QStringLiteral("application/zip"))
               || mimeName.contains(QStringLiteral("archive"))
               || mimeName.contains(QStringLiteral("compressed"))) {
        category = QStringLiteral("archive");
        icon = QStringLiteral("archive");
    } else {
        const QString language = sourceLanguage(info.suffix());
        if (!language.isEmpty()) {
            category = QStringLiteral("source-code");
            icon = QStringLiteral("code");
            result.insert(QStringLiteral("language"), language);
        } else if (mimeName.startsWith(QStringLiteral("text/"))) {
            category = QStringLiteral("document");
            icon = QStringLiteral("description");
        }
    }
    result.insert(QStringLiteral("category"), category);
    result.insert(QStringLiteral("icon"), icon);
    return result;
}

QString fileCategoryLabel(const QJsonObject &file)
{
    const QString category = file.value(QStringLiteral("category")).toString();
    if (category == QStringLiteral("folder"))
        return QStringLiteral("文件夹");
    if (category == QStringLiteral("image"))
        return QStringLiteral("图片文件");
    if (category == QStringLiteral("video"))
        return QStringLiteral("视频");
    if (category == QStringLiteral("audio"))
        return QStringLiteral("音频");
    if (category == QStringLiteral("archive"))
        return QStringLiteral("压缩包");
    if (category == QStringLiteral("pdf"))
        return QStringLiteral("PDF");
    if (category == QStringLiteral("source-code"))
        return file.value(QStringLiteral("language")).toString()
            + QStringLiteral(" 源文件");
    if (category == QStringLiteral("document"))
        return QStringLiteral("文档");
    return QStringLiteral("文件");
}

QString cacheDirectory()
{
    QString path = qEnvironmentVariable("CLAVIS_CLIPBOARD_CACHE_DIR").trimmed();
    if (path.isEmpty())
        path = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
            + QStringLiteral("/clavis/clipboard");
    QDir().mkpath(path);
    QFile::setPermissions(
        path,
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    return path;
}

void removeCachedPreview(const QString &id)
{
    QDir directory(cacheDirectory());
    const QStringList matches = directory.entryList(
        {QStringLiteral("entry-%1-*.png").arg(id)}, QDir::Files);
    for (const QString &name : matches)
        directory.remove(name);
}

void clearPreviewCache()
{
    QDir directory(cacheDirectory());
    const QStringList matches =
        directory.entryList({QStringLiteral("entry-*.png")}, QDir::Files);
    for (const QString &name : matches)
        directory.remove(name);
}

QString writeImagePreview(const QString &id,
                          const QByteArray &bytes,
                          QString *errorCode)
{
    QBuffer buffer;
    buffer.setData(bytes);
    buffer.open(QIODevice::ReadOnly);
    QImageReader reader(&buffer);
    reader.setAutoTransform(true);
    const QSize originalSize = reader.size();
    if (!originalSize.isValid()
        || originalSize.width() > MaximumImageDimension
        || originalSize.height() > MaximumImageDimension) {
        *errorCode = QStringLiteral("clipboard_image_decode_failed");
        return {};
    }
    if (originalSize.width() > ThumbnailExtent
        || originalSize.height() > ThumbnailExtent) {
        reader.setScaledSize(originalSize.scaled(
            ThumbnailExtent, ThumbnailExtent, Qt::KeepAspectRatio));
    }
    const QImage image = reader.read();
    if (image.isNull()) {
        *errorCode = QStringLiteral("clipboard_image_decode_failed");
        return {};
    }

    const QByteArray digest =
        QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex().left(16);
    const QString path = QDir(cacheDirectory()).filePath(
        QStringLiteral("entry-%1-%2.png").arg(id, QString::fromLatin1(digest)));
    QSaveFile output(path);
    output.setDirectWriteFallback(false);
    if (!output.open(QIODevice::WriteOnly)
        || !image.save(&output, "PNG")
        || !output.commit()) {
        *errorCode = QStringLiteral("clipboard_preview_failed");
        return {};
    }
    QFile::setPermissions(
        path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return QUrl::fromLocalFile(path).toString();
}

QString sanitizedDisplayLine(QString line)
{
    line = line.trimmed();
    for (QChar &character : line) {
        if (character == QLatin1Char('\t')
            || (character.category() == QChar::Other_Control
                && character != QChar::Null)) {
            character = QLatin1Char(' ');
        }
    }
    return line;
}

struct TextDisplay {
    QString title;
    QString subtitle;
    int lineCount = 0;
    bool multiline = false;
};

TextDisplay textDisplay(const QString &text)
{
    QString normalized = text;
    normalized.replace(QStringLiteral("\r\n"), QStringLiteral("\n"));
    normalized.replace(QLatin1Char('\r'), QLatin1Char('\n'));

    QStringList effectiveLines;
    for (const QString &line : normalized.split(QLatin1Char('\n'))) {
        const QString displayLine = sanitizedDisplayLine(line);
        if (!displayLine.isEmpty())
            effectiveLines.append(displayLine);
    }

    TextDisplay display;
    display.lineCount = effectiveLines.size();
    display.multiline = effectiveLines.size() > 1;
    if (effectiveLines.isEmpty()) {
        display.title = QStringLiteral("空文本");
        display.subtitle = QStringLiteral("文本");
        return display;
    }
    display.title = effectiveLines.first();
    if (effectiveLines.size() == 1) {
        display.subtitle = QStringLiteral("文本");
    } else {
        display.subtitle = effectiveLines.at(1);
        if (effectiveLines.size() > 2)
            display.subtitle.append(QChar(0x2026));
    }
    return display;
}

bool looksLikeHtml(const QString &text)
{
    static const QRegularExpression expression(
        QStringLiteral("^\\s*(?:<!doctype\\b|<html\\b|<meta\\b|<img\\b|<div\\b|<span\\b)"),
        QRegularExpression::CaseInsensitiveOption);
    return expression.match(text).hasMatch();
}

QString decodeHtmlEntities(QString text)
{
    text.replace(QStringLiteral("&lt;"), QStringLiteral("<"),
                 Qt::CaseInsensitive);
    text.replace(QStringLiteral("&gt;"), QStringLiteral(">"),
                 Qt::CaseInsensitive);
    text.replace(QStringLiteral("&quot;"), QStringLiteral("\""),
                 Qt::CaseInsensitive);
    text.replace(QStringLiteral("&apos;"), QStringLiteral("'"),
                 Qt::CaseInsensitive);
    text.replace(QStringLiteral("&#39;"), QStringLiteral("'"),
                 Qt::CaseInsensitive);
    // Decode ampersand last so an encoded "&amp;lt;" is not decoded twice.
    text.replace(QStringLiteral("&amp;"), QStringLiteral("&"),
                 Qt::CaseInsensitive);
    return text;
}

QString htmlImageSource(const QString &html)
{
    static const QRegularExpression imageExpression(
        QStringLiteral("<img\\b[^>]*\\bsrc\\s*=\\s*(['\\\"])(.*?)\\1"),
        QRegularExpression::CaseInsensitiveOption
            | QRegularExpression::DotMatchesEverythingOption);
    return decodeHtmlEntities(
        imageExpression.match(html).captured(2)).trimmed();
}

QString htmlImageAlt(const QString &html)
{
    static const QRegularExpression altExpression(
        QStringLiteral("<img\\b[^>]*\\balt\\s*=\\s*(['\\\"])(.*?)\\1"),
        QRegularExpression::CaseInsensitiveOption
            | QRegularExpression::DotMatchesEverythingOption);
    return sanitizedDisplayLine(decodeHtmlEntities(
        altExpression.match(html).captured(2)));
}

QString htmlPlainText(QString html)
{
    static const QRegularExpression unsafeBlocks(
        QStringLiteral("<(script|style)\\b[^>]*>.*?</\\1\\s*>"),
        QRegularExpression::CaseInsensitiveOption
            | QRegularExpression::DotMatchesEverythingOption);
    static const QRegularExpression lineBreaks(
        QStringLiteral("<(?:br\\s*/?|/p|/div|/li|/h[1-6])\\s*>"),
        QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression tags(QStringLiteral("<[^>]+>"));
    html.remove(unsafeBlocks);
    html.replace(lineBreaks, QStringLiteral("\n"));
    html.remove(tags);
    return decodeHtmlEntities(html).trimmed();
}

QJsonObject basePayload(const QString &id, qsizetype byteSize)
{
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("payloadKind"), QStringLiteral("binary")},
        {QStringLiteral("textSubtype"), QJsonValue(QJsonValue::Null)},
        {QStringLiteral("title"), QStringLiteral("二进制剪贴板")},
        {QStringLiteral("subtitle"), QStringLiteral("未知二进制内容")},
        {QStringLiteral("icon"), QStringLiteral("data_object")},
        {QStringLiteral("preview"), QString()},
        {QStringLiteral("previewUrl"), QString()},
        {QStringLiteral("mimeType"), QString()},
        {QStringLiteral("byteSize"), static_cast<qint64>(byteSize)},
        {QStringLiteral("width"), 0},
        {QStringLiteral("height"), 0},
        {QStringLiteral("fileCount"), 0},
        {QStringLiteral("files"), QJsonArray{}},
        {QStringLiteral("fileOperation"), QJsonValue(QJsonValue::Null)},
        {QStringLiteral("multiline"), false},
        {QStringLiteral("lineCount"), 0},
        {QStringLiteral("restorable"), true},
    };
}

PayloadInspection inspectPayload(const QString &id,
                                 const QByteArray &bytes,
                                 bool createPreview)
{
    PayloadInspection result;
    result.json = basePayload(id, bytes.size());
    if (bytes.size() > MaximumPayloadBytes) {
        result.ok = false;
        result.errorCode = QStringLiteral("clipboard_payload_too_large");
        result.errorMessage = QStringLiteral("Clipboard payload exceeds the safe limit");
        return result;
    }

    QBuffer imageBuffer;
    imageBuffer.setData(bytes);
    imageBuffer.open(QIODevice::ReadOnly);
    QImageReader imageReader(&imageBuffer);
    const QSize imageSize = imageReader.size();
    if (imageSize.isValid() && !imageReader.format().isEmpty()) {
        const QString format = QString::fromLatin1(imageReader.format()).toLower();
        QString mime = QMimeDatabase().mimeTypeForData(bytes).name();
        if (!mime.startsWith(QStringLiteral("image/")))
            mime = QStringLiteral("image/") + (format == QStringLiteral("jpg")
                                               ? QStringLiteral("jpeg") : format);
        result.mimeType = mime;
        result.json.insert(QStringLiteral("payloadKind"), QStringLiteral("image"));
        result.json.insert(QStringLiteral("title"), QStringLiteral("图片剪贴板"));
        result.json.insert(QStringLiteral("subtitle"),
                           QStringLiteral("%1 · %2×%3 · %4")
                               .arg(format.toUpper())
                               .arg(imageSize.width())
                               .arg(imageSize.height())
                               .arg(humanBytes(bytes.size())));
        result.json.insert(QStringLiteral("icon"), QStringLiteral("image"));
        result.json.insert(QStringLiteral("mimeType"), mime);
        result.json.insert(QStringLiteral("format"), format);
        result.json.insert(QStringLiteral("width"), imageSize.width());
        result.json.insert(QStringLiteral("height"), imageSize.height());
        if (createPreview) {
            QString errorCode;
            const QString previewUrl = writeImagePreview(id, bytes, &errorCode);
            if (!previewUrl.isEmpty())
                result.json.insert(QStringLiteral("previewUrl"), previewUrl);
            else
                result.json.insert(QStringLiteral("previewError"), errorCode);
        }
        return result;
    }

    QStringDecoder decoder(QStringDecoder::Utf8);
    QString text = decoder.decode(bytes);
    const bool validText = !decoder.hasError()
        && !text.contains(QChar::Null)
        && std::none_of(text.cbegin(), text.cend(), [](QChar character) {
            return character.category() == QChar::Other_Control
                && character != QLatin1Char('\n')
                && character != QLatin1Char('\r')
                && character != QLatin1Char('\t');
        });

    if (validText) {
        if (looksLikeHtml(text)) {
            const QString source = htmlImageSource(text);
            const QString alt = htmlImageAlt(text);
            if (source.startsWith(QStringLiteral("data:image/"),
                                  Qt::CaseInsensitive)) {
                static const QRegularExpression dataImageExpression(
                    QStringLiteral("^data:(image/(?:png|jpeg|gif|webp));base64,(.+)$"),
                    QRegularExpression::CaseInsensitiveOption
                        | QRegularExpression::DotMatchesEverythingOption);
                const QRegularExpressionMatch match =
                    dataImageExpression.match(source);
                if (match.hasMatch()) {
                    const QByteArray encoded = match.captured(2).toLatin1();
                    const auto decoded = QByteArray::fromBase64Encoding(
                        encoded, QByteArray::AbortOnBase64DecodingErrors);
                    if (decoded
                        && decoded.decoded.size() <= MaximumPayloadBytes) {
                        PayloadInspection embedded = inspectPayload(
                            id, decoded.decoded, createPreview);
                        if (embedded.ok
                            && embedded.json.value(QStringLiteral("payloadKind"))
                                   .toString() == QStringLiteral("image")) {
                            embedded.restoreBytes = decoded.decoded;
                            embedded.json.insert(
                                QStringLiteral("htmlImageFallback"), true);
                            return embedded;
                        }
                    }
                }
            } else {
                const QUrl sourceUrl(source, QUrl::StrictMode);
                if (sourceUrl.isValid() && sourceUrl.isLocalFile()) {
                    const QFileInfo fileInfo(sourceUrl.toLocalFile());
                    if (fileInfo.exists() && fileInfo.isFile()
                        && fileInfo.isReadable() && !fileInfo.isSymLink()
                        && fileInfo.size() <= MaximumPayloadBytes) {
                        QFile imageFile(fileInfo.absoluteFilePath());
                        if (imageFile.open(QIODevice::ReadOnly)) {
                            const QByteArray imageBytes = imageFile.readAll();
                            PayloadInspection localImage = inspectPayload(
                                id, imageBytes, createPreview);
                            if (localImage.ok
                                && localImage.json
                                       .value(QStringLiteral("payloadKind"))
                                       .toString() == QStringLiteral("image")) {
                                localImage.restoreBytes = imageBytes;
                                localImage.json.insert(
                                    QStringLiteral("htmlImageFallback"), true);
                                return localImage;
                            }
                        }
                    }
                }
            }

            const QString readableText = htmlPlainText(text);
            const TextDisplay display = textDisplay(readableText);
            const QUrl sourceUrl(source, QUrl::StrictMode);
            const bool remoteImage = sourceUrl.isValid()
                && (sourceUrl.scheme() == QStringLiteral("http")
                    || sourceUrl.scheme() == QStringLiteral("https")
                    || sourceUrl.scheme() == QStringLiteral("blob"));
            const bool imageWrapper = !source.isEmpty();
            result.mimeType = QStringLiteral("text/html");
            result.json.insert(QStringLiteral("payloadKind"),
                               QStringLiteral("text"));
            result.json.insert(QStringLiteral("textSubtype"),
                               QStringLiteral("plain"));
            result.json.insert(QStringLiteral("mimeType"), result.mimeType);
            result.json.insert(QStringLiteral("htmlFallback"), true);
            result.json.insert(QStringLiteral("icon"),
                               imageWrapper ? QStringLiteral("image")
                                            : QStringLiteral("article"));
            if (!readableText.isEmpty()) {
                result.json.insert(QStringLiteral("title"),
                                   display.title.left(240));
                result.json.insert(QStringLiteral("subtitle"),
                                   display.subtitle.left(300));
                result.json.insert(QStringLiteral("multiline"),
                                   display.multiline);
                result.json.insert(QStringLiteral("lineCount"),
                                   display.lineCount);
                result.json.insert(QStringLiteral("preview"),
                                   readableText.left(4096));
                result.json.insert(QStringLiteral("searchText"),
                                   readableText.left(
                                       MaximumSearchTextCharacters));
            } else if (imageWrapper) {
                const QString host = sourceUrl.host();
                result.json.insert(QStringLiteral("title"),
                                   alt.isEmpty() ? QStringLiteral("图片引用")
                                                 : alt.left(240));
                result.json.insert(
                    QStringLiteral("subtitle"),
                    remoteImage && !host.isEmpty()
                        ? QStringLiteral("远程图片 · %1（未下载）").arg(host)
                        : QStringLiteral("图片内容未提供可持久化像素"));
                result.json.insert(QStringLiteral("preview"), alt.left(4096));
                result.json.insert(QStringLiteral("searchText"),
                                   (alt + QLatin1Char(' ') + host)
                                       .left(MaximumSearchTextCharacters));
            } else {
                result.json.insert(QStringLiteral("title"),
                                   QStringLiteral("HTML 内容"));
                result.json.insert(QStringLiteral("subtitle"),
                                   QStringLiteral("没有可安全显示的正文"));
                result.json.insert(QStringLiteral("preview"), QString());
                result.json.insert(QStringLiteral("searchText"), QString());
            }
            result.json.insert(QStringLiteral("searchTextTruncated"), false);
            return result;
        }

        QStringList rawLines = text.split(QLatin1Char('\n'));
        while (!rawLines.isEmpty() && rawLines.last().trimmed().isEmpty())
            rawLines.removeLast();
        QString operation;
        int firstUriLine = 0;
        if (!rawLines.isEmpty()
            && (rawLines.first() == QStringLiteral("copy")
                || rawLines.first() == QStringLiteral("cut"))) {
            operation = rawLines.first();
            firstUriLine = 1;
        }

        QList<QUrl> urls;
        bool fileList = rawLines.size() > firstUriLine;
        for (int index = firstUriLine; index < rawLines.size(); ++index) {
            const QString line = rawLines.at(index).trimmed();
            if (line.isEmpty() || (operation.isEmpty() && line.startsWith(QLatin1Char('#'))))
                continue;
            QUrl url;
            if (line.startsWith(QStringLiteral("file://")))
                url = QUrl(line, QUrl::StrictMode);
            else if (operation.isEmpty()
                     && QDir::isAbsolutePath(line)
                     && QFileInfo::exists(line))
                url = QUrl::fromLocalFile(line);
            if (!url.isValid() || !url.isLocalFile()) {
                fileList = false;
                break;
            }
            urls.append(url);
        }
        fileList = fileList && !urls.isEmpty();
        if (fileList) {
            QJsonArray files;
            QStringList names;
            for (const QUrl &url : urls) {
                const QJsonObject file = fileMetadata(url);
                files.append(file);
                if (names.size() < 3)
                    names.append(file.value(QStringLiteral("name")).toString());
            }
            const bool multiple = files.size() > 1;
            const QJsonObject first = files.first().toObject();
            result.mimeType = operation.isEmpty()
                ? QStringLiteral("text/uri-list")
                : QStringLiteral("x-special/gnome-copied-files");
            result.json.insert(QStringLiteral("payloadKind"),
                               multiple ? QStringLiteral("file-list")
                                        : QStringLiteral("file"));
            result.json.insert(QStringLiteral("mimeType"), result.mimeType);
            result.json.insert(QStringLiteral("files"), files);
            result.json.insert(QStringLiteral("fileCount"), files.size());
            result.json.insert(QStringLiteral("fileOperation"),
                               operation.isEmpty()
                                   ? QJsonValue(QJsonValue::Null)
                                   : QJsonValue(operation));
            result.json.insert(QStringLiteral("icon"),
                               multiple ? QStringLiteral("file_copy")
                                        : first.value(QStringLiteral("icon")));
            result.json.insert(QStringLiteral("previewUrl"),
                               multiple ? QString()
                                        : first.value(QStringLiteral("previewUrl")).toString());
            if (multiple) {
                result.json.insert(QStringLiteral("title"),
                                   QStringLiteral("%1 个文件").arg(files.size()));
                result.json.insert(QStringLiteral("subtitle"),
                                   names.join(QStringLiteral("、"))
                                       + (files.size() > 3 ? QStringLiteral("…") : QString()));
            } else {
                result.json.insert(QStringLiteral("title"),
                                   first.value(QStringLiteral("name")).toString());
                QStringList details{
                    fileCategoryLabel(first),
                    first.value(QStringLiteral("parent")).toString(),
                };
                if (first.value(QStringLiteral("byteSize")).toInteger() > 0)
                    details.append(humanBytes(
                        first.value(QStringLiteral("byteSize")).toInteger()));
                result.json.insert(QStringLiteral("subtitle"),
                                   details.join(QStringLiteral(" · ")));
            }
            return result;
        }

        const QString trimmed = text.trimmed();
        const QUrl url(trimmed, QUrl::StrictMode);
        QString subtype = QStringLiteral("plain");
        QString icon = QStringLiteral("content_paste");
        const TextDisplay display = textDisplay(text);
        QString title = display.title;
        QString subtitle = display.subtitle;
        if (!trimmed.contains(QRegularExpression(QStringLiteral("\\s")))
            && url.isValid() && !url.scheme().isEmpty()
            && (url.scheme() == QStringLiteral("http")
                || url.scheme() == QStringLiteral("https"))) {
            subtype = QStringLiteral("url");
            icon = QStringLiteral("link");
            title = url.host().isEmpty() ? trimmed : url.host();
            subtitle = trimmed;
        }
        result.mimeType = QStringLiteral("text/plain;charset=utf-8");
        result.json.insert(QStringLiteral("payloadKind"), QStringLiteral("text"));
        result.json.insert(QStringLiteral("textSubtype"), subtype);
        result.json.insert(QStringLiteral("mimeType"), result.mimeType);
        result.json.insert(QStringLiteral("icon"), icon);
        result.json.insert(QStringLiteral("title"),
                           title.isEmpty() ? QStringLiteral("空文本") : title.left(240));
        result.json.insert(QStringLiteral("subtitle"), subtitle.left(300));
        result.json.insert(QStringLiteral("multiline"), display.multiline);
        result.json.insert(QStringLiteral("lineCount"), display.lineCount);
        result.json.insert(QStringLiteral("preview"), text.left(4096));
        result.json.insert(QStringLiteral("searchText"),
                           text.left(MaximumSearchTextCharacters));
        result.json.insert(QStringLiteral("searchTextTruncated"),
                           text.size() > MaximumSearchTextCharacters);
        return result;
    }

    const QString detectedMime = QMimeDatabase().mimeTypeForData(bytes).name();
    if (!detectedMime.isEmpty()
        && detectedMime != QStringLiteral("application/octet-stream")) {
        result.mimeType = detectedMime;
        result.json.insert(QStringLiteral("mimeType"), detectedMime);
        result.json.insert(QStringLiteral("subtitle"),
                           detectedMime + QStringLiteral(" · ") + humanBytes(bytes.size()));
    } else {
        result.json.insert(QStringLiteral("subtitle"),
                           QStringLiteral("未知二进制 · ") + humanBytes(bytes.size()));
    }
    return result;
}

QJsonObject lightweightEntry(const QByteArray &line)
{
    const qsizetype separator = line.indexOf('\t');
    if (separator <= 0)
        return {};
    const QString id = QString::fromUtf8(line.first(separator));
    QString normalizedId;
    if (!parseId(id, &normalizedId))
        return {};
    const QString preview = QString::fromUtf8(line.sliced(separator + 1));
    QJsonObject entry = basePayload(normalizedId, 0);
    const bool html = looksLikeHtml(preview);
    const bool htmlImage = html && !htmlImageSource(preview).isEmpty();
    const TextDisplay display = textDisplay(preview);
    entry.insert(QStringLiteral("preview"), html ? QString() : preview);
    entry.insert(QStringLiteral("title"),
                 htmlImage ? QStringLiteral("图片引用")
                           : html ? QStringLiteral("HTML 内容")
                                  : display.title);
    entry.insert(QStringLiteral("subtitle"),
                 html ? QStringLiteral("正在检查内容") : display.subtitle);
    entry.insert(QStringLiteral("payloadKind"), QStringLiteral("text"));
    entry.insert(QStringLiteral("textSubtype"), QStringLiteral("plain"));
    entry.insert(QStringLiteral("mimeType"), QStringLiteral("text/plain;charset=utf-8"));
    entry.insert(QStringLiteral("icon"),
                 htmlImage ? QStringLiteral("image")
                           : html ? QStringLiteral("article")
                                  : QStringLiteral("content_paste"));
    entry.insert(QStringLiteral("multiline"), display.multiline);
    entry.insert(QStringLiteral("lineCount"), display.lineCount);

    static const QRegularExpression imageExpression(
        QStringLiteral("^\\[\\[ binary data ([0-9.]+ [A-Za-z]+) ([^ ]+) ([0-9]+)x([0-9]+) \\]\\]$"));
    const QRegularExpressionMatch imageMatch = imageExpression.match(preview);
    if (imageMatch.hasMatch()) {
        const QString format = imageMatch.captured(2).toLower();
        entry.insert(QStringLiteral("payloadKind"), QStringLiteral("image"));
        entry.insert(QStringLiteral("textSubtype"), QJsonValue(QJsonValue::Null));
        entry.insert(QStringLiteral("title"), QStringLiteral("图片剪贴板"));
        entry.insert(QStringLiteral("subtitle"),
                     QStringLiteral("%1 · %2×%3")
                         .arg(format.toUpper())
                         .arg(imageMatch.captured(3))
                         .arg(imageMatch.captured(4)));
        entry.insert(QStringLiteral("icon"), QStringLiteral("image"));
        entry.insert(QStringLiteral("format"), format);
        entry.insert(QStringLiteral("mimeType"),
                     QStringLiteral("image/") + (format == QStringLiteral("jpg")
                                                ? QStringLiteral("jpeg") : format));
        entry.insert(QStringLiteral("width"), imageMatch.captured(3).toInt());
        entry.insert(QStringLiteral("height"), imageMatch.captured(4).toInt());
    } else if (preview.contains(QChar::ReplacementCharacter)) {
        entry.insert(QStringLiteral("payloadKind"), QStringLiteral("binary"));
        entry.insert(QStringLiteral("textSubtype"), QJsonValue(QJsonValue::Null));
        entry.insert(QStringLiteral("title"), QStringLiteral("二进制剪贴板"));
        entry.insert(QStringLiteral("subtitle"), QStringLiteral("按需检查内容"));
        entry.insert(QStringLiteral("icon"), QStringLiteral("data_object"));
        entry.insert(QStringLiteral("mimeType"), QString());
    }
    return entry;
}

ProcessResult decodeEntry(const QString &cliphist, const QString &id)
{
    // cliphist parses stdin as an exact decimal token. A trailing newline makes
    // current cliphist releases reject the otherwise valid entry ID.
    return runProcess(cliphist, {QStringLiteral("decode")}, id.toUtf8());
}

bool consumeJsonOptions(const QStringList &arguments,
                        int start,
                        QString *invalid)
{
    for (int index = start; index < arguments.size(); ++index) {
        const QString argument = arguments.at(index);
        if (argument == QStringLiteral("--json"))
            continue;
        if (argument == QStringLiteral("--format")
            && arguments.value(index + 1) == QStringLiteral("json")) {
            ++index;
            continue;
        }
        *invalid = argument;
        return false;
    }
    return true;
}

} // namespace

CommandResult ClipboardCommand::run(const QStringList &arguments) const
{
    const bool jsonRequested =
        arguments.contains(QStringLiteral("--json"))
        || (arguments.contains(QStringLiteral("--format"))
            && arguments.value(arguments.indexOf(QStringLiteral("--format")) + 1)
                == QStringLiteral("json"));
    if (arguments.isEmpty())
        return usageFailure(QStringLiteral("Missing clipboard subcommand"), jsonRequested);

    const QString subcommand = arguments.first();
    const QString cliphist = QStandardPaths::findExecutable(QStringLiteral("cliphist"));
    const QString wlCopy = QStandardPaths::findExecutable(QStringLiteral("wl-copy"));
    const QString wlPaste = QStandardPaths::findExecutable(QStringLiteral("wl-paste"));
    const bool cliphistAvailable = !cliphist.isEmpty();
    const bool wlCopyAvailable = !wlCopy.isEmpty();
    const bool watcherRunning = cliphistAvailable && clipboardWatcherRunning();
    const QJsonObject dependencies = dependencyObject(cliphist, wlCopy, wlPaste);
    const QJsonObject capabilities{
        {QStringLiteral("inspect"), true},
        {QStringLiteral("preview"), true},
        {QStringLiteral("mimeRestore"), true},
        {QStringLiteral("mimeAwareStore"), true},
    };

    if (subcommand == QStringLiteral("store")) {
        QString invalid;
        if (!consumeJsonOptions(arguments, 1, &invalid))
            return usageFailure(
                QStringLiteral("Unknown clipboard store option: %1").arg(invalid),
                jsonRequested);

        // wl-paste --watch supplies the event payload on stdin. Drain it so a
        // large selection cannot block the watcher pipe while this command
        // requests one explicitly selected MIME from the compositor.
        drainStandardInput();
        if (qEnvironmentVariable("CLIPBOARD_STATE").compare(
                QStringLiteral("sensitive"), Qt::CaseInsensitive) == 0) {
            return resultFor(
                QStringLiteral("clipboard.store"), jsonRequested, Success,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("stored"), false},
                 {QStringLiteral("skippedSensitive"), true},
                 {QStringLiteral("dependencies"), dependencies}},
                QStringLiteral("Sensitive clipboard entry skipped"), false);
        }
        if (!cliphistAvailable || wlPaste.isEmpty()) {
            const QString code = !cliphistAvailable
                ? QStringLiteral("cliphist_unavailable")
                : QStringLiteral("wl_paste_unavailable");
            const QString message = !cliphistAvailable
                ? QStringLiteral("cliphist is unavailable")
                : QStringLiteral("wl-paste is unavailable");
            return resultFor(
                QStringLiteral("clipboard.store"), jsonRequested,
                DependencyFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("stored"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"), errorObject(code, message)}},
                message, true);
        }

        const ProcessResult listTypes = runProcess(
            wlPaste, {QStringLiteral("--list-types")});
        const QString selectedMime = listTypes.started && listTypes.finished
            && listTypes.exitCode == 0
            ? preferredSelectionMime(listTypes.standardOutput) : QString();
        if (selectedMime.isEmpty()) {
            const QString message =
                QStringLiteral("Clipboard selection has no supported image or text MIME");
            return resultFor(
                QStringLiteral("clipboard.store"), jsonRequested,
                RuntimeFailure,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("stored"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"), errorObject(
                      QStringLiteral("clipboard_mime_unsupported"), message)}},
                message, true);
        }

        const ProcessResult selection = runProcess(
            wlPaste, {QStringLiteral("--type"), selectedMime});
        if (!selection.started || !selection.finished
            || selection.exitCode != 0
            || selection.standardOutput.size() > MaximumPayloadBytes) {
            const bool tooLarge =
                selection.standardOutput.size() > MaximumPayloadBytes;
            const QString message = tooLarge
                ? QStringLiteral("Clipboard payload exceeds the safe limit")
                : QStringLiteral("Unable to read the selected clipboard MIME");
            return resultFor(
                QStringLiteral("clipboard.store"), jsonRequested,
                RuntimeFailure,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("stored"), false},
                 {QStringLiteral("selectedMime"), selectedMime},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"), errorObject(
                      tooLarge ? QStringLiteral("clipboard_payload_too_large")
                               : QStringLiteral("clipboard_read_failed"),
                      message)}},
                message, true);
        }
        const ProcessResult store = runProcess(
            cliphist, {QStringLiteral("store")}, selection.standardOutput);
        const bool stored = store.started && store.finished
            && store.exitCode == 0;
        const QString message = stored
            ? QStringLiteral("Clipboard entry stored")
            : QStringLiteral("Unable to store clipboard entry");
        return resultFor(
            QStringLiteral("clipboard.store"), jsonRequested,
            stored ? Success : RuntimeFailure,
            {{QStringLiteral("available"), true},
             {QStringLiteral("stored"), stored},
             {QStringLiteral("selectedMime"), selectedMime},
             {QStringLiteral("dependencies"), dependencies},
             {QStringLiteral("exitCode"), store.exitCode},
             {QStringLiteral("error"),
              stored ? QJsonValue(QJsonValue::Null)
                     : QJsonValue(errorObject(
                           QStringLiteral("cliphist_store_failed"), message))}},
            message, !stored);
    }

    if (subcommand == QStringLiteral("status")) {
        QString invalid;
        if (!consumeJsonOptions(arguments, 1, &invalid))
            return usageFailure(
                QStringLiteral("Unknown clipboard status option: %1").arg(invalid),
                jsonRequested);
        const bool dependenciesAvailable = cliphistAvailable && wlCopyAvailable;
        const bool available = dependenciesAvailable && watcherRunning;
        const QString message = !dependenciesAvailable
            ? dependencyMessage(cliphistAvailable, wlCopyAvailable)
            : watcherRunning ? QString()
                             : QStringLiteral("cliphist watcher is inactive");
        return resultFor(
            QStringLiteral("clipboard.status"), jsonRequested,
            available ? Success : DependencyFailure,
            {{QStringLiteral("available"), available},
             {QStringLiteral("canList"), cliphistAvailable},
             {QStringLiteral("canRestore"), dependenciesAvailable},
             {QStringLiteral("watcherRunning"), watcherRunning},
             {QStringLiteral("dependencies"), dependencies},
             {QStringLiteral("capabilities"), capabilities},
             {QStringLiteral("error"),
              available ? QJsonValue(QJsonValue::Null)
                        : QJsonValue(errorObject(
                              dependenciesAvailable
                                  ? QStringLiteral("cliphist_watcher_inactive")
                                  : !cliphistAvailable
                                      ? QStringLiteral("cliphist_unavailable")
                                      : QStringLiteral("wl_copy_unavailable"),
                              message))}},
            available ? QStringLiteral("available") : message, !available);
    }

    if (subcommand == QStringLiteral("list")) {
        int limit = DefaultLimit;
        for (int index = 1; index < arguments.size(); ++index) {
            const QString argument = arguments.at(index);
            if (argument == QStringLiteral("--json"))
                continue;
            if (argument == QStringLiteral("--format")
                && arguments.value(index + 1) == QStringLiteral("json")) {
                ++index;
                continue;
            }
            if (argument == QStringLiteral("--limit") && index + 1 < arguments.size()) {
                bool ok = false;
                limit = arguments.at(++index).toInt(&ok);
                if (!ok || limit < 1 || limit > MaximumLimit)
                    return usageFailure(
                        QStringLiteral("Clipboard limit must be between 1 and %1")
                            .arg(MaximumLimit),
                        jsonRequested);
                continue;
            }
            return usageFailure(
                QStringLiteral("Unknown or incomplete clipboard list option: %1")
                    .arg(argument), jsonRequested);
        }
        if (!cliphistAvailable) {
            const QString message = dependencyMessage(false, wlCopyAvailable);
            return resultFor(
                QStringLiteral("clipboard.list"), jsonRequested, DependencyFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("canList"), false},
                 {QStringLiteral("canRestore"), false},
                 {QStringLiteral("watcherRunning"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("capabilities"), capabilities},
                 {QStringLiteral("entries"), QJsonArray{}},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("cliphist_unavailable"), message)}},
                message, true);
        }

        const ProcessResult process = runProcess(cliphist, {QStringLiteral("list")});
        if (!process.started || !process.finished || process.exitCode != 0) {
            const QString message = QStringLiteral("Unable to read clipboard history");
            return resultFor(
                QStringLiteral("clipboard.list"), jsonRequested, RuntimeFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("canList"), false},
                 {QStringLiteral("canRestore"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("capabilities"), capabilities},
                 {QStringLiteral("entries"), QJsonArray{}},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("cliphist_list_failed"), message)}},
                message, true);
        }
        QJsonArray entries;
        for (const QByteArray &rawLine : process.standardOutput.split('\n')) {
            if (rawLine.isEmpty() || entries.size() >= limit)
                continue;
            const QJsonObject entry = lightweightEntry(rawLine);
            if (!entry.isEmpty())
                entries.append(entry);
        }
        const bool canRestore = wlCopyAvailable;
        const bool inactiveAndEmpty = entries.isEmpty() && !watcherRunning;
        const QString message = inactiveAndEmpty
            ? QStringLiteral("cliphist watcher is inactive") : QString();
        return resultFor(
            QStringLiteral("clipboard.list"), jsonRequested,
            inactiveAndEmpty ? DependencyFailure : Success,
            {{QStringLiteral("available"), canRestore},
             {QStringLiteral("canList"), true},
             {QStringLiteral("canRestore"), canRestore},
             {QStringLiteral("watcherRunning"), watcherRunning},
             {QStringLiteral("dependencies"), dependencies},
             {QStringLiteral("capabilities"), capabilities},
             {QStringLiteral("entries"), entries},
             {QStringLiteral("error"),
              inactiveAndEmpty
                  ? QJsonValue(errorObject(
                        QStringLiteral("cliphist_watcher_inactive"), message))
                  : QJsonValue(QJsonValue::Null)}},
            inactiveAndEmpty
                ? message
                : QStringLiteral("%1 clipboard entries").arg(entries.size()),
            inactiveAndEmpty);
    }

    if (subcommand == QStringLiteral("inspect")
        || subcommand == QStringLiteral("preview")) {
        if (arguments.size() < 2)
            return usageFailure(QStringLiteral("Missing clipboard entry id"),
                                jsonRequested);
        QString id;
        if (!parseId(arguments.at(1), &id))
            return usageFailure(
                QStringLiteral("Clipboard entry id must be a positive decimal integer"),
                jsonRequested);
        QString invalid;
        if (!consumeJsonOptions(arguments, 2, &invalid))
            return usageFailure(
                QStringLiteral("Unknown clipboard %1 option: %2")
                    .arg(subcommand, invalid), jsonRequested);
        if (!cliphistAvailable) {
            const QString message = dependencyMessage(false, wlCopyAvailable);
            return resultFor(
                QStringLiteral("clipboard.") + subcommand, jsonRequested,
                DependencyFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("id"), id},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("cliphist_unavailable"), message)}},
                message, true);
        }
        const ProcessResult decode = decodeEntry(cliphist, id);
        if (!decode.started || !decode.finished || decode.exitCode != 0) {
            const QString message = QStringLiteral("Unable to decode clipboard entry");
            return resultFor(
                QStringLiteral("clipboard.") + subcommand, jsonRequested,
                RuntimeFailure,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("id"), id},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("exitCode"), decode.exitCode},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("clipboard_inspect_failed"), message)}},
                message, true);
        }
        PayloadInspection inspection =
            inspectPayload(id, decode.standardOutput, true);
        if (!inspection.ok) {
            return resultFor(
                QStringLiteral("clipboard.") + subcommand, jsonRequested,
                RuntimeFailure,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("id"), id},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"),
                  errorObject(inspection.errorCode, inspection.errorMessage)}},
                inspection.errorMessage, true);
        }
        QJsonObject extra = inspection.json;
        extra.insert(QStringLiteral("available"), true);
        extra.insert(QStringLiteral("dependencies"), dependencies);
        return resultFor(
            QStringLiteral("clipboard.") + subcommand, jsonRequested, Success,
            extra, QStringLiteral("Clipboard entry inspected"), false);
    }

    if (subcommand == QStringLiteral("clear")) {
        QString invalid;
        if (!consumeJsonOptions(arguments, 1, &invalid))
            return usageFailure(
                QStringLiteral("Unknown clipboard clear option: %1").arg(invalid),
                jsonRequested);
        if (!cliphistAvailable) {
            const QString message = dependencyMessage(false, wlCopyAvailable);
            return resultFor(
                QStringLiteral("clipboard.clear"), jsonRequested, DependencyFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("cliphist_unavailable"), message)}},
                message, true);
        }
        const ProcessResult process = runProcess(cliphist, {QStringLiteral("wipe")});
        const bool ok = process.started && process.finished && process.exitCode == 0;
        if (ok)
            clearPreviewCache();
        const QString message = ok ? QStringLiteral("Clipboard history cleared")
                                   : QStringLiteral("Unable to clear clipboard history");
        return resultFor(
            QStringLiteral("clipboard.clear"), jsonRequested,
            ok ? Success : RuntimeFailure,
            {{QStringLiteral("available"), true},
             {QStringLiteral("dependencies"), dependencies},
             {QStringLiteral("exitCode"), process.exitCode},
             {QStringLiteral("error"),
              ok ? QJsonValue(QJsonValue::Null)
                 : QJsonValue(errorObject(
                       QStringLiteral("cliphist_clear_failed"), message))}},
            message, !ok);
    }

    if (subcommand == QStringLiteral("restore")
        || subcommand == QStringLiteral("delete")) {
        if (arguments.size() < 2)
            return usageFailure(QStringLiteral("Missing clipboard entry id"),
                                jsonRequested);
        QString id;
        if (!parseId(arguments.at(1), &id))
            return usageFailure(
                QStringLiteral("Clipboard entry id must be a positive decimal integer"),
                jsonRequested);
        QString invalid;
        if (!consumeJsonOptions(arguments, 2, &invalid))
            return usageFailure(
                QStringLiteral("Unknown clipboard %1 option: %2")
                    .arg(subcommand, invalid), jsonRequested);
        const bool dependenciesAvailable =
            cliphistAvailable
            && (subcommand != QStringLiteral("restore") || wlCopyAvailable);
        if (!dependenciesAvailable) {
            const QString message = dependencyMessage(
                cliphistAvailable, wlCopyAvailable);
            const QString code = !cliphistAvailable
                ? QStringLiteral("cliphist_unavailable")
                : QStringLiteral("wl_copy_unavailable");
            return resultFor(
                QStringLiteral("clipboard.") + subcommand, jsonRequested,
                DependencyFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("id"), id},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"), errorObject(code, message)}},
                message, true);
        }

        const QByteArray idInput = id.toUtf8();
        if (subcommand == QStringLiteral("delete")) {
            const ProcessResult process =
                runProcess(cliphist, {QStringLiteral("delete")}, idInput);
            const bool ok =
                process.started && process.finished && process.exitCode == 0;
            if (ok)
                removeCachedPreview(id);
            const QString message = ok ? QStringLiteral("Clipboard entry deleted")
                                       : QStringLiteral("Unable to delete clipboard entry");
            return resultFor(
                QStringLiteral("clipboard.delete"), jsonRequested,
                ok ? Success : RuntimeFailure,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("id"), id},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("exitCode"), process.exitCode},
                 {QStringLiteral("error"),
                  ok ? QJsonValue(QJsonValue::Null)
                     : QJsonValue(errorObject(
                           QStringLiteral("cliphist_delete_failed"), message))}},
                message, !ok);
        }

        const ProcessResult decode = decodeEntry(cliphist, id);
        if (!decode.started || !decode.finished || decode.exitCode != 0) {
            const QString message = QStringLiteral("Unable to decode clipboard entry");
            return resultFor(
                QStringLiteral("clipboard.restore"), jsonRequested, RuntimeFailure,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("id"), id},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("exitCode"), decode.exitCode},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("cliphist_decode_failed"), message)}},
                message, true);
        }
        PayloadInspection inspection =
            inspectPayload(id, decode.standardOutput, false);
        if (!inspection.ok) {
            return resultFor(
                QStringLiteral("clipboard.restore"), jsonRequested, RuntimeFailure,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("id"), id},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"),
                  errorObject(inspection.errorCode, inspection.errorMessage)}},
                inspection.errorMessage, true);
        }
        QStringList copyArguments;
        if (!inspection.mimeType.isEmpty())
            copyArguments << QStringLiteral("--type") << inspection.mimeType;
        const QByteArray &restoreBytes = inspection.restoreBytes.isNull()
            ? decode.standardOutput : inspection.restoreBytes;
        const ProcessResult copy =
            runProcess(wlCopy, copyArguments, restoreBytes);
        const bool ok = copy.started && copy.finished && copy.exitCode == 0;
        const QString message = ok ? QStringLiteral("Clipboard entry restored")
                                   : QStringLiteral("Unable to write clipboard entry");
        return resultFor(
            QStringLiteral("clipboard.restore"), jsonRequested,
            ok ? Success : RuntimeFailure,
            {{QStringLiteral("available"), true},
             {QStringLiteral("id"), id},
             {QStringLiteral("payloadKind"),
              inspection.json.value(QStringLiteral("payloadKind"))},
             {QStringLiteral("mimeType"), inspection.mimeType},
             {QStringLiteral("dependencies"), dependencies},
             {QStringLiteral("exitCode"), copy.exitCode},
             {QStringLiteral("error"),
              ok ? QJsonValue(QJsonValue::Null)
                 : QJsonValue(errorObject(
                       QStringLiteral("wl_copy_failed"), message))}},
            message, !ok);
    }

    return usageFailure(
        QStringLiteral("Unknown clipboard command: %1").arg(subcommand),
        jsonRequested);
}
