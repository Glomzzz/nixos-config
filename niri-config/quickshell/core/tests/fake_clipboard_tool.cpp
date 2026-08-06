#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QUrl>

#include <cstdio>

namespace {

bool appendTrace(const QByteArray &value)
{
    const QString path =
        qEnvironmentVariable("CLAVIS_TEST_CLIPBOARD_TRACE");
    if (path.isEmpty())
        return true;
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append))
        return false;
    return file.write(value) == value.size();
}

QByteArray readStdin()
{
    QFile input;
    if (!input.open(stdin, QIODevice::ReadOnly))
        return {};
    return input.readAll();
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);
    const QString executable =
        QFileInfo(QCoreApplication::applicationFilePath()).fileName();

    if (executable == QStringLiteral("wl-copy")) {
        const QByteArray input = readStdin();
        const QString argumentsPath =
            qEnvironmentVariable("CLAVIS_TEST_WL_COPY_ARGUMENTS");
        if (!argumentsPath.isEmpty()) {
            QFile argumentsFile(argumentsPath);
            if (!argumentsFile.open(QIODevice::WriteOnly))
                return 1;
            argumentsFile.write(
                application.arguments().mid(1).join(QLatin1Char('\n')).toUtf8());
        }
        if (qEnvironmentVariableIsSet("CLAVIS_TEST_WL_COPY_FAIL"))
            return 1;
        return appendTrace(QByteArrayLiteral("copy:") + input) ? 0 : 1;
    }

    if (executable == QStringLiteral("wl-paste")) {
        const QStringList arguments = application.arguments().mid(1);
        if (arguments.contains(QStringLiteral("--list-types"))) {
            const QByteArray types = qgetenv("CLAVIS_TEST_SELECTION_TYPES");
            const QByteArray output = types.isEmpty()
                ? QByteArrayLiteral("text/plain;charset=utf-8\ntext/html\n")
                : types;
            fwrite(output.constData(), 1,
                   static_cast<size_t>(output.size()), stdout);
            return 0;
        }
        const int typeIndex = arguments.indexOf(QStringLiteral("--type"));
        if (typeIndex >= 0 && typeIndex + 1 < arguments.size()) {
            const QString mime = arguments.at(typeIndex + 1);
            QByteArray payload;
            if (mime.startsWith(QStringLiteral("image/"))) {
                payload = QByteArray::fromBase64(
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC"
                    "AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=");
            } else if (mime == QStringLiteral("text/html")) {
                payload = qgetenv("CLAVIS_TEST_SELECTION_HTML");
                if (payload.isEmpty())
                    payload = QByteArrayLiteral("<meta><img src=\"https://example.com/a.png\">");
            } else {
                payload = qgetenv("CLAVIS_TEST_SELECTION_TEXT");
                if (payload.isEmpty())
                    payload = QByteArrayLiteral("plain selection");
            }
            fwrite(payload.constData(), 1,
                   static_cast<size_t>(payload.size()), stdout);
            return 0;
        }
        return 2;
    }

    const QStringList arguments = application.arguments().mid(1);
    const QString command = arguments.value(0);
    if (command == QStringLiteral("list")) {
        QTextStream(stdout)
            << "9\talpha beta\n"
            << "8\t[[ binary data 68 B png 1x1 ]]\n"
            << "7\tfile reference\n"
            << "6\tmultiple files\n"
            << "12\t<meta><img src=\"https://example.com/a.png\">\n"
            << "13\t床前明月光，\n";
        return 0;
    }
    if (command == QStringLiteral("decode")) {
        if (qEnvironmentVariableIsSet("CLAVIS_TEST_CLIPHIST_DECODE_FAIL"))
            return 1;
        const QByteArray id = readStdin();
        const QString root = qEnvironmentVariable("CLAVIS_TEST_FILE_ROOT");
        QByteArray payload;
        if (id == QByteArrayLiteral("16")) {
            payload = QByteArrayLiteral("Hello world");
        } else if (id == QByteArrayLiteral("15")) {
            payload = QByteArrayLiteral(
                "# heading\n"
                "const value = items.map(item => {\n"
                "  return item.id;\n"
                "});\n");
        } else if (id == QByteArrayLiteral("14")) {
            payload = QByteArrayLiteral(
                "\n\t  first line  \n\n\tsecond\tline\n\nthird\n\n");
        } else if (id == QByteArrayLiteral("13")) {
            payload = QByteArrayLiteral(
                "床前明月光，\n"
                "疑是地上霜。\n"
                "举头望明月，\n"
                "低头思故乡。");
        } else if (id == QByteArrayLiteral("12")) {
            payload = QByteArrayLiteral(
                "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\">"
                "<img src=\"https://images.example.test/photo.png?private=1\">");
        } else if (id == QByteArrayLiteral("11")) {
            payload = QByteArrayLiteral(
                "<meta><img src=\"data:image/png;base64,"
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC"
                "AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
                "\">");
        } else if (id == QByteArrayLiteral("10")) {
            payload = QByteArrayLiteral("\x89PNG\r\n\x1a\ncorrupt");
        } else if (id == QByteArrayLiteral("9")) {
            payload = QByteArrayLiteral("alpha\nbeta");
        } else if (id == QByteArrayLiteral("8")) {
            payload = QByteArray::fromBase64(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC"
                "AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=");
        } else if (id == QByteArrayLiteral("7")) {
            payload = QUrl::fromLocalFile(
                QDir(root).filePath(QStringLiteral("image.png")))
                          .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("6")) {
            payload = QByteArrayLiteral("copy\n")
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("video.mp4")))
                      .toString(QUrl::FullyEncoded).toUtf8()
                + '\n'
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("archive.zip")))
                      .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("5")) {
            payload = QByteArrayLiteral("cut\n")
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("main.cpp")))
                      .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("4")) {
            payload = QByteArrayLiteral("# files\n")
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("image.png")))
                      .toString(QUrl::FullyEncoded).toUtf8()
                + '\n'
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("video.mp4")))
                      .toString(QUrl::FullyEncoded).toUtf8()
                + '\n'
                + QUrl::fromLocalFile(
                      QDir(root).filePath(QStringLiteral("archive.zip")))
                      .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("3")) {
            payload = QUrl::fromLocalFile(
                QDir(root).filePath(QStringLiteral("folder")))
                          .toString(QUrl::FullyEncoded).toUtf8();
        } else if (id == QByteArrayLiteral("2")) {
            payload = QByteArrayLiteral(
                "const value = items.map(item => {\n"
                "  return item.id;\n"
                "});\n");
        } else if (id == QByteArrayLiteral("1")) {
            payload = QByteArrayLiteral("https://example.com/path?q=value");
        } else {
            return 1;
        }
        fwrite(payload.constData(), 1, static_cast<size_t>(payload.size()), stdout);
        return 0;
    }
    if (command == QStringLiteral("delete")) {
        const QByteArray id = readStdin();
        if (id.isEmpty() || id.contains('\n'))
            return 1;
        return appendTrace(QByteArrayLiteral("delete:") + id + '\n')
            ? 0 : 1;
    }
    if (command == QStringLiteral("store")) {
        const QByteArray payload = readStdin();
        return appendTrace(QByteArrayLiteral("store:") + payload) ? 0 : 1;
    }
    if (command == QStringLiteral("wipe"))
        return appendTrace(QByteArrayLiteral("wipe\n")) ? 0 : 1;
    return 2;
}
