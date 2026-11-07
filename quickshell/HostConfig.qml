import QtQuick
import Quickshell

// Everything a host can tell Basalt's shell, with the defaults it gets for not
// saying. A host does not use this type directly: it provides a singleton named
// Host at the root of its quickshell config that derives from it, and sets
// only what differs.
//
//   // ~/.config/quickshell/Host.qml
//   pragma Singleton
//   import qs.basalt
//
//   HostConfig {
//     updatesStatus: ["snout", "has-updates", "--json"]
//     updatesDetails: ["snout", "report", "--json"]
//   }
//
// Every Basalt file reads it as `Host` (import qs), so a host's values, its
// overridden functions included, are what the shell sees. Host.qml is required:
// one that sets nothing is `HostConfig {}`.
Singleton {
  // ---- theme ----

  // The base16 palette, as bare six-digit hex without a leading '#'. theme.json
  // at the top of the repo is the canonical copy of the default, and
  // `nix flake check` holds this one to it.
  property var palette: ({
    base00: "141817", base01: "222725", base02: "293b35", base03: "6e7371",
    base04: "959998", base05: "cdd0cf", base06: "e1e3e2", base07: "f2f4f3",
    base08: "ff615d", base09: "e5801a", base0A: "bd9903", base0B: "39ba5a",
    base0C: "20b1bf", base0D: "579ff9", base0E: "ce74dc", base0F: "ca8b7f"
  })

  // The UI face, the monospace face, and the Nerd Font the glyph icons are
  // drawn with (its non-mono variant).
  property var fonts: ({ ui: "Onest", mono: "Hack Nerd Font Mono", glyph: "Hack Nerd Font" })

  // ---- the launcher ----

  // Desktop-entry ids the launcher never shows, matched case-insensitively.
  property var ignoredApps: ["xterm", "nvim", "btop"]

  // How the launcher starts an application. An argv in which "{id}" stands for
  // the desktop entry's id ("firefox"), e.g. ["uwsm", "app", "--", "{id}.desktop"].
  // Empty: the entry's own Exec line, through DesktopEntry.execute().
  property var launchCommand: []

  // The launcher calls this for every application it starts, so a host that
  // needs more than an argv (a different environment, say) overrides it.
  function launch(entry) {
    if (launchCommand.length === 0) {
      entry.execute();
      return;
    }
    Quickshell.execDetached(launchCommand.map(a => a.split("{id}").join(entry.id)));
  }

  // ---- updates ----
  //
  // The bar's updates pill and the details window run commands rather than
  // knowing any package manager. Each prints one JSON document; the formats
  // are in Basalt's README, under "The updates protocol".

  // Polled every updatesInterval ms for the pill. Must be cheap and must never
  // start expensive work. Empty: no pill.
  property var updatesStatus: []

  // Fetched when the popup or the details window opens, and polled while the
  // window is shown: every update, part by part. Empty: no details.
  property var updatesDetails: []

  // Run by the details window's "Check now" button, which only exists when
  // this is set. It may take a while; the window shows the status meanwhile.
  property var updatesCheck: []

  property int updatesInterval: 10000

  // ---- the bar ----

  // Extra items for the bar, placed at the start of its right-hand group,
  // before the tray. Each is created once per bar (one per monitor); an item
  // with a `barWindow` property is handed its bar's window.
  //
  //   barItems: [ Component { MyIndicator {} } ]
  property list<Component> barItems
}
