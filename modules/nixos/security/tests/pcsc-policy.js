"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const settings = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const rules = [];
const yes = "authorized";
vm.runInNewContext(settings.pcscPolicy, {
  polkit: {
    Result: { YES: yes },
    addRule: (rule) => rules.push(rule),
    addAdminRule: () => {},
  },
}, { timeout: 1000 });

function allowed(action, user, active, local) {
  const subject = { user, active, local, isInGroup: () => false };
  return rules.some((rule) => rule({ id: action }, subject) === yes);
}

const actions = [
  "org.debian.pcsc-lite.access_pcsc",
  "org.debian.pcsc-lite.access_card",
];
for (const active of [false, true]) {
  for (const local of [false, true]) {
    for (const action of actions) {
      assert(allowed(action, settings.pcscUser, active, local),
        `PC/SC access must work for the configured user: ${action}`);
      for (const user of ["nobody", "root", `${settings.pcscUser}-other`]) {
        assert(!allowed(action, user, active, local),
          `The custom rule must not grant PC/SC access to ${user}`);
      }
    }
    for (const action of [
      "org.freedesktop.policykit.exec",
      "org.freedesktop.systemd1.manage-units",
      "org.debian.pcsc-lite.access_pcsc.other",
      "org.debian.pcsc-lite.other",
    ]) {
      assert(!allowed(action, settings.pcscUser, active, local),
        `The custom rule must not authorize unrelated actions: ${action}`);
    }
  }
}

console.log("PC/SC policy permits only the configured user and exact card-access actions");
