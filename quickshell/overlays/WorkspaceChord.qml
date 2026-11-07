import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.basalt.theme

// Transient hint shown while a workspace chord submap is active (see the
// WORKSPACE CHORDS section of hypr/binds.lua). Hyprland shows it
// when a switch/move submap is entered and hides it when the chord resolves or
// is cancelled, via `qs ipc call wschord ...`.
//
// Purely visual: it takes NO keyboard focus and is click-through, so the 1-5
// and Escape keys are handled by Hyprland's submap, not this window.
Scope {
  id: root

  property bool   shown: false
  property string prompt: ""       // heading text
  property string screenName: ""   // output to display on
  property int    slotCount: 5

  // Switch: opens on the chosen monitor, which is itself the switch target.
  function showSwitch(monitorName) {
    root.prompt = "Switch to workspace:";
    root.screenName = monitorName;
    root.shown = true;
  }

  // Move: opens on the currently active monitor and names the chosen target.
  function showMove(monitorLabel) {
    const fm = Hyprland.focusedMonitor;
    root.screenName = fm ? fm.name : "";
    root.prompt = "Move to monitor " + monitorLabel + ", workspace:";
    root.shown = true;
  }

  function hide() { root.shown = false }

  function screenFor(name) {
    const screens = Quickshell.screens;
    for (let i = 0; i < screens.length; i++)
      if (screens[i].name === name) return screens[i];
    return null;
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
      WlrLayershell.namespace: "quickshell:wschord"

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
            text: root.prompt
            font.family: Theme.fontFamily
            font.pixelSize: 20
            color: Theme.fgPrimary
            Layout.alignment: Qt.AlignHCenter
          }

          RowLayout {
            spacing: 12
            Layout.alignment: Qt.AlignHCenter
            Repeater {
              model: root.slotCount
              delegate: Rectangle {
                required property int index
                implicitWidth: 48
                implicitHeight: 48
                radius: Theme.radiusLg
                color: Theme.bgSurface
                Text {
                  anchors.centerIn: parent
                  text: index + 1
                  font.family: Theme.fontFamily
                  font.pixelSize: 22
                  color: Theme.fgPrimary
                }
              }
            }
          }
        }
      }
    }
  }
}
