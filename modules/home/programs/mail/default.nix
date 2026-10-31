{
  config,
  lib,
  pkgs,
  email,
  usernameFull,
  ...
}: let
  passwordStore = "${config.home.homeDirectory}/.password-store";
  python = pkgs.python3.withPackages (ps: [ps.secretstorage]);
  account = config.accounts.email.accounts.infomaniak;
  inboxNew = "${account.maildir.absPath}/${account.folders.inbox}/new";
  notifyState = "${config.xdg.stateHome}/mail-notify/infomaniak-inbox.json";
  credential = pkgs.writeShellApplication {
    name = "infomaniak-password";
    text = ''
      exec ${python}/bin/python3 ${./credential.py} \
        --account ${lib.escapeShellArg email} \
        --pass-program ${config.programs.password-store.package}/bin/pass \
        --password-store ${lib.escapeShellArg passwordStore} "$@"
    '';
  };
in {
  home = {
    packages = [credential];
    # This Home Manager generates isyncrc, but isync 1.5 still defaults to
    # ~/.mbsyncrc. Keep manual mbsync and the service on the same config.
    file.".mbsyncrc".source = config.xdg.configFile."isyncrc".source;
    # Maildir and its parent contain private, unencrypted message contents.
    activation.privateMaildir = lib.hm.dag.entryAfter ["createMaildir"] ''
      run chmod 700 ${lib.escapeShellArg config.accounts.email.maildirBasePath} ${lib.escapeShellArg config.accounts.email.accounts.infomaniak.maildir.absPath}
    '';
  };
  programs = {
    mbsync.enable = true;
    msmtp.enable = true;
    mu.enable = true;
    password-store = {
      enable = true;
      settings.PASSWORD_STORE_DIR = passwordStore;
    };
    # Unlike archive packages, mu4e must match the installed mu executable.
    emacs.extraPackages = epkgs: [epkgs.mu4e];
  };

  accounts.email = {
    maildirBasePath = "Maildir";
    accounts.infomaniak = {
      primary = true;
      address = email;
      userName = email;
      realName = usernameFull;
      # Login's PAM stack unlocks GNOME Keyring with the account password.
      # Only the command enters the Nix store. Never auto-unlock or fall back to
      # the YubiKey; pass is kept solely for explicit one-time import/backup.
      passwordCommand = "${credential}/bin/infomaniak-password lookup";
      imap = {
        host = "mail.infomaniak.com";
        port = 993;
        tls.enable = true;
      };
      smtp = {
        host = "mail.infomaniak.com";
        port = 587;
        tls = {
          enable = true;
          useStartTls = true;
        };
      };
      folders.inbox = "INBOX";
      maildir.path = "infomaniak";
      mbsync = {
        enable = true;
        create = "maildir";
        remove = "none";
        expunge = "none";
        patterns = ["*"];
        subFolders = "Verbatim";
      };
      msmtp.enable = true;
      mu.enable = true;
    };
  };

  services.mbsync = {
    enable = true;
    package = config.programs.mbsync.package;
    frequency = "*:0/5";
    verbose = false;
    preExec = "${pkgs.coreutils}/bin/mkdir -p %h/Maildir/infomaniak";
    # Do not run `mu index` here: mu4e owns the database lock while open.
    # Its five-minute update timer indexes mail synchronized externally.
  };

  systemd.user = {
    services = {
      mbsync = {
        # A successful sync starts the notifier.  That unit only reads new
        # message headers, so mu's database lock is left alone.
        Unit.OnSuccess = ["mail-notify.service"];
        Service = {
          # Status 1 skips this attempt cleanly when locked/missing. The next
          # timer tick retries without pinentry, GUI prompts, or GPG access.
          ExecCondition = "${credential}/bin/infomaniak-password check";
          UMask = "0077";
          TimeoutStartSec = "15min";
        };
      };
      mail-notify = {
        Unit.Description = "Notify about new Infomaniak INBOX mail";
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.python3}/bin/python3 ${./notify.py} --new-dir ${inboxNew} --state ${notifyState} --notify-send ${pkgs.libnotify}/bin/notify-send";
          UMask = "0077";
        };
      };
    };
    timers.mbsync.Timer.Persistent = true;
  };
}
