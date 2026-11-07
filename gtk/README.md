# GTK and Qt

## GTK: why adw-gtk3, and why files in `~/.config`

`gtk-{3,4}.0/colors.css` recolour GTK with the base16 palette, through
libadwaita's named colours (`@window_bg_color`, `@accent_bg_color` …). Each
`gtk.css` only imports its `colors.css`.

- **The theme is adw-gtk3-dark, not Adwaita.** GTK4/libadwaita resolves the
  named colours at runtime, so for GTK4 the CSS just works. Stock Adwaita for
  GTK3 cannot be recoloured: it is compiled from SCSS with every colour baked
  in. adw-gtk3 is libadwaita's stylesheet ported back to GTK3 and built to be
  recoloured (it references `@window_bg_color` over 200 times, and derives the
  legacy GTK3 names from the libadwaita ones), so one palette drives both
  generations. "Adwaita-dark" as a GTK3 theme name does not exist, and GTK3
  falls back to *light* Adwaita; `color-scheme` does not rescue that, because
  GDK3 never reads it.
- **The files go in `~/.config`.** GTK reads `gtk.css` only from the user's
  config directory: no system fallback, no environment variable, nothing a
  wrapper could use, and libadwaita apps ignore the theme name entirely and read
  `~/.config/gtk-4.0/gtk.css` and nothing else. So each of the four files is
  linked there (they must sit in the same directory: `@import` resolves
  relative to the importing file). The Nix module links store copies with
  systemd user tmpfiles, re-applied on every switch.
- **The settings** (theme, dark preference, icons, cursor, fonts) live in
  `org.gnome.desktop.interface`: `bin/basalt-gsettings` sets them, or the Nix
  module's dconf profile. Install adw-gtk3, Papirus and Bibata.

## Qt: qt6ct

`qt/base16.conf` is the palette as qt6ct's colour scheme; `qt/qt6ct.conf`
selects it (style Fusion, Papirus icons) and goes in `~/.config/qt6ct/` (and
`qt5ct/` as `qt5ct.conf`, for a Qt5 app), with `@COLORS@` replaced by the
absolute path of `base16.conf`. Qt programs read it when
`QT_QPA_PLATFORMTHEME=qt6ct`, and qt6ct's plugin is on `QT_PLUGIN_PATH`.

NixOS' `qt.platformTheme` is not used by the module: its one value that covers
Qt6, "qt5ct", brings the whole Qt5 stack (~108 MB) along for the GUI, where
the module needs only qt6ct (~1 MB on top of the Qt6 quickshell already pulls).
