{
  config,
  lib,
  ...
}: let
  emc = "${config.home.homeDirectory}/.local/bin/emc";
  # Desktop launches open a GUI frame and return at once, so no Kitty wrapper
  # is involved. Terminal callers keep emc's blocking TTY default.
  guiEditor = {
    name = "Emacs";
    genericName = "Text Editor";
    comment = "Edit text in Emacs";
    exec = "${emc} --create-frame --no-wait %F";
    icon = "emacs";
    terminal = false;
    categories = ["Development" "TextEditor"];
    startupNotify = false;
    mimeType = builtins.attrNames (lib.filterAttrs
      (_: applications: lib.elem "emacsclient.desktop" applications)
      config.xdg.mimeApps.defaultApplications);
  };
in {
  # Preserve the desktop IDs used by existing MIME associations.
  xdg.desktopEntries = {
    emacs = guiEditor;
    emacsclient =
      guiEditor
      // {
        name = "Emacs Client";
        noDisplay = true;
      };
    emacs-dirvish = {
      name = "Emacs Dirvish";
      genericName = "File Manager";
      comment = "Manage files with Dirvish in Emacs";
      exec = "${emc} --create-frame --no-wait %f";
      icon = "emacs";
      terminal = false;
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
