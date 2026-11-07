import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.basalt.shared
import qs.basalt.theme

// Power menu: one large button per PowerActions entry (icon over label) in a
// horizontal row, shown on the focused monitor as a layer-shell overlay.
// Toggled via IPC; also closes on Escape and on click outside the card.
// Keyboard: Left/Right move the highlight, wrapping at the ends; Enter
// activates, 1-9 are direct hotkeys (shown in each button's corner). Mouse:
// hover highlights, click activates.
//
// Nothing here is sized or numbered for a fixed count: the card's implicitWidth
// follows the row, and the hotkey range follows the list.
Scope {
  id: root

  property bool shown: false
  function toggle() { shown = !shown }
  function open()   { shown = true }
  function close()  { shown = false }

  // Resolve the ShellScreen for Hyprland's currently focused monitor so the
  // overlay appears where the user is looking.
  function focusedScreen() {
    const fm = Hyprland.focusedMonitor;
    if (!fm) return null;
    const screens = Quickshell.screens;
    for (let i = 0; i < screens.length; i++) {
      if (screens[i].name === fm.name) return screens[i];
    }
    return null;
  }

  LazyLoader {
    active: root.shown

    PanelWindow {
      id: win
      screen: root.focusedScreen()
      anchors { left: true; right: true; top: true; bottom: true }
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.namespace: "quickshell:powermenu"

      // Click anywhere outside the card dismisses.
      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
      }

      FocusScope {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onEscapePressed: root.close()
        Keys.onLeftPressed:   card.move(-1)
        Keys.onRightPressed:  card.move(1)
        Keys.onReturnPressed: card.activate()
        Keys.onEnterPressed:  card.activate()
        // Derived from the list rather than hardcoded, so adding an action to
        // PowerActions.qml gives it a hotkey. Capped at 9 because Qt.Key_0 does
        // not continue the run.
        Keys.onPressed: (event) => {
          const n = Math.min(PowerActions.list.length, 9);
          if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + n) {
            card.selected = event.key - Qt.Key_1;
            card.activate();
            event.accepted = true;
          }
        }

        Rectangle {
          id: card
          anchors.centerIn: parent
          radius: Theme.radiusXl
          color: Theme.popupBackground
          border.color: Theme.borderSubtle
          border.width: 1
          implicitWidth: row.implicitWidth + 48
          implicitHeight: row.implicitHeight + 48

          property int selected: 0
          function move(d) {
            const n = PowerActions.list.length;
            if (n === 0) return;
            selected = (selected + d + n) % n;
          }
          function activate() {
            Quickshell.execDetached(PowerActions.list[selected].command);
            root.close();
          }

          // Swallow clicks on the card so they don't reach the dismiss area.
          MouseArea { anchors.fill: parent }

          RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 16

            Repeater {
              model: PowerActions.list
              delegate: Rectangle {
                id: button
                required property int index
                required property var modelData
                Layout.preferredWidth: 120
                Layout.preferredHeight: 120
                radius: Theme.radiusLg
                color: card.selected === index ? Theme.bgSurfaceHover : Theme.bgSurface

                // Hotkey hint in the corner; only 1-9 exist (see Keys.onPressed).
                Text {
                  visible: button.index < 9
                  text: button.index + 1
                  anchors { top: parent.top; left: parent.left; margins: 8 }
                  font.family: Theme.fontMono
                  font.pixelSize: 12
                  color: card.selected === button.index ? Theme.fgSecondary : Theme.fgMuted
                }

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: 10
                  Text {
                    text: String.fromCodePoint(button.modelData.codepoint)
                    font.family: Theme.fontGlyph
                    font.pixelSize: 44
                    color: Theme.fgPrimary
                    Layout.alignment: Qt.AlignHCenter
                  }
                  Text {
                    text: button.modelData.label
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    color: Theme.fgPrimary
                    Layout.alignment: Qt.AlignHCenter
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: card.selected = button.index
                  onClicked: { card.selected = button.index; card.activate(); }
                }
              }
            }
          }
        }
      }
    }
  }
}
