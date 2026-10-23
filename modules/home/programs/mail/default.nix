{
  config,
  lib,
  pkgs,
  email,
  usernameFull,
  ...
}: let
  passwordStore = "${config.home.homeDirectory}/.password-store";
  passwordEntry = "email/infomaniak";
in {
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
      # Explicit environment also works in systemd, before a new login session.
      # Only the command is stored in Nix; the password stays GPG-encrypted at home.
      passwordCommand = "${pkgs.coreutils}/bin/env PASSWORD_STORE_DIR=${passwordStore} ${config.programs.password-store.package}/bin/pass show ${passwordEntry}";
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

  # This Home Manager generates isyncrc, but isync 1.5 still defaults to
  # ~/.mbsyncrc. Keep manual `mbsync -a` and the service on the same config.
  home.file.".mbsyncrc".source = config.xdg.configFile."isyncrc".source;

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
    services.mbsync = {
      Unit.ConditionPathExists = "${passwordStore}/${passwordEntry}.gpg";
      Service = {
        UMask = "0077";
        TimeoutStartSec = "15min";
      };
    };
    timers.mbsync.Timer.Persistent = true;
  };

  # Maildir and its parent contain private, unencrypted message contents.
  home.activation.privateMaildir = lib.hm.dag.entryAfter ["createMaildir"] ''
    run chmod 700 ${lib.escapeShellArg config.accounts.email.maildirBasePath} ${lib.escapeShellArg config.accounts.email.accounts.infomaniak.maildir.absPath}
  '';
}
