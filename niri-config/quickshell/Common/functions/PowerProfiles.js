var profileOrder = ["performance", "balanced", "power-saver"];

function normalizeProfile(value) {
    const profile = String(value || "").trim();
    return profileOrder.indexOf(profile) !== -1 ? profile : "";
}

function parseList(output) {
    const discovered = {};
    let activeProfile = "";
    const lines = String(output || "").split(/\r?\n/);

    for (const line of lines) {
        const match = line.match(/^\s*(\*)?\s*(performance|balanced|power-saver):\s*$/);
        if (!match)
            continue;

        const profile = normalizeProfile(match[2]);
        if (profile === "")
            continue;
        discovered[profile] = true;
        if (match[1] === "*")
            activeProfile = profile;
    }

    const profiles = profileOrder.filter(profile => discovered[profile]);
    if (profiles.indexOf(activeProfile) === -1)
        activeProfile = "";

    return {
        "profiles": profiles,
        "activeProfile": activeProfile
    };
}
