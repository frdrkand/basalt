import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.basalt.bar
import qs.basalt.shared
import qs.basalt.theme

// Bluetooth module. State is read reactively from Quickshell.Bluetooth; actions go
// through bluetoothctl. Hidden when there's no adapter. Left-click opens a popup
// (power toggle + bonded device list with battery); right-click toggles adapter
// power. "Manage devices" opens the Settings window on its Bluetooth tab.
Rectangle {
  id: root
  property var settings                      // Settings window (from shell.qml)
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool enabled: adapter ? adapter.enabled : false
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property int connectedCount: {
    var n = 0;
    for (var i = 0; i < devices.length; i++) if (devices[i].connected) n++;
    return n;
  }

  // BlueZ reports battery as 0–1; normalise in case a backend hands over 0–100.
  function batteryPct(d) {
    return d.battery <= 1 ? Math.round(d.battery * 100) : Math.round(d.battery);
  }
  function batteryColor(pct, fallback) {
    return pct <= 5 ? Theme.accentDanger : pct <= 10 ? Theme.accentWarning : fallback;
  }

  // Lowest battery among connected devices that report one; -1 when none do.
  readonly property int lowestBattery: {
    var low = -1;
    for (var i = 0; i < devices.length; i++) {
      var d = devices[i];
      if (!d.connected || !d.batteryAvailable) continue;
      var p = batteryPct(d);
      if (low < 0 || p < low) low = p;
    }
    return low;
  }

  visible: adapter !== null
  Layout.alignment: Qt.AlignVCenter
  implicitHeight: Theme.barHeight - 8
  implicitWidth: 26
  radius: Theme.radiusMd
  color: pop.visible ? Theme.accentTintHover
       : hover.hovered ? Theme.accentTintSoft : "transparent"

  function power(on) { Quickshell.execDetached(["bluetoothctl", "power", on ? "on" : "off"]); }

  Text {
    anchors.centerIn: parent
    text: "\uf293"   // nf-fa-bluetooth
    font.family: Theme.fontGlyph
    font.pixelSize: Theme.textBody
    color: !root.enabled ? Theme.fgMuted
         : root.lowestBattery >= 0 ? root.batteryColor(root.lowestBattery, Theme.fgSecondary)
         : Theme.fgSecondary
  }

  HoverHandler { id: hover }
  TapHandler { acceptedButtons: Qt.LeftButton; onTapped: pop.visible = !pop.visible }
  TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.power(!root.enabled) }

  BarPopup {
    id: pop
    anchorItem: root
    contentWidth: 280

    // header + power toggle
    RowLayout {
      width: parent.width
      Text {
        Layout.fillWidth: true
        text: "Bluetooth"
        color: Theme.fgEmphasis
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textLabel
        font.weight: Theme.weightBold
      }
      ToggleSwitch {
        checked: root.enabled
        onToggled: (v) => root.power(v)
      }
    }

    // bonded / connected devices
    Repeater {
      model: root.devices
      delegate: Rectangle {
        id: devRow
        required property var modelData
        readonly property bool show: modelData.bonded || modelData.paired || modelData.connected
        width: parent.width
        height: show ? 34 : 0
        visible: show
        radius: Theme.radiusMd
        color: dhover.hovered ? Theme.bgSurfaceHover : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.space3
          anchors.rightMargin: Theme.space3
          spacing: Theme.space3
          Text {
            text: "\uf293"
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textCaption
            color: devRow.modelData.connected ? Theme.accentPrimary : Theme.fgMuted
          }
          Text {
            Layout.fillWidth: true
            text: devRow.modelData.name || devRow.modelData.address
            elide: Text.ElideRight
            color: Theme.fgPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textCaption
          }
          Text {
            visible: devRow.modelData.batteryAvailable
            text: root.batteryPct(devRow.modelData) + "%"
            color: root.batteryColor(root.batteryPct(devRow.modelData), Theme.fgMuted)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textMicro
          }
          Text {
            visible: devRow.modelData.connected
            text: "\uf00c"   // check
            color: Theme.accentSuccess
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textMicro
          }
        }
        HoverHandler { id: dhover }
        TapHandler {
          onTapped: Quickshell.execDetached(
            ["bluetoothctl", devRow.modelData.connected ? "disconnect" : "connect", devRow.modelData.address])
        }
      }
    }

    // open full settings
    Rectangle {
      width: parent.width
      height: 28
      radius: Theme.radiusMd
      color: shover.hovered ? Theme.bgSurfaceHover : Theme.bgSurface
      Text {
        anchors.centerIn: parent
        text: "Manage devices"
        color: Theme.fgSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
      }
      HoverHandler { id: shover }
      TapHandler { onTapped: { if (root.settings) root.settings.open("bluetooth"); pop.visible = false; } }
    }
  }
}
