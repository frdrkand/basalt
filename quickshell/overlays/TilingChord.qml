import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.basalt.bar.modules
import qs.basalt.theme

// Popup for the tiling chord (TILING CHORD in hypr/binds.lua). It draws the
// slices as they are typed, using the same picture as the bar's layout icon
// (ColumnsPicture.qml) but large, with each slice's share written in it.
// Hyprland drives it over `qs ipc call tiling ...`: start when SUPER+T opens
// the chord, update after each digit or BackSpace, then applied / dwindle /
// failed (shown briefly, then hidden) or hide when it is cancelled.
//
// Purely visual, like WorkspaceChord.qml: it takes NO keyboard focus and is
// click-through, so the keys are handled by Hyprland's submap, not this window.
Scope {
  id: root

  property bool   shown: false
  property string screenName: ""
  property int    wsId: -1
  property var    weights: []      // the digits typed so far, as numbers
  // "typing" while the chord is open; "applied", "dwindle" or "failed" for the
  // moment between the chord ending and the popup closing.
  property string phase: "typing"
  property string error: ""

  // Each keypress is its own `qs ipc call` process, so two calls close together
  // can arrive out of order. Hyprland numbers them (one count for the whole
  // session), and a call older than the last one seen is dropped. Every call
  // carries the whole state, so a dropped one loses nothing.
  property int lastSeq: 0
  function fresh(seq) {
    if (seq <= root.lastSeq) return false;
    root.lastSeq = seq;
    return true;
  }

  // How long a result stays up.
  readonly property int resultMs: 700

  // Opens on the focused monitor, for its active workspace: that is the one the
  // chord applies to. Done by whichever call of a chord arrives first, since
  // the start call itself may be the one that arrived late.
  function open() {
    if (root.shown && root.phase === "typing") return;
    const fm = Hyprland.focusedMonitor;
    root.screenName = fm ? fm.name : "";
    root.wsId = fm && fm.activeWorkspace ? fm.activeWorkspace.id : -1;
    root.phase = "typing";
    closeTimer.stop();
    root.shown = true;
  }

  function start(seq) { if (fresh(seq)) { open(); setDigits("") } }

  // "121" -> [1, 2, 1]. Digits only, so they travel through the IPC call
  // without any quoting; "" is no slices yet.
  function update(seq, digits) { if (fresh(seq)) { open(); setDigits(digits) } }
  function setDigits(digits) {
    root.weights = digits.split("").map(Number).filter(function (n) { return n > 0; });
  }

  function applied(seq, digits) { if (fresh(seq)) { open(); setDigits(digits); finish("applied") } }
  function dwindle(seq)         { if (fresh(seq)) { open(); finish("dwindle") } }
  function failed(seq, message) { if (fresh(seq)) { open(); root.error = message; finish("failed") } }
  function hide(seq)            { if (fresh(seq)) { closeTimer.stop(); root.shown = false } }

  function finish(phase) {
    root.phase = phase;
    root.shown = true;
    closeTimer.restart();
  }

  Timer {
    id: closeTimer
    interval: root.resultMs
    onTriggered: root.shown = false
  }

  function screenFor(name) {
    const screens = Quickshell.screens;
    for (let i = 0; i < screens.length; i++)
      if (screens[i].name === name) return screens[i];
    return null;
  }

  readonly property string heading: {
    switch (root.phase) {
    case "applied": return "Applied to workspace " + root.wsId;
    case "dwindle": return "Workspace " + root.wsId + " back to dwindle";
    case "failed":  return "Not applied";
    default:        return "Columns for workspace " + root.wsId;
    }
  }

  LazyLoader {
    active: root.shown

    PanelWindow {
      screen: root.screenFor(root.screenName)
      anchors { left: true; right: true; top: true; bottom: true }
      color: "transparent"
      mask: Region {}   // empty region -> fully click-through

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "quickshell:tiling"

      Rectangle {
        anchors.centerIn: parent
        radius: Theme.radiusXl
        color: Theme.popupBackground
        border.color: Theme.borderSubtle
        border.width: 1
        implicitWidth: col.implicitWidth + 48
        implicitHeight: col.implicitHeight + 40

        ColumnLayout {
          id: col
          anchors.centerIn: parent
          spacing: 18

          Text {
            text: root.heading
            font.family: Theme.fontFamily
            font.pixelSize: 20
            color: Theme.fgPrimary
            Layout.alignment: Qt.AlignHCenter
          }

          // A screen, with the layout drawn in it.
          Rectangle {
            id: screenBox
            Layout.alignment: Qt.AlignHCenter
            readonly property int pad: 8
            implicitWidth: 300
            implicitHeight: 176
            radius: Theme.radiusLg
            color: Theme.bgCanvas
            border.color: Theme.borderSubtle
            border.width: 1

            readonly property int innerW: width - 2 * pad
            readonly property int innerH: height - 2 * pad

            // Typed slices (and, after Enter, the applied ones).
            ColumnsPicture {
              anchors.centerIn: parent
              visible: root.phase !== "dwindle" && root.phase !== "failed" && root.weights.length > 0
              weights: root.weights
              minWidth: screenBox.innerW - 6
              boxHeight: screenBox.innerH
              gap: 6
              radius: Theme.radiusLg
              labels: true
            }

            // Dwindle: one window left, two stacked right, as it splits.
            Item {
              anchors.fill: parent
              anchors.margins: screenBox.pad
              visible: root.phase === "dwindle"
              Rectangle {
                width: (parent.width - 6) / 2; height: parent.height
                radius: Theme.radiusLg; color: Theme.fgSecondary
              }
              Rectangle {
                x: (parent.width + 6) / 2
                width: (parent.width - 6) / 2; height: (parent.height - 6) / 2
                radius: Theme.radiusLg; color: Theme.fgSecondary
              }
              Rectangle {
                x: (parent.width + 6) / 2; y: (parent.height + 6) / 2
                width: (parent.width - 6) / 2; height: (parent.height - 6) / 2
                radius: Theme.radiusLg; color: Theme.fgSecondary
              }
            }

            Text {
              anchors.centerIn: parent
              width: screenBox.innerW - 16
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              visible: root.phase === "failed" || (root.phase === "typing" && root.weights.length === 0)
              text: root.phase === "failed" ? root.error : "Type a weight per slice\n1 2 1 is 25% · 50% · 25%"
              font.family: Theme.fontFamily
              font.pixelSize: 14
              lineHeight: 1.3
              color: Theme.fgMuted
            }
          }

          // The digits so far, as typed.
          Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.phase === "typing" || root.phase === "applied"
            text: root.weights.length > 0 ? root.weights.join("  ") : " "
            font.family: Theme.fontFamily
            font.pixelSize: 22
            color: Theme.fgPrimary
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.phase === "typing"
            text: "1–9 add a slice · Enter apply · BackSpace undo · d dwindle · Esc cancel"
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: Theme.fgMuted
          }
        }
      }
    }
  }
}
