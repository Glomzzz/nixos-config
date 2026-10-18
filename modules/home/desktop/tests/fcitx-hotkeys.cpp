#include <fstream>
#include <iostream>

#include <fcitx-config/iniparser.h>
#include <fcitx-config/marshallfunction.h>
#include <fcitx-config/rawconfig.h>
#include <fcitx-utils/key.h>

// Check unbindings with Fcitx's own INI parser and key-list decoder,
// rather than assuming Python's configparser matches their semantics.
int main(int argc, char **argv) {
    if (argc != 3) {
        std::cerr << "Usage: fcitx-hotkeys-check FILE KEY_PATH\n";
        return 1;
    }
    std::ifstream input(argv[1]);
    if (!input) {
        std::cerr << "Cannot read " << argv[1] << '\n';
        return 1;
    }
    fcitx::RawConfig config;
    fcitx::readFromIni(config, input);
    auto entry = config.get(argv[2]);
    if (!entry) {
        std::cerr << "Missing explicit unbinding: " << argv[2] << '\n';
        return 1;
    }
    fcitx::KeyList keys{fcitx::Key("Control+semicolon"),
                        fcitx::Key("Control+Alt+P")};
    if (!fcitx::unmarshallOption(keys, *entry, false)) {
        std::cerr << "Invalid key list: " << argv[2] << '\n';
        return 1;
    }
    for (const auto &key : keys) {
        if (!key.toString().empty()) {
            std::cerr << argv[2] << " still binds " << key.toString() << '\n';
            return 1;
        }
    }
}
