import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.basalt.bar
import qs.basalt.theme

// Network module. Quickshell.Networking is heavy/unstable in 0.3.0, so this polls
// nmcli (matches the repo's script-driven approach). Shows wifi SSID / ethernet /
// disconnected; click opens a popup with the connection name + IP and a settings
// launcher. Refreshes every 5s and on click.
Rectangle {
  id: root
  property var settings          // Settings window (from shell.qml)
  property string netType: ""    // "wifi" | "ethernet" | "other" | ""
  property string netName: ""
  property string netIp: ""
  readonly property bool connected: netName.length > 0

  Layout.alignment: Qt.AlignVCenter
  implicitHeight: Theme.barHeight - 8
  implicitWidth: nrow.implicitWidth + Theme.space4
  radius: Theme.radiusMd
  color: pop.visible ? Theme.accentTintHover
       : hover.hovered ? Theme.accentTintSoft : "transparent"

  function refresh() { proc.running = false; proc.running = true; }

  Process {
    id: proc
    command: ["sh", "-c",
      "line=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | grep -v ':loopback:' | grep -v ':bridge:' | head -1); " +
      "name=$(printf '%s' \"$line\" | cut -d: -f1); type=$(printf '%s' \"$line\" | cut -d: -f2); dev=$(printf '%s' \"$line\" | cut -d: -f3); " +
      "ip=$(nmcli -g IP4.ADDRESS device show \"$dev\" 2>/dev/null | head -1 | cut -d/ -f1); " +
      "printf '%s\\n%s\\n%s' \"$type\" \"$name\" \"$ip\""]
    stdout: StdioCollector {
      id: out
      onStreamFinished: {
        var lines = out.text.split("\n");
        var t = (lines[0] || "").trim();
        root.netName = (lines[1] || "").trim();
        root.netIp = (lines[2] || "").trim();
        root.netType = (t.indexOf("wireless") >= 0 || t.indexOf("wifi") >= 0) ? "wifi"
                     : (t.indexOf("ethernet") >= 0) ? "ethernet"
                     : (root.netName.length > 0 ? "other" : "");
      }
    }
  }

  Component.onCompleted: refresh()
  Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refresh() }

  RowLayout {
    id: nrow
    anchors.centerIn: parent
    spacing: Theme.space2
    Text {
      text: root.netType === "wifi" ? "\uf1eb"          // wifi
          : root.netType === "ethernet" ? "\uf0e8"      // sitemap (wired)
          : root.connected ? "\uf0ac"                   // globe
          : "\uf127"                                    // chain-broken
      font.family: Theme.fontGlyph
      font.pixelSize: Theme.textBody
      color: root.connected ? Theme.fgSecondary : Theme.accentDanger
    }
    Text {
      visible: root.netType === "wifi" && root.netName.length > 0
      text: root.netName
      elide: Text.ElideRight
      Layout.maximumWidth: 120
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textLabel
      font.weight: Theme.weightMedium
      color: Theme.fgSecondary
    }
  }

  HoverHandler { id: hover }
  TapHandler { onTapped: { root.refresh(); pop.visible = !pop.visible; } }

  BarPopup {
    id: pop
    anchorItem: root
    contentWidth: 260

    Text {
      width: parent.width
      text: "Network"
      color: Theme.fgEmphasis
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textLabel
      font.weight: Theme.weightBold
    }
    Text {
      width: parent.width
      text: root.connected ? root.netName : "Disconnected"
      color: root.connected ? Theme.fgSecondary : Theme.accentDanger
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }
    Text {
      width: parent.width
      visible: root.netIp.length > 0
      text: "IP  " + root.netIp
      color: Theme.fgMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }
    Rectangle {
      width: parent.width
      height: 28
      radius: Theme.radiusMd
      color: shover.hovered ? Theme.bgSurfaceHover : Theme.bgSurface
      Text {
        anchors.centerIn: parent
        text: "Manage networks"
        color: Theme.fgSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
      }
      HoverHandler { id: shover }
      TapHandler { onTapped: { if (root.settings) root.settings.open("network"); pop.visible = false; } }
    }
  }
}
