import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.basalt.shared
import qs.basalt.theme

// Left-side workspace pips for THIS bar's monitor. Persistent workspaces mean all
// slots always exist; which ids belong to this output comes from the Display
// singleton, which reads the layout Hyprland's workspace rules were built from
// (hypr/display.lua).
//
// After an undock, windows from the external monitor's workspaces can end up on
// the remaining monitor under ids outside its own range. Those get a pip of their own, labelled
// with the bare id, for as long as they hold windows — otherwise they would be
// on the monitor but nowhere in the bar.
//
// Each pip is labeled in "<monitor>×<slot>" chord notation to match the
// SUPER+<mon> then <slot> keybinds, where <monitor> is the output's position in
// that layout. Click focuses the workspace via Hyprland IPC directly (this is
// what Waybar's on-click couldn't do under Hyprland's Lua config).
RowLayout {
  id: root
  property var screen
  spacing: Theme.space1

  // Recompute state on every Hyprland event (window open/close, focus change).
  // ignoreUnknownSignals keeps this quiet if the signal name differs across builds;
  // the property-notify bindings below still drive most updates.
  property int tick: 0
  Connections {
    target: Hyprland
    ignoreUnknownSignals: true
    function onRawEvent(event) { root.tick++ }
  }

  readonly property var monitor: {
    var ms = Hyprland.monitors.values;
    for (var i = 0; i < ms.length; i++)
      if (screen && ms[i].name === screen.name) return ms[i];
    return null;
  }
  // Position in the layout, not Hyprland's runtime monitor.id: the ids are
  // assigned in connection order, while the chord binds and the workspace ids
  // both follow the layout's.
  readonly property int monIndex: monitor ? Display.indexFor(monitor.name) : 0
  readonly property int base: monitor ? Display.baseFor(monitor.name) : 0
  readonly property int slotCount: monitor ? Display.slotsFor(monitor.name) : 0

  readonly property var slots: {
    var t = tick;                          // dependency: recompute on hypr events
    var wsList = Hyprland.workspaces.values;
    var mon = monitor;
    var fm = Hyprland.focusedMonitor;      // dependency: focus moved between outputs
    var focusedMonName = fm ? fm.name : "";
    var isFocusedMon = mon ? mon.name === focusedMonName : false;
    var shownId = mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1;
    var arr = [];
    for (var s = 0; s < slotCount; s++) {
      var id = base + s + 1;
      var ws = null;
      for (var i = 0; i < wsList.length; i++)
        if (wsList[i].id === id) { ws = wsList[i]; break; }
      // Use the live per-workspace toplevel list, not lastIpcObject.windows —
      // the latter goes stale for background workspaces on the non-focused monitor
      // (Quickshell doesn't always refresh it), while toplevels stays correct.
      var windows = ws && ws.toplevels ? ws.toplevels.values.length : 0;
      var isShown = id === shownId;        // the workspace currently displayed on this monitor
      arr.push({
        wsId: id,
        label: (monIndex + 1) + "×" + (s + 1),
        occupied: windows > 0,
        shown: isShown,
        active: isShown && isFocusedMon,   // displayed on the focused monitor
        visible: isShown && !isFocusedMon, // displayed on the other monitor
        urgent: ws ? ws.urgent === true : false
      });
    }
    // Strays: any other ordinary workspace on this monitor that has windows.
    for (var j = 0; j < wsList.length; j++) {
      var w = wsList[j];
      if (!mon || !w.monitor || w.monitor.name !== mon.name) continue;
      if (w.id <= 0 || (w.id > base && w.id <= base + slotCount)) continue;
      if (!w.toplevels || w.toplevels.values.length === 0) continue;
      var wShown = w.id === shownId;
      arr.push({
        wsId: w.id,
        label: String(w.id),
        occupied: true,
        shown: wShown,
        active: wShown && isFocusedMon,
        visible: wShown && !isFocusedMon,
        urgent: w.urgent === true
      });
    }
    return arr;
  }

  Repeater {
    model: root.slots
    delegate: Rectangle {
      id: pip
      required property var modelData
      Layout.alignment: Qt.AlignVCenter
      implicitHeight: Theme.barHeight - 10
      implicitWidth: lbl.implicitWidth + Theme.space6
      radius: Theme.radiusMd
      color: modelData.urgent  ? Theme.accentDanger
           : modelData.active  ? Theme.accentPrimary
           : modelData.visible ? Theme.accentTintSoft
           : hover.hovered     ? Theme.accentTintHover
           : "transparent"

      Text {
        id: lbl
        anchors.centerIn: parent
        text: pip.modelData.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textLabel
        font.weight: Theme.weightMedium
        color: (pip.modelData.urgent || pip.modelData.active) ? Theme.fgOnAccent
             : pip.modelData.visible ? Theme.accentPrimary
             : Theme.fgSecondary
      }

      // Occupancy badge: a small dot on the top-right when this workspace has
      // windows (replaces Waybar's occupied-vs-empty font-color cue). Hidden on the
      // active pip (you're already there and it's fully highlighted). The dark
      // outline keeps it legible over any pip background.
      Rectangle {
        visible: pip.modelData.occupied && !pip.modelData.shown
        width: 7; height: 7; radius: height / 2
        anchors { top: parent.top; right: parent.right; topMargin: 3; rightMargin: 3 }
        color: Theme.accentPrimary
        border.width: 1
        border.color: Theme.barBackground
      }

      HoverHandler { id: hover }
      // Click-to-focus. Hyprland 0.55's Lua config wraps dispatch requests as
      // `return hl.dispatch(<X>)`, so a plain "workspace N" is invalid Lua (the bug
      // that left Waybar's click inert). Quickshell's Hyprland.dispatch() also had
      // no effect here, so we shell out to hyprctl with the Lua-shorthand
      // hl.dsp.focus({workspace=N}) form, which is verified to switch.
      TapHandler {
        onTapped: Quickshell.execDetached(
          ["hyprctl", "dispatch", "hl.dsp.focus({workspace=" + pip.modelData.wsId + "})"])
      }
    }
  }
}
