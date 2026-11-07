import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.basalt.theme

// The column layout of the workspace shown on THIS bar's monitor, drawn as a
// small picture of the slices (ColumnsPicture.qml). Nothing for dwindle: the
// module collapses out of the row. No font has a glyph for arbitrary
// proportions, so the picture is drawn rather than looked up.
//
// The source is the state file hypr/columns.lua keeps in $XDG_RUNTIME_DIR, one
// line per workspace on lua:columns ("6 1 2 1"); a workspace that isn't listed
// is on dwindle. columns.lua rewrites it on every change and creates it when the
// config loads, so it exists before this watches it (a watch can't be put on a
// file that doesn't exist yet).
Item {
  id: root
  property var screen

  readonly property var monitor: {
    var ms = Hyprland.monitors.values;
    for (var i = 0; i < ms.length; i++)
      if (screen && ms[i].name === screen.name) return ms[i];
    return null;
  }
  readonly property int wsId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1

  // Workspace id -> weights, e.g. { "6": [1, 2, 1] }.
  property var layouts: ({})

  function parse(text) {
    var map = {};
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/);
      if (f.length < 2) continue;
      var w = f.slice(1).map(Number);
      if (w.every(function (x) { return x > 0; })) map[f[0]] = w;
    }
    layouts = map;
  }

  FileView {
    id: state
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hypr-columns.state"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(state.text())
    onLoadFailed: root.layouts = ({})
  }

  readonly property var weights: layouts[String(wsId)] || null
  visible: weights !== null

  Layout.alignment: Qt.AlignVCenter
  implicitHeight: Theme.barHeight - 8
  implicitWidth: pic.implicitWidth + Theme.space4

  ColumnsPicture {
    id: pic
    anchors.centerIn: parent
    weights: root.weights || []
  }
}
