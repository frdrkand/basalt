import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs
import qs.basalt.settings
import qs.basalt.shared
import qs.basalt.theme

// Application launcher: a search box over a single flat result list where
// applications, power actions, settings pages, and a live math result coexist
// (no modes).
//   * apps        -> DesktopEntries, launched through Host.launch(), frecency-ordered
//   * power       -> the shared PowerActions entries (match by label/key/keywords)
//   * settings    -> the Settings window, plus one entry per SettingsPages tab
//   * math        -> qalc evaluates the query live; Enter copies the result
// Frecency persists to ~/.local/state/quickshell; the last query is kept only
// in memory, so it survives close/reopen within a session but resets on login.
Scope {
  id: root

  property bool shown: false
  property var settings            // Settings window (from shell.qml)
  function toggle() { if (shown) close(); else open(); }
  function open()   { query = lastQuery; shown = true; }
  function close()  { lastQuery = query; saveState(); shown = false; }

  // ---- focused monitor -----------------------------------------------------
  function focusedScreen() {
    const fm = Hyprland.focusedMonitor;
    if (!fm) return null;
    const screens = Quickshell.screens;
    for (let i = 0; i < screens.length; i++) {
      if (screens[i].name === fm.name) return screens[i];
    }
    return null;
  }

  // ---- persistent state ----------------------------------------------------
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
  property var frecency: ({})      // { "<id>": { count, lastUsed } }
  property string lastQuery: ""    // session-only: not persisted, cleared on login

  // Desktop-entry ids never shown in the launcher (matched case-insensitively).
  readonly property var ignoredApps: Host.ignoredApps

  FileView {
    id: stateFile
    path: root.stateDir + "/launcher.json"
    blockLoading: true
  }

  Component.onCompleted: {
    loadState();
    // Touch the desktop-entry index so it starts populating before the first
    // open (it loads lazily/reactively, so an early imperative read can be empty).
    void DesktopEntries.applications.values.length;
  }

  // The app list can populate/refresh after we've already built results (e.g.
  // right after a config reload). Rebuild reactively so an empty first open
  // fills in once entries are available.
  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.rebuild(); }
  }

  function loadState() {
    try {
      const s = JSON.parse(stateFile.text() || "{}");
      frecency = s.frecency || {};
    } catch (e) {
      frecency = ({});
    }
  }
  function saveState() {
    stateFile.setText(JSON.stringify({ frecency: frecency }, null, 2));
  }

  function frecencyScore(id) {
    const r = frecency[id];
    if (!r) return 0;
    const ageDays = (Date.now() - (r.lastUsed || 0)) / 86400000;
    const recency = Math.exp(-ageDays / 30);   // ~monthly decay
    return (r.count || 0) * (0.5 + recency);
  }
  function bumpFrecency(id) {
    const r = frecency[id] || { count: 0, lastUsed: 0 };
    r.count = (r.count || 0) + 1;
    r.lastUsed = Date.now();
    frecency[id] = r;
    saveState();
  }

  // ---- query / results -----------------------------------------------------
  property string query: ""
  property var results: []

  function setQuery(t) {
    query = t;
    if (looksLikeMath(t)) mathDebounce.restart();
    else mathResult = "";
    rebuild();
  }

  function rebuild() {
    const q = query.trim().toLowerCase();
    const out = [];

    if (mathResult.length > 0)
      out.push({ type: "math", title: query.trim(), result: mathResult });

    // Apps before power actions and settings: Enter takes the first row, and a
    // letter or two of an app ("e", "t") also matches Sleep or Logout.
    const apps = DesktopEntries.applications.values;
    const matched = [];
    for (let i = 0; i < apps.length; i++) {
      const e = apps[i];
      if (e.noDisplay) continue;
      if (root.ignoredApps.indexOf((e.id || "").toLowerCase()) >= 0) continue;
      const name = (e.name || "").toLowerCase();
      const generic = (e.genericName || "").toLowerCase();
      let kw = "";
      const kwList = e.keywords || [];
      for (let k = 0; k < kwList.length; k++) kw += " " + String(kwList[k]).toLowerCase();
      if (q.length === 0 || name.indexOf(q) >= 0 || generic.indexOf(q) >= 0 || kw.indexOf(q) >= 0)
        matched.push(e);
    }
    matched.sort((a, b) => {
      const d = frecencyScore(b.id) - frecencyScore(a.id);
      if (d !== 0) return d;
      return (a.name || "").localeCompare(b.name || "");
    });
    for (let i = 0; i < matched.length; i++) {
      const e = matched[i];
      out.push({ type: "app", id: e.id, title: e.name, icon: e.icon });
    }

    if (q.length > 0) {
      // `keywords` is optional on a power action (only Sleep carries one, so
      // that "suspend" finds it); the || "" keeps the others matching on
      // label/key alone.
      for (let i = 0; i < PowerActions.list.length; i++) {
        const a = PowerActions.list[i];
        if (a.label.toLowerCase().indexOf(q) >= 0 || a.key.indexOf(q) >= 0
            || (a.keywords || "").indexOf(q) >= 0)
          out.push({ type: "power", title: a.label, codepoint: a.codepoint, command: a.command });
      }

      // Settings: the window itself (first tab) plus a direct entry per tab, so
      // typing "settings" lists them all and "wifi" jumps straight to Network.
      if ("settings".indexOf(q) >= 0)
        out.push({ type: "settings", title: "Settings", page: "", codepoint: 0xf013 });
      for (let s = 0; s < SettingsPages.list.length; s++) {
        const p = SettingsPages.list[s];
        if ("settings".indexOf(q) >= 0 || p.key.indexOf(q) >= 0
            || p.label.toLowerCase().indexOf(q) >= 0 || p.keywords.indexOf(q) >= 0)
          out.push({ type: "settings", title: p.label + " settings", page: p.key, codepoint: p.codepoint });
      }
    }

    results = out;
  }

  function activate(item) {
    if (!item) return;
    if (item.type === "app") {
      // The host decides how an application starts (HostConfig.qml): under a
      // session manager, with another environment, or as the entry says.
      const entry = DesktopEntries.byId(item.id);
      if (entry) Host.launch(entry);
      bumpFrecency(item.id);
    } else if (item.type === "power") {
      Quickshell.execDetached(item.command);
    } else if (item.type === "settings") {
      if (root.settings) root.settings.open(item.page);
    } else if (item.type === "math") {
      const p = procComponent.createObject(sys, {
        command: ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", item.result]
      });
      p.running = true;
    }
    close();
  }

  // ---- live math (qalc) ----------------------------------------------------
  property string mathResult: ""
  function looksLikeMath(t) {
    const s = t.trim();
    return /[0-9]/.test(s) && /[-+*/^%()]/.test(s);
  }

  Timer {
    id: mathDebounce
    interval: 150
    onTriggered: {
      if (!root.looksLikeMath(root.query)) { root.mathResult = ""; return; }
      qalcProc.running = false;
      qalcProc.command = ["qalc", "-t", "--", root.query.trim()];
      qalcProc.running = true;
    }
  }

  Process {
    id: qalcProc
    stdout: StdioCollector {
      id: qalcOut
      onStreamFinished: {
        root.mathResult = qalcOut.text.trim();
        root.rebuild();
      }
    }
  }

  // ---- window --------------------------------------------------------------
  LazyLoader {
    active: root.shown

    PanelWindow {
      id: win
      screen: root.focusedScreen()
      anchors { left: true; right: true; top: true; bottom: true }
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.namespace: "quickshell:launcher"

      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
      }

      Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.12)
        width: 640
        height: 520
        radius: Theme.radiusXl
        color: Theme.popupBackground
        border.color: Theme.borderSubtle
        border.width: 1

        // Swallow clicks inside the card.
        MouseArea { anchors.fill: parent }

        Component.onCompleted: {
          input.text = root.query;
          input.selectAll();
          input.forceActiveFocus();
          root.rebuild();
        }

        Column {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          // search box
          Rectangle {
            width: parent.width
            height: 44
            radius: Theme.radiusLg
            color: Theme.bgSurface
            TextInput {
              id: input
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              verticalAlignment: TextInput.AlignVCenter
              clip: true
              color: Theme.fgPrimary
              font.family: Theme.fontFamily
              font.pixelSize: 18
              selectByMouse: true
              selectionColor: Theme.bgSurfaceHover

              onTextChanged: root.setQuery(text)

              Keys.onEscapePressed: root.close()
              Keys.onDownPressed: (e) => { list.moveSelection(1); e.accepted = true; }
              Keys.onUpPressed:   (e) => { list.moveSelection(-1); e.accepted = true; }
              Keys.onReturnPressed: (e) => { root.activate(root.results[list.currentIndex]); e.accepted = true; }
              Keys.onEnterPressed:  (e) => { root.activate(root.results[list.currentIndex]); e.accepted = true; }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: "Search apps, actions, or type math..."
                color: Theme.fgMuted
                font: input.font
              }
            }
          }

          // results
          ListView {
            id: list
            width: parent.width
            height: parent.height - 44 - 12
            clip: true
            model: root.results
            currentIndex: 0
            keyNavigationEnabled: false
            boundsBehavior: Flickable.StopAtBounds

            function moveSelection(d) {
              if (count === 0) return;
              currentIndex = Math.max(0, Math.min(count - 1, currentIndex + d));
              positionViewAtIndex(currentIndex, ListView.Contain);
            }

            onModelChanged: currentIndex = 0

            delegate: Rectangle {
              id: rowItem
              required property int index
              required property var modelData
              width: list.width
              height: 48
              radius: Theme.radiusLg
              color: list.currentIndex === index ? Theme.bgSurfaceHover : "transparent"

              Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Item {
                  width: 32
                  height: parent.height
                  Image {
                    id: iconImage
                    anchors.centerIn: parent
                    width: 28; height: 28
                    // Only show the image when it loaded cleanly; otherwise the
                    // fallback glyph below takes over instead.
                    visible: rowItem.modelData.type === "app" && iconImage.status === Image.Ready
                    // Pass check=true so an unresolvable icon yields "" (empty
                    // source) rather than the theme's magenta/black placeholder,
                    // which would otherwise load as a valid Image.Ready image.
                    source: rowItem.modelData.type === "app"
                            ? Quickshell.iconPath(rowItem.modelData.icon || "", true)
                            : ""
                    sourceSize.width: 28
                    sourceSize.height: 28
                  }
                  // Fallback glyph when an app's icon can't be resolved at all
                  // (empty/unresolved source or load error) — guarantees a
                  // visible default even if the icon theme lacks a generic icon.
                  Text {
                    anchors.centerIn: parent
                    visible: rowItem.modelData.type === "app"
                             && iconImage.status !== Image.Ready
                             && iconImage.status !== Image.Loading
                    text: String.fromCodePoint(0xf013)   // gear/app (nf-fa set)
                    font.family: Theme.fontGlyph
                    font.pixelSize: 22
                    color: Theme.fgPrimary
                  }
                  Text {
                    anchors.centerIn: parent
                    visible: rowItem.modelData.type !== "app"
                    // power + settings rows carry their own glyph; math doesn't
                    text: rowItem.modelData.codepoint
                          ? String.fromCodePoint(rowItem.modelData.codepoint)
                          : String.fromCodePoint(0xf1ec)   // calculator
                    font.family: Theme.fontGlyph
                    font.pixelSize: 22
                    color: Theme.fgPrimary
                  }
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 2
                  Text {
                    text: rowItem.modelData.type === "math"
                          ? (rowItem.modelData.title + " = " + rowItem.modelData.result)
                          : rowItem.modelData.title
                    color: Theme.fgPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                  }
                  Text {
                    visible: rowItem.modelData.type === "math"
                    text: "Press Enter to copy"
                    color: Theme.fgSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: list.currentIndex = rowItem.index
                onClicked: root.activate(rowItem.modelData)
              }
            }
          }
        }
      }
    }
  }
}
