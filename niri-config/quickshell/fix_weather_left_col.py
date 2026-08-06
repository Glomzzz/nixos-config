import sys

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "r") as f:
    lines = f.readlines()

filtered_lines = []
skip = False
for i, line in enumerate(lines):
    if "Rectangle {" in line and "Layout.fillWidth: true" in lines[i+1] and "Layout.preferredHeight: 1" in lines[i+2] and "color: Appearance.colors.colOutlineVariant" in lines[i+3]:
        skip = True
        skip_count = 5
        continue

    if skip:
        skip_count -= 1
        if skip_count == 0:
            skip = False
        continue

    filtered_lines.append(line)

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "w") as f:
    f.writelines(filtered_lines)

print("Done")
