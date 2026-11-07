import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.basalt.bar.modules
import qs.basalt.theme
import qs.basalt.updates

// Persistent top status bar — one PanelWindow per monitor (Variants over
// Quickshell.screens), so each bar shows only its own output's modules. Left:
// per-monitor workspace pips. Center: clock + calendar. Right: the host's own
// items (Host.barItems), the application tray (whatever apps have registered,
// so possibly nothing), then the system modules, then power.
//
// powerMenu, settings and updates are the toplevels from shell.qml, injected so
// the modules can open them directly (same process, no IPC hop). They are passed
// down rather than created here precisely because this is a Variants: anything
// built inside would exist once per monitor.
Variants {
  id: bar
  model: Quickshell.screens
  property var powerMenu
  property var settings
  property var updates

  PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "quickshell:bar"

    Rectangle {
      anchors.fill: parent
      color: Theme.barBackground

      // ---- left: workspace pips for this monitor, then the shown workspace's
      // column layout (nothing on dwindle) ----
      RowLayout {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        anchors.leftMargin: Theme.space4
        spacing: Theme.space2

        Workspaces { screen: win.screen }
        Columns { screen: win.screen }
      }

      // ---- center: clock + calendar ----
      RowLayout {
        anchors.centerIn: parent
        spacing: Theme.space2

        BarClock { barWindow: win }
      }

      // ---- right: the host's items, the tray, system modules + power ----
      RowLayout {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        anchors.rightMargin: Theme.space4
        spacing: Theme.space2

        Repeater {
          model: Host.barItems
          delegate: Loader {
            required property var modelData
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: modelData
            // An item that wants its bar's window (to anchor a popup) gets it.
            onLoaded: if (item && "barWindow" in item) item.barWindow = win // qmllint disable missing-property
          }
        }
        Tray { barWindow: win }
        Cpu {}
        Memory {}
        Battery {}
        Audio { settings: bar.settings }
        Updates { window: bar.updates; visible: Host.updatesStatus.length > 0 }
        Bluetooth { settings: bar.settings }
        Network { settings: bar.settings }
        Power { powerMenu: bar.powerMenu }
      }
    }
  }
}
