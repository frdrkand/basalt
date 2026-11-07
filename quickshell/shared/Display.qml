pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The monitor layout, as Workspaces.qml needs it: which workspace ids belong to
// an output, and which monitor number to print on its pips so they match the
// SUPER+<n> chords.
//
// Hyprland's side decides it (hypr/display.lua, declared or derived) and writes
// the result at every config load to $XDG_RUNTIME_DIR/basalt-display.state, one
// line per monitor in layout order:
//
//     <connector> <first workspace id> <workspace count>
//
// This only reads that file, so there is no second copy of the ordering rule
// to keep in step. A dock or undock reloads Hyprland's config, which rewrites
// the file, which this watches.
Singleton {
  id: root

  // In layout order: [{ name, first, workspaces }].
  property var outputs: []

  function parse(text) {
    const out = [];
    for (const line of text.split("\n")) {
      const f = line.trim().split(/\s+/);
      if (f.length !== 3) continue;
      const first = Number(f[1]), count = Number(f[2]);
      if (first > 0 && count >= 0) out.push({ name: f[0], first: first, workspaces: count });
    }
    outputs = out;
  }

  FileView {
    id: state
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/basalt-display.state"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(state.text())
    onLoadFailed: root.outputs = []
  }

  // Position of `name` in `outputs`, or -1 if it is not in the layout. The
  // monitor number in the SUPER+<n> chords is this plus one.
  function indexFor(name) {
    for (let i = 0; i < outputs.length; i++)
      if (outputs[i].name === name) return i;
    return -1;
  }

  // How many workspaces live on `name`, 0 if it is not in the layout.
  function slotsFor(name) {
    const i = indexFor(name);
    return i < 0 ? 0 : outputs[i].workspaces;
  }

  // The id before the first workspace on `name`: its workspaces are this plus
  // 1 .. slotsFor(name).
  function baseFor(name) {
    const i = indexFor(name);
    return i < 0 ? 0 : outputs[i].first - 1;
  }
}
