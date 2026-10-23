{
  config,
  lib,
  ...
}: let
  emc = "${config.home.homeDirectory}/.local/bin/emc";
  terminalEditor = {
    name = "Emacs (Terminal)";
    genericName = "Text Editor";
    comment = "Edit text in terminal Emacs";
    exec = "${emc} --tty %F";
    icon = "emacs";
    terminal = true;
    categories = ["Development" "TextEditor"];
    startupNotify = false;
    mimeType = builtins.attrNames (lib.filterAttrs
      (_: applications: lib.elem "emacsclient.desktop" applications)
      config.xdg.mimeApps.defaultApplications);
  };
in {
  # Preserve the desktop IDs used by existing MIME associations, but never
  # detach a TTY client: its terminal must stay alive until editing finishes.
  xdg.desktopEntries = {
    emacs = terminalEditor;
    emacsclient =
      terminalEditor
      // {
        name = "Emacs Client (Terminal)";
        noDisplay = true;
      };
    emacs-gui =
      terminalEditor
      // {
        name = "Emacs (GUI)";
        comment = "Explicitly open a graphical Emacs client frame";
        exec = "${emc} --create-frame --no-wait %F";
        terminal = false;
      };
    emacs-dirvish = {
      name = "Emacs Dirvish";
      genericName = "File Manager";
      comment = "Manage files with Dirvish in terminal Emacs";
      exec = "${emc} --tty %f";
      icon = "emacs";
      terminal = true;
      categories = ["System" "FileTools" "FileManager"];
      mimeType = ["inode/directory"];
      startupNotify = false;
    };
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
