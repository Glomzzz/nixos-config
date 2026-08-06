import sys

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherFiveDayForecast.qml", "r") as f:
    content = f.read()

old_delegate = """            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.preferredWidth: 40
                    text: modelData.day
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                MaterialSymbol {
                    text: modelData.icon
                    iconSize: 20
                    color: Appearance.colors.colPrimary
                }

                Text {
                    Layout.preferredWidth: 32
                    text: modelData.minTemp + "°"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Appearance.colors.colSurfaceContainerHigh
                    }

                    Canvas {
                        anchors.fill: parent
                        onWidthChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            const startX = width * modelData.startRatio;
                            const barW = Math.max(height, width * modelData.widthRatio);
                            const endX = startX + barW;

                            const grad = ctx.createLinearGradient(startX, 0, endX, 0);
                            grad.addColorStop(0, "#4fc3f7"); // Light blue
                            grad.addColorStop(1, "#ffa726"); // Orange

                            ctx.beginPath();
                            ctx.moveTo(startX + height/2, 0);
                            ctx.lineTo(endX - height/2, 0);
                            ctx.arc(endX - height/2, height/2, height/2, -Math.PI/2, Math.PI/2);
                            ctx.lineTo(startX + height/2, height);
                            ctx.arc(startX + height/2, height/2, height/2, Math.PI/2, Math.PI*1.5);
                            ctx.fillStyle = grad;
                            ctx.fill();
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: 32
                    text: modelData.maxTemp + "°"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 13
                }
            }"""

new_delegate = """            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.preferredWidth: 40
                    text: modelData.day
                    color: index === 0 ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    font.weight: index === 0 ? Font.Medium : Font.Normal
                }

                MaterialSymbol {
                    text: modelData.icon
                    iconSize: 22
                    fill: 1
                    color: Appearance.colors.colPrimary
                }

                Text {
                    Layout.preferredWidth: 32
                    text: modelData.minTemp + "°"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 2
                        radius: Math.min(width, height) / 2
                        color: Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.22)
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * modelData.startRatio
                        width: Math.max(parent.height, parent.width * modelData.widthRatio)
                        height: 5
                        radius: Math.min(width, height) / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.55) }
                            GradientStop { position: 1.0; color: Appearance.colors.colPrimary }
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: 32
                    text: modelData.maxTemp + "°"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 13
                }
            }"""

if old_delegate in content:
    content = content.replace(old_delegate, new_delegate)
    with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherFiveDayForecast.qml", "w") as f:
        f.write(content)
    print("Replaced old delegate successfully")
else:
    print("Could not find exact old delegate match!")
    sys.exit(1)
