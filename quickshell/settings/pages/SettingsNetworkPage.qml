import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.basalt.theme

// Wi-Fi page of the Settings window — our replacement for nm-connection-editor.
// Lifted from the old NetworkManager overlay: all state comes from nmcli via
// Process (matching the bar's approach, since Quickshell.Networking is unstable
// in 0.3.0), rescanning while the tab is visible and revealing a password field
// for secured networks we don't already have saved.
FocusScope {
  id: root

  property bool active: false
  signal backToNav()

  function focusFirst() { input.forceActiveFocus(); }

  property var rows: []            // [{ ssid, signal, secured, active }]
  property var saved: ({})         // set of saved connection names
  property string filter: ""
  property string selected: ""     // ssid awaiting a password
  property string status: ""

  // ---- nmcli terse (-t) line splitter: unescapes '\:' / '\\', splits on ':' ----
  function splitTerse(line) {
    var out = [], cur = "";
    for (var i = 0; i < line.length; i++) {
      var c = line[i];
      if (c === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++; }
      else if (c === ":") { out.push(cur); cur = ""; }
      else cur += c;
    }
    out.push(cur);
    return out;
  }

  function refresh() {
    savedProc.running = false; savedProc.running = true;
    listProc.running = false;  listProc.running = true;
  }

  function joinNetwork(ssid, password) {
    root.status = "Connecting to " + ssid + "…";
    // A password goes in through nmcli's prompt (--ask), not its arguments,
    // which any process can read from /proc while nmcli runs.
    connectProc.password = password || "";
    connectProc.stdinEnabled = connectProc.password.length > 0;
    connectProc.command = connectProc.stdinEnabled
      ? ["nmcli", "--ask", "device", "wifi", "connect", ssid]
      : ["nmcli", "device", "wifi", "connect", ssid];
    connectProc.running = false; connectProc.running = true;
  }
  function dropNetwork(ssid) {
    root.status = "Disconnecting…";
    dcProc.command = ["nmcli", "connection", "down", "id", ssid];
    dcProc.running = false; dcProc.running = true;
  }
  function forgetNetwork(ssid) {
    dcProc.command = ["nmcli", "connection", "delete", "id", ssid];
    dcProc.running = false; dcProc.running = true;
  }

  // activating a row: known/open connect immediately; secured+new asks for a password
  function tap(r) {
    if (!r) return;
    if (r.active) { root.selected = ""; return; }
    if (r.secured && !root.saved[r.ssid]) { root.selected = r.ssid; root.status = ""; }
    else { root.selected = ""; joinNetwork(r.ssid, ""); }
  }

  // Scan only while this tab is the visible one.
  onActiveChanged: {
    if (active) { refresh(); rescanProc.running = true; }
    else { filter = ""; selected = ""; status = ""; input.text = ""; }
  }

  // ---- processes ----
  Process {
    id: listProc
    command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list"]
    stdout: StdioCollector {
      id: listOut
      onStreamFinished: {
        var lines = listOut.text.split("\n");
        var seen = {}, arr = [];
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i]) continue;
          var f = root.splitTerse(lines[i]);
          var ssid = (f[3] || "").trim();
          if (ssid.length === 0) continue;
          var sig = parseInt(f[1] || "0") || 0;
          var row = { ssid: ssid, signal: sig,
                      secured: (f[2] || "").trim().length > 0,
                      active: (f[0] || "").indexOf("*") >= 0 };
          if (seen[ssid] !== undefined) {   // dedup, keep strongest / active
            if (row.active || sig > arr[seen[ssid]].signal) arr[seen[ssid]] = row;
          } else { seen[ssid] = arr.length; arr.push(row); }
        }
        arr.sort(function (a, b) {
          if (a.active !== b.active) return a.active ? -1 : 1;
          return b.signal - a.signal;
        });
        root.rows = arr;
      }
    }
  }
  Process {
    id: savedProc
    command: ["nmcli", "-t", "-g", "NAME", "connection", "show"]
    stdout: StdioCollector {
      id: savedOut
      onStreamFinished: {
        var s = {}, lines = savedOut.text.split("\n");
        for (var i = 0; i < lines.length; i++) { var n = lines[i].trim(); if (n) s[n] = true; }
        root.saved = s;
      }
    }
  }
  Process { id: rescanProc; command: ["nmcli", "device", "wifi", "rescan"] }
  Process {
    id: connectProc
    property string password: ""
    onStarted: {
      if (!stdinEnabled) return;
      write(password + "\n");
      password = "";
      // Then EOF, so a second prompt (a wrong password) fails rather than waits.
      stdinEnabled = false;
    }
    stdout: StdioCollector { id: cOut }
    stderr: StdioCollector { id: cErr }
    onExited: (code) => {
      root.status = code === 0 ? "Connected" : (cErr.text.trim() || "Failed to connect");
      root.selected = "";
      root.refresh();
    }
  }
  Process { id: dcProc; onExited: (code) => root.refresh() }

  // rescan periodically while the tab is open
  Timer {
    interval: 10000; repeat: true; running: root.active
    onTriggered: { rescanProc.running = true; root.refresh(); }
  }

  readonly property var results: {
    var q = filter.trim().toLowerCase();
    if (q.length === 0) return rows;
    var arr = [];
    for (var i = 0; i < rows.length; i++)
      if (rows[i].ssid.toLowerCase().indexOf(q) >= 0) arr.push(rows[i]);
    return arr;
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Theme.space4

    // ---- header ----
    RowLayout {
      Layout.fillWidth: true
      Text {
        text: "\uf1eb  Wi-Fi"   // wifi
        color: Theme.fgEmphasis
        font.family: Theme.fontGlyph
        font.pixelSize: Theme.textTitle
        font.weight: Theme.weightBold
      }
      Item { Layout.fillWidth: true }
      Text {
        text: root.status
        elide: Text.ElideRight
        Layout.maximumWidth: 280
        color: root.status.indexOf("Fail") >= 0 ? Theme.accentDanger : Theme.fgMuted
        font.family: Theme.fontUi
        font.pixelSize: Theme.textMicro
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
        Keys.onReturnPressed: (e) => { root.tap(root.results[list.currentIndex]); e.accepted = true; }
        Keys.onEnterPressed:  (e) => { root.tap(root.results[list.currentIndex]); e.accepted = true; }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: input.text.length === 0
          text: "Search networks…"
          color: Theme.fgMuted
          font: input.font
        }
      }
    }

    // ---- network list ----
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
        readonly property bool current: list.currentIndex === index && root.activeFocus

        width: list.width
        height: 46
        radius: Theme.radiusMd
        color: current || rhover.hovered ? Theme.bgSurfaceHover
             : modelData.active ? Theme.accentTintSoft : "transparent"
        border.width: 1
        border.color: current ? Theme.borderFocus : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.space4
          anchors.rightMargin: Theme.space4
          spacing: Theme.space4

          Text {
            text: "\uf1eb"   // wifi
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textBody
            color: row.modelData.active ? Theme.accentPrimary
                 : row.modelData.signal >= 55 ? Theme.fgSecondary : Theme.fgMuted
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              Layout.fillWidth: true
              text: row.modelData.ssid
              elide: Text.ElideRight
              color: Theme.fgPrimary
              font.family: Theme.fontUi
              font.pixelSize: Theme.textLabel
            }
            Text {
              text: row.modelData.signal + "%"
                    + (root.saved[row.modelData.ssid] ? "  ·  saved" : "")
              color: Theme.fgMuted
              font.family: Theme.fontUi
              font.pixelSize: Theme.textMicro
            }
          }
          Text {
            visible: row.modelData.secured
            text: "\uf023"   // lock
            color: Theme.fgMuted
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textCaption
          }
          Text {
            visible: row.modelData.active
            text: "\uf00c"   // check
            color: Theme.accentSuccess
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textCaption
          }
          // disconnect (active) / forget (saved), on hover or keyboard focus
          Text {
            visible: (rhover.hovered || row.current)
                     && (row.modelData.active || root.saved[row.modelData.ssid])
            text: row.modelData.active ? "\uf00d" : "\uf1f8"   // times / trash
            color: xhover.hovered ? Theme.accentDanger : Theme.fgMuted
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textCaption
            HoverHandler { id: xhover }
            TapHandler {
              onTapped: row.modelData.active ? root.dropNetwork(row.modelData.ssid)
                                             : root.forgetNetwork(row.modelData.ssid)
            }
          }
        }
        HoverHandler { id: rhover }
        TapHandler {
          onTapped: {
            list.currentIndex = row.index;
            input.forceActiveFocus();
            root.tap(row.modelData);
          }
        }
      }

      // Empty on a machine with no Wi-Fi radio (this desktop is wired-only), or
      // before the first scan lands — say so rather than showing a blank page.
      Text {
        anchors.centerIn: parent
        visible: list.count === 0
        text: root.filter.length > 0 ? "No networks match “" + root.filter + "”"
                                     : "No Wi-Fi networks found"
        color: Theme.fgMuted
        font.family: Theme.fontUi
        font.pixelSize: Theme.textCaption
      }
    }

    // ---- password bar (secured + new network) ----
    Rectangle {
      Layout.fillWidth: true
      visible: root.selected.length > 0
      Layout.preferredHeight: 44
      radius: Theme.radiusLg
      color: Theme.bgSurface
      border.color: Theme.borderFocus
      border.width: 1
      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space5
        anchors.rightMargin: Theme.space3
        spacing: Theme.space3
        Text {
          text: "\uf023"   // lock
          font.family: Theme.fontGlyph
          font.pixelSize: Theme.textCaption
          color: Theme.fgMuted
        }
        TextInput {
          id: pw
          Layout.fillWidth: true
          verticalAlignment: TextInput.AlignVCenter
          clip: true
          echoMode: TextInput.Password
          color: Theme.fgPrimary
          font.family: Theme.fontUi
          font.pixelSize: Theme.textBody
          selectByMouse: true
          onVisibleChanged: if (visible) forceActiveFocus()
          Keys.onEscapePressed: { root.selected = ""; input.forceActiveFocus(); }
          Keys.onReturnPressed: { root.joinNetwork(root.selected, text); text = ""; }
          Keys.onEnterPressed:  { root.joinNetwork(root.selected, text); text = ""; }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: pw.text.length === 0
            text: "Password for " + root.selected
            color: Theme.fgMuted
            font: pw.font
          }
        }
        Rectangle {
          implicitWidth: 74; implicitHeight: 30
          radius: Theme.radiusMd
          color: gohover.hovered ? Theme.accentPrimaryHover : Theme.accentPrimary
          Text {
            anchors.centerIn: parent
            text: "Connect"
            color: Theme.fgOnAccent
            font.family: Theme.fontUi
            font.pixelSize: Theme.textCaption
          }
          HoverHandler { id: gohover }
          TapHandler { onTapped: { root.joinNetwork(root.selected, pw.text); pw.text = ""; } }
        }
      }
    }
  }
}
