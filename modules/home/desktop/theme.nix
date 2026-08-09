{pkgs, ...}: {
  # Session-wide dark preference. With KDE gone nothing was telling GTK, Qt or
  # the XDG portal that this is a dark desktop, so every toolkit fell back to
  # its light default while the hand-styled surfaces (foot, waybar, swaync,
  # zathura, fuzzel) stayed dark. Each block below covers one toolkit; there is
  # no single switch that reaches all of them.

  gtk = {
    enable = true;

    # This one option drives three separate mechanisms in Home Manager, which
    # is why it is set here rather than writing the keys by hand:
    #   1. gtk-3.0/settings.ini and gtk-4.0/settings.ini get
    #      gtk-application-prefer-dark-theme=true (GTK4 also gets
    #      gtk-interface-color-scheme=2),
    #   2. dconf org/gnome/desktop/interface color-scheme becomes "prefer-dark",
    #   3. which is exactly the key xdg-desktop-portal-gtk reads to answer the
    #      org.freedesktop.appearance color-scheme portal query.
    # That portal answer is what libadwaita apps, Firefox and Electron follow,
    # so setting this also fixes them without any per-app configuration.
    # Writing dconf's color-scheme directly here instead would collide with the
    # module's own definition of that key.
    colorScheme = "dark";

    # GTK4/libadwaita ignores gtk-theme-name and recolours itself from the
    # color-scheme above, so this theme only affects GTK2/GTK3 apps.
    # adw-gtk3-dark reproduces the current Adwaita dark styling for GTK3, which
    # keeps GTK3 and GTK4 windows looking like the same desktop.
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    font = {
      name = "Noto Sans CJK SC";
      size = 11;
    };

    # GTK2 needs no block of its own: the module already mirrors the theme, icon
    # and font settings above into ~/.gtkrc-2.0, which is the only file GTK2
    # reads. GTK2 has no prefer-dark flag at all, so a GTK2 app is dark purely
    # because adw-gtk3-dark is.
  };

  # GTK_THEME is deliberately not exported. It is a debugging override that
  # outranks settings.ini and dconf for every GTK process, including ones that
  # ship their own styling, and it cannot be undone per-app.

  qt = {
    enable = true;

    # The gtk3 platform theme makes Qt read the GTK settings written above, so
    # Qt follows the same dark preference instead of needing a parallel colour
    # config. It is built into both qtbase 5 and 6 here (libqgtk3.so is present
    # in each), so this needs no extra package - unlike qtct, which would add
    # qt5ct/qt6ct plus a second theme config to keep in sync.
    #
    # This sets QT_QPA_PLATFORMTHEME, which is independent of the
    # QT_QPA_PLATFORM="wayland;xcb" set in hardware/zephyrus/gpu: one picks the
    # windowing backend, the other the widget theming source.
    platformTheme.name = "gtk3";
  };

  # Qt's own dark styling comes from the platform theme above, so no
  # QT_STYLE_OVERRIDE is set here; adding one would outrank it.

  # xdg-desktop-portal-gtk answers the appearance query out of dconf, and its
  # schema has to be installed for that lookup to resolve at all.
  home.packages = [pkgs.gsettings-desktop-schemas];
}
