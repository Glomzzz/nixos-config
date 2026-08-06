import sys

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "r") as f:
    lines = f.readlines()

for i in range(len(lines)):
    if "// Map Area (Stack 1)" in lines[i]:
        # The next line is Rectangle {
        # The next line is Layout.fillWidth: true
        # The next line is Layout.fillHeight: true
        for j in range(i, min(i+10, len(lines))):
            if "Layout.fillHeight: true" in lines[j]:
                lines[j] = lines[j] + "                Layout.minimumHeight: 292\n                Layout.preferredHeight: 292\n"
                break
        break

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "w") as f:
    f.writelines(lines)

print("Done")
