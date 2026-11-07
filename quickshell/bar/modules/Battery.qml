import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.basalt.bar
import qs.basalt.theme

// Battery module (UPower). Hidden on desktops (no laptop battery). Icon + percent
// tinted by threshold (crit <=15, warn <=30, charging = success). Click opens a
// small popup with charge state and time remaining.
Rectangle {
  id: root
  readonly property var dev: UPower.displayDevice
  readonly property bool present: dev ? dev.isLaptopBattery : false
  readonly property int pct: dev ? Math.round(dev.percentage * 100) : 0
  readonly property int st: dev ? dev.state : 0
  readonly property bool charging: st === UPowerDeviceState.Charging
                                 || st === UPowerDeviceState.FullyCharged

  visible: present
  Layout.alignment: Qt.AlignVCenter
  implicitHeight: Theme.barHeight - 8
  implicitWidth: brow.implicitWidth + Theme.space4
  radius: Theme.radiusMd
  color: pop.visible ? Theme.accentTintHover
       : hover.hovered ? Theme.accentTintSoft : "transparent"

  readonly property var icons: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
  readonly property color tone:
      (pct <= 15 && !charging) ? Theme.accentDanger
    : (pct <= 30 && !charging) ? Theme.accentWarning
    : charging ? Theme.accentSuccess
    : Theme.fgSecondary

  RowLayout {
    id: brow
    anchors.centerIn: parent
    spacing: Theme.space2
    Text {
      text: root.charging ? "\uf0e7" : root.icons[Math.min(4, Math.floor(root.pct / 20))]
      font.family: Theme.fontGlyph
      font.pixelSize: Theme.textBody
      color: root.tone
    }
    Text {
      text: root.pct + "%"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textLabel
      font.weight: Theme.weightMedium
      color: root.tone
    }
  }

  HoverHandler { id: hover }
  TapHandler { onTapped: pop.visible = !pop.visible }

  readonly property string stateText:
      st === UPowerDeviceState.Charging ? "Charging"
    : st === UPowerDeviceState.Discharging ? "Discharging"
    : st === UPowerDeviceState.FullyCharged ? "Full"
    : "—"
  readonly property string timeText: {
    if (!dev) return "";
    var s = charging ? dev.timeToFull : dev.timeToEmpty;
    if (!s || s <= 0) return "";
    var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    return (charging ? "Full in " : "Empty in ") + h + "h " + m + "m";
  }

  BarPopup {
    id: pop
    anchorItem: root
    contentWidth: 220

    Text {
      width: parent.width
      text: "Battery"
      color: Theme.fgEmphasis
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textLabel
      font.weight: Theme.weightBold
    }
    Text {
      width: parent.width
      text: root.pct + "%  ·  " + root.stateText
      color: Theme.fgSecondary
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }
    Text {
      width: parent.width
      visible: root.timeText.length > 0
      text: root.timeText
      color: Theme.fgMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }
  }
}
