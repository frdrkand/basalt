import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.basalt.shared
import qs.basalt.theme

// Bluetooth page of the Settings window — our replacement for blueman-manager.
// Lifted from the old BluetoothManager overlay: state is read reactively from
// Quickshell.Bluetooth, privileged actions shell out to bluetoothctl (BlueZ
// directly, no blueman mechanism). Discovery runs only while this tab is visible.
FocusScope {
  id: root

  property bool active: false
  signal backToNav()

  function focusFirst() { input.forceActiveFocus(); }

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool powered: adapter ? adapter.enabled : false
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  property string filter: ""

  function power(on) { Quickshell.execDetached(["bluetoothctl", "power", on ? "on" : "off"]); }
  function scan(on)  { if (adapter) adapter.discovering = on; }

  // primary per-row action: disconnect / connect / (pair+trust+connect)
  function activate(d) {
    if (!d) return;
    if (d.connected) {
      Quickshell.execDetached(["bluetoothctl", "disconnect", d.address]);
    } else if (d.bonded || d.paired) {
      Quickshell.execDetached(["bluetoothctl", "connect", d.address]);
    } else {
      // The address goes in as $1, not into the script text.
      // Pairable must be on: with it off (BlueZ's default at boot, normally
      // flipped by blueman or GNOME) the kernel pairs without bonding, so no key
      // is stored and the device can't reconnect by itself. Where BlueZ already
      // has it on, this is a no-op.
      Quickshell.execDetached(["sh", "-c",
        "bluetoothctl pairable on >/dev/null; bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && bluetoothctl connect \"$1\"",
        "sh", d.address]);
    }
  }
  function forget(d) { if (d) Quickshell.execDetached(["bluetoothctl", "remove", d.address]); }

  onActiveChanged: {
    if (active) scan(true);
    else { scan(false); filter = ""; input.text = ""; }
  }

  readonly property var results: {
    var q = filter.trim().toLowerCase();
    var arr = [];
    for (var i = 0; i < devices.length; i++) {
      var d = devices[i];
      if (!d) continue;
      var label = (d.name || d.address || "").toLowerCase();
      if (q.length === 0 || label.indexOf(q) >= 0) arr.push(d);
    }
    function rank(x) { return x.connected ? 0 : (x.bonded || x.paired) ? 1 : 2; }
    arr.sort(function (a, b) {
      if (rank(a) !== rank(b)) return rank(a) - rank(b);
      return (a.name || a.address || "").localeCompare(b.name || b.address || "");
    });
    return arr;
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Theme.space4

    // ---- header: title + adapter power toggle ----
    RowLayout {
      Layout.fillWidth: true
      Text {
        text: "\uf293  Bluetooth"
        color: Theme.fgEmphasis
        font.family: Theme.fontGlyph
        font.pixelSize: Theme.textTitle
        font.weight: Theme.weightBold
      }
      Item { Layout.fillWidth: true }
      Text {
        text: root.adapter && root.adapter.discovering ? "scanning…" : ""
        color: Theme.fgMuted
        font.family: Theme.fontUi
        font.pixelSize: Theme.textMicro
      }
      ToggleSwitch {
        checked: root.powered
        onToggled: (v) => root.power(v)
      }
    }

    // ---- search box (owns the keyboard for this page) ----
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 40
      radius: Theme.radiusLg
      color: Theme.bgSurface
      border.width: 1
      border.color: input.activeFocus ? Theme.borderFocus : "transparent"
      TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.space5
        anchors.rightMargin: Theme.space5
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.fgPrimary
        font.family: Theme.fontUi
        font.pixelSize: Theme.textBody
        selectByMouse: true
        selectionColor: Theme.bgSurfaceHover
        onTextChanged: root.filter = text

        Keys.onEscapePressed: root.backToNav()
        Keys.onLeftPressed:  (e) => { if (input.text.length === 0) { root.backToNav(); e.accepted = true; } else e.accepted = false; }
        Keys.onDownPressed:  (e) => { list.move(1); e.accepted = true; }
        Keys.onUpPressed:    (e) => { list.move(-1); e.accepted = true; }
        Keys.onReturnPressed: (e) => { root.activate(root.results[list.currentIndex]); e.accepted = true; }
        Keys.onEnterPressed:  (e) => { root.activate(root.results[list.currentIndex]); e.accepted = true; }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: input.text.length === 0
          text: "Search devices…"
          color: Theme.fgMuted
          font: input.font
        }
      }
    }

    // ---- device list ----
    ListView {
      id: list
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      model: root.results
      spacing: Theme.space1
      currentIndex: 0
      keyNavigationEnabled: false
      boundsBehavior: Flickable.StopAtBounds

      function move(d) {
        if (count === 0) return;
        currentIndex = Math.max(0, Math.min(count - 1, currentIndex + d));
        positionViewAtIndex(currentIndex, ListView.Contain);
      }
      onModelChanged: if (currentIndex >= count) currentIndex = 0

      delegate: Rectangle {
        id: row
        required property int index
        required property var modelData
        readonly property bool connected: modelData.connected
        readonly property bool known: modelData.bonded || modelData.paired
        // paired but no stored key: works now, won't reconnect on its own
        readonly property bool unsaved: modelData.paired && !modelData.bonded
        readonly property bool current: list.currentIndex === index && root.activeFocus

        width: list.width
        height: 52
        radius: Theme.radiusMd
        color: current || rhover.hovered ? Theme.bgSurfaceHover : "transparent"
        border.width: 1
        border.color: current ? Theme.borderFocus : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.space4
          anchors.rightMargin: Theme.space4
          spacing: Theme.space4

          Text {
            text: "\uf293"
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textTitle
            color: row.connected ? Theme.accentPrimary
                 : row.known ? Theme.fgSecondary : Theme.fgMuted
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              Layout.fillWidth: true
              text: row.modelData.name || row.modelData.address
              elide: Text.ElideRight
              color: Theme.fgPrimary
              font.family: Theme.fontUi
              font.pixelSize: Theme.textLabel
            }
            Text {
              text: {
                var s = row.connected ? "Connected" : row.known ? "Paired" : "Available";
                if (row.unsaved) s += "  ·  won't auto-reconnect, remove and pair again";
                if (row.modelData.batteryAvailable) {
                  var b = row.modelData.battery <= 1 ? Math.round(row.modelData.battery * 100)
                                                     : Math.round(row.modelData.battery);
                  s += "  ·  " + b + "%";
                }
                return s;
              }
              color: row.unsaved ? Theme.accentWarning
                   : row.connected ? Theme.accentSuccess : Theme.fgMuted
              font.family: Theme.fontUi
              font.pixelSize: Theme.textMicro
            }
          }
          // forget — known devices only, on hover or keyboard focus
          Text {
            visible: row.known && (rhover.hovered || row.current)
            text: "\uf1f8"   // trash
            color: fhover.hovered ? Theme.accentDanger : Theme.fgMuted
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textLabel
            HoverHandler { id: fhover }
            TapHandler { onTapped: root.forget(row.modelData) }
          }
        }
        HoverHandler { id: rhover }
        TapHandler {
          onTapped: {
            list.currentIndex = row.index;
            input.forceActiveFocus();
            root.activate(row.modelData);
          }
        }
      }
    }
  }
}
