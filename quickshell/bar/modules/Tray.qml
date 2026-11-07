import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.basalt.theme

// Tray icons that applications register at runtime (StatusNotifierItem) — Slack,
// Nextcloud, nm-applet, Steam and the like. Unlike every other module in the
// bar, nothing here is known in advance: the row is whatever SystemTray.items
// holds right now, and it collapses to nothing when no application has an icon
// up.
//
// Named Tray rather than SystemTray because Quickshell.Services.SystemTray
// already exports a `SystemTray` type, which would win the name lookup — the
// way QtQuick's own `Palette` would shadow a singleton of that name.
//
// Quickshell owns the StatusNotifierWatcher for the session, so this works with
// no extra daemon. An app that only speaks the old XEmbed tray protocol will
// not show up here; nothing on Wayland can host those.
//
// Clicks follow the convention the apps expect:
//   left    activate(), or the menu if the item says it is menu-only
//   middle  secondaryActivate()
//   right   the item's own menu (DBusMenu), drawn by Quickshell
//   wheel   scroll(), which some apps map to volume or switching accounts
RowLayout {
  id: root
  // The PanelWindow this row sits in. display() opens the menu as a popup of
  // that window, at coordinates relative to it.
  property var barWindow

  visible: SystemTray.items.values.length > 0 // qmllint disable missing-property
  spacing: Theme.space1

  Repeater {
    model: SystemTray.items

    delegate: Rectangle {
      id: slot
      required property SystemTrayItem modelData

      readonly property bool attention: modelData.status === Status.NeedsAttention

      function showMenu() {
        if (!modelData.hasMenu || !root.barWindow) return;
        const p = slot.mapToItem(null, 0, slot.height);
        modelData.display(root.barWindow, Math.round(p.x), Math.round(p.y));
      }

      Layout.alignment: Qt.AlignVCenter
      implicitWidth: 26
      implicitHeight: Theme.barHeight - 8
      radius: Theme.radiusMd
      color: attention ? Theme.accentTintHover
           : hover.hovered ? Theme.accentTintSoft
           : "transparent"

      IconImage {
        anchors.centerIn: parent
        implicitSize: 16
        source: slot.modelData.icon
      }

      HoverHandler { id: hover }

      TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onTapped: (eventPoint, button) => {
          if (button === Qt.RightButton) slot.showMenu();
          else if (button === Qt.MiddleButton) slot.modelData.secondaryActivate();
          else if (slot.modelData.onlyMenu) slot.showMenu();
          else slot.modelData.activate();
        }
      }

      WheelHandler {
        onWheel: (event) => {
          const horizontal = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y);
          slot.modelData.scroll(horizontal ? event.angleDelta.x : event.angleDelta.y, horizontal);
        }
      }
    }
  }
}
