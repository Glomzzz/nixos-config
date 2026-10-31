{
  config,
  email,
  pkgs,
}: let
  home = config.home-manager.users.glom;
  account = home.accounts.email.accounts.infomaniak;
  python = pkgs.python3.withPackages (ps: [ps.secretstorage]);
  settings = pkgs.writeText "mail-settings.json" (builtins.toJSON {
    inherit (account) passwordCommand;
    mbsync = home.xdg.configFile."isyncrc".text;
    msmtp = home.xdg.configFile."msmtp/config".text;
    muInit = home.home.activation.runMuInit.data;
    service = home.systemd.user.services.mbsync;
    timer = home.systemd.user.timers.mbsync;
    notify = home.systemd.user.services.mail-notify;
    legacyConfig = toString home.home.file.".mbsyncrc".source;
    xdgConfig = toString home.xdg.configFile."isyncrc".source;
  });
in
  assert home.programs.mbsync.enable && home.programs.msmtp.enable && home.programs.mu.enable;
  assert home.programs.password-store.enable;
  assert account.primary && account.mu.enable && account.msmtp.enable && account.mbsync.enable;
  assert account.address == email && account.userName == account.address;
  assert account.imap.tls.enable && !account.imap.tls.useStartTls && account.imap.port == 993;
  assert account.smtp.tls.enable && account.smtp.tls.useStartTls && account.smtp.port == 587;
  assert account.mbsync.create == "maildir" && account.mbsync.remove == "none" && account.mbsync.expunge == "none";
  assert home.services.mbsync.postExec == null;
  assert home.services.gpg-agent.enable;
  assert config.services.gnome.gnome-keyring.enable;
  assert config.security.pam.services.login.enableGnomeKeyring;
    pkgs.runCommand "mail-check" {
      nativeBuildInputs = [python home.programs.mu.package];
    } ''
      python3 ${./credential-tests.py} ${./credential.py}
      python3 - ${settings} '${email}' <<'PY'
      import json
      import sys

      with open(sys.argv[1]) as source:
          s = json.load(source)
      for config_name, password_option in (("mbsync", "PassCmd"), ("msmtp", "passwordeval")):
          text = s[config_name]
          assert "mail.infomaniak.com" in text
          assert "/bin/infomaniak-password" in text
          assert "pass show" not in text, "no automatic hardware-backed fallback"
          assert " ".join(s["passwordCommand"]) in text
          assert s["passwordCommand"][1:] == ["lookup"]
          assert password_option in text
      for line in ("Create Near", "Remove None", "Expunge None", "SubFolders Verbatim",
                   "Inbox /home/glom/Maildir/infomaniak/INBOX"):
          assert line in s["mbsync"]
      for line in ("tls on", "tls_starttls on", "port 587", "account default : infomaniak"):
          assert line in s["msmtp"]
      assert s["legacyConfig"] == s["xdgConfig"]
      service = s["service"]
      assert "ConditionPathExists" not in service.get("Unit", {})
      assert service["Service"]["ExecCondition"] == s["passwordCommand"][0] + " check"
      assert service["Service"]["UMask"] == "0077"
      assert "ExecStartPost" not in service["Service"], "mu4e must own the index lock"
      assert service["Unit"]["OnSuccess"] == ["mail-notify.service"]
      assert s["notify"]["Service"]["Type"] == "oneshot"
      execStart = " ".join(s["notify"]["Service"]["ExecStart"])
      for folder in ("INBOX", "alimail", "gmail", "monash", "qqmail"):
          assert "--folder " + folder + " /home/glom/Maildir/infomaniak/" + folder + "/new " in execStart
      assert "Spam" not in execStart
      assert "--systemd-run " in execStart and "--emc /home/glom/.local/bin/emc" in execStart
      assert s["timer"]["Timer"]["OnCalendar"] == "*:0/5"
      assert s["timer"]["Timer"]["Persistent"]
      assert "--my-address=" + sys.argv[2] in s["muInit"]
      assert "--maildir=/home/glom/Maildir" in s["muInit"]
      PY

      python3 ${./notify-tests.py} ${./notify.py}

      # Exercise the pinned mu version with a private, synthetic mailbox only.
      export HOME="$TMPDIR/home" MUHOME="$TMPDIR/mu"
      mkdir -p "$HOME/Maildir/infomaniak/INBOX/"{cur,new,tmp}
      printf 'From: sender@example.org\nTo: %s\nSubject: Mail smoke test\nMessage-ID: <mail-check@example.org>\nDate: Wed, 21 Oct 2026 12:00:00 +0000\n\nOffline test.\n' '${email}' > "$HOME/Maildir/infomaniak/INBOX/new/test-message"
      mu init --maildir="$HOME/Maildir" --my-address='${email}'
      mu index
      mu find 'subject:"Mail smoke test"' --fields=subject | grep -F 'Mail smoke test'
      touch "$out"
    ''
