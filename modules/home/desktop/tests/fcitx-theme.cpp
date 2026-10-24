#include <QColor>
#include <QCoreApplication>
#include <QImage>
#include <QPainter>
#include <QSettings>
#include <algorithm>
#include <cmath>
#include <iostream>
#include <stdexcept>

void require(bool condition, const char *message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void checkBackground(QSettings &theme, const QString &section,
                     const QString &filename) {
    theme.beginGroup(section);
    require(!theme.value("Image").toString().isEmpty(),
            "background must use an explicit image for Qt client compatibility");
    const QColor background(theme.value("Color").toString());
    const QColor border(theme.value("BorderColor").toString());
    const int borderWidth = theme.value("BorderWidth").toInt();
    const int left = theme.value("Margin/Left").toInt();
    const int right = theme.value("Margin/Right").toInt();
    const int top = theme.value("Margin/Top").toInt();
    const int bottom = theme.value("Margin/Bottom").toInt();
    theme.endGroup();

    require(background.isValid() && border.isValid(), "invalid theme colors");
    require(borderWidth > 0 && std::min({left, right, top, bottom}) > borderWidth,
            "stretchable background needs solid padding inside the border");
    const QImage image(filename);
    require(!image.isNull(), "background PNG cannot be loaded by Qt");
    require(image.width() > left + right && image.height() > top + bottom,
            "background image has no stretchable center");
    for (int y = 0; y < image.height(); ++y) {
        for (int x = 0; x < image.width(); ++x) {
            const bool edge = x < borderWidth || y < borderWidth ||
                              x >= image.width() - borderWidth ||
                              y >= image.height() - borderWidth;
            require(image.pixelColor(x, y) == (edge ? border : background),
                    "background PNG has unexpected colors or transparency");
        }
    }

    // Exercise the Qt client's nine-patch layout with smooth interpolation at
    // integer and fractional scales, without a compositor or live input context.
    for (const QSize size : {QSize(450, 105), QSize(180, 240)}) {
        for (const qreal scale : {1.0, 1.25, 1.5, 2.0}) {
            QImage output(size * scale, QImage::Format_ARGB32_Premultiplied);
            output.setDevicePixelRatio(scale);
            output.fill(Qt::transparent);
            {
                QPainter painter(&output);
                painter.setRenderHint(QPainter::SmoothPixmapTransform);
                const int sx[] = {0, left, image.width() - right, image.width()};
                const int sy[] = {0, top, image.height() - bottom, image.height()};
                const int dx[] = {0, left, size.width() - right, size.width()};
                const int dy[] = {0, top, size.height() - bottom, size.height()};
                for (int y = 0; y < 3; ++y) {
                    for (int x = 0; x < 3; ++x) {
                        painter.drawImage(
                            QRect(dx[x], dy[y], dx[x + 1] - dx[x], dy[y + 1] - dy[y]),
                            image,
                            QRect(sx[x], sy[y], sx[x + 1] - sx[x], sy[y + 1] - sy[y]));
                    }
                }
            }
            const int inset = std::ceil((std::max({left, right, top, bottom}) + 2) * scale);
            for (int y = inset; y < output.height() - inset; ++y) {
                for (int x = inset; x < output.width() - inset; ++x) {
                    require(output.pixelColor(x, y) == background,
                            "scaled background is not uniformly opaque and solid");
                }
            }
        }
    }
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    try {
        require(argc == 4, "expected theme.conf, input-panel.png, menu.png");
        QSettings theme(QString::fromLocal8Bit(argv[1]), QSettings::IniFormat);
        require(theme.value("InputPanel/Background/Image") == "input-panel.png",
                "unexpected input panel image reference");
        require(theme.value("Menu/Background/Image") == "menu.png",
                "unexpected menu image reference");
        checkBackground(theme, "InputPanel/Background", QString::fromLocal8Bit(argv[2]));
        checkBackground(theme, "Menu/Background", QString::fromLocal8Bit(argv[3]));
        std::cout << "Fcitx theme PNG colors, padding, and scaled Qt rendering passed\n";
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
