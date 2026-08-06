import QtQuick 2.15
import QtTest 1.3
import "../../Common/functions/PowerProfiles.js" as PowerProfiles

TestCase {
    name: "PowerProfiles"

    function test_parsesSupportedAndActiveProfiles() {
        const state = PowerProfiles.parseList([
            "  performance:",
            "    CpuDriver:\tamd_pstate",
            "",
            "* balanced:",
            "    PlatformDriver:\tplatform_profile",
            "",
            "  power-saver:"
        ].join("\n"));

        compare(JSON.stringify(state.profiles), JSON.stringify([
            "performance", "balanced", "power-saver"
        ]));
        compare(state.activeProfile, "balanced");
    }

    function test_acceptsMachinesWithoutPerformanceProfile() {
        const state = PowerProfiles.parseList(
            "* balanced:\n\n  power-saver:\n");

        compare(JSON.stringify(state.profiles),
            JSON.stringify(["balanced", "power-saver"]));
        compare(state.activeProfile, "balanced");
    }

    function test_rejectsMalformedOrInactiveOutput() {
        let state = PowerProfiles.parseList("service unavailable");
        compare(JSON.stringify(state.profiles), "[]");
        compare(state.activeProfile, "");

        state = PowerProfiles.parseList(
            "  performance:\n  balanced:\n  power-saver:\n");
        compare(JSON.stringify(state.profiles), JSON.stringify([
            "performance", "balanced", "power-saver"
        ]));
        compare(state.activeProfile, "");
    }

    function test_ignoresUnknownAndDuplicateProfiles() {
        const state = PowerProfiles.parseList([
            "* balanced:",
            "  turbo:",
            "  balanced:",
            "  power-saver:"
        ].join("\n"));

        compare(JSON.stringify(state.profiles),
            JSON.stringify(["balanced", "power-saver"]));
        compare(state.activeProfile, "balanced");
        compare(PowerProfiles.normalizeProfile("turbo"), "");
    }
}
