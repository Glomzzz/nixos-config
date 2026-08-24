{
  config,
  pkgs,
  ...
}: let
  emc = "${config.home.homeDirectory}/.local/bin/emc";
  noSpawnEditor = "${pkgs.coreutils}/bin/false";
in {
  programs.fish.functions.magit = {
    description = "Open Magit in a new Emacs window for the current directory";
    body = ''
      if not command git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>/dev/null
        echo "magit: $PWD is not inside a Git repository" >&2
        return 1
      end

      # Always ask emacsclient for a fresh graphical frame.  The Elisp
      # entry point uses that request's selected frame, so existing Magit
      # windows are left untouched.
      ${emc} --create-frame --no-wait --suppress-output --alternate-editor=${noSpawnEditor} --eval '(git/status-window default-directory)'
      and echo "Magit opened in a new Emacs window"
    '';
  };

  xdg.desktopEntries.emacs-dirvish = {
    name = "Emacs Dirvish";
    genericName = "File Manager";
    comment = "Manage files with Dirvish in Emacs";
    exec = "${emc} --create-frame --no-wait --alternate-editor=${noSpawnEditor} %f";
    icon = "emacs";
    terminal = false;
    categories = ["System" "FileTools" "FileManager"];
    mimeType = ["inode/directory"];
    startupNotify = true;
  };

  # Language-specific file associations (C/C++, Java) live in the
  # per-language modules under ./langs.
  xdg.mimeApps.defaultApplications = {
    "application/epub+zip" = ["emacsclient.desktop"];
    "application/x-fishscript" = ["emacsclient.desktop"];
    "application/json" = ["emacsclient.desktop"];
    "application/pdf" = ["emacsclient.desktop"];
    "application/postscript" = ["emacsclient.desktop"];
    "application/x-shellscript" = ["emacsclient.desktop"];
    "application/x-gzpostscript" = ["emacsclient.desktop"];
    "image/x-eps" = ["emacsclient.desktop"];
    "inode/directory" = ["emacs-dirvish.desktop"];
    "text/plain" = ["emacsclient.desktop"];
    "text/x-makefile" = ["emacsclient.desktop"];
    "text/x-moc" = ["emacsclient.desktop"];
    "text/x-pascal" = ["emacsclient.desktop"];
    "text/x-tcl" = ["emacsclient.desktop"];
    "text/x-tex" = ["emacsclient.desktop"];
    "x-scheme-handler/org-protocol" = ["emacsclient.desktop"];
  };
}
