import sys

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "r") as f:
    lines = f.readlines()

# Update root dimensions
for i in range(len(lines)):
    if lines[i].startswith("    width: 820"):
        lines[i] = "    width: 876\n"
    elif lines[i].startswith("    height: 560"):
        lines[i] = "    height: 600\n"

# Update map width constraint
for i in range(len(lines)):
    if "// Map Area (Stack 1)" in lines[i]:
        for j in range(i, min(i+20, len(lines))):
            if "Layout.minimumHeight: 292" in lines[j]:
                lines.insert(j, "                Layout.minimumWidth: 500\n                Layout.preferredWidth: 500\n")
                break
        break

with open("/home/archirithm/.config/quickshell/Modules/Keystone/WeatherContent/WeatherContent.qml", "w") as f:
    f.writelines(lines)

print("Done")
