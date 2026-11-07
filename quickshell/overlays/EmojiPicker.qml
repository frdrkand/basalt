import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.basalt.theme

// Emoji / icon picker: a search bar over a scrollable grid, with All / Emoji /
// Icons tabs that switch between color emoji and Nerd Font glyph icons.
// On select the glyph is pasted into the window that was focused before the
// picker opened (see insert() for why paste, not synthesised keystrokes). The
// picker stays open after a pick so several glyphs can be inserted in a row;
// close it with Escape or by clicking away.
// Datasets, both { emoji, name, keywords[], category }:
//   data/emoji.json  — color emoji (vendored from Noctalia).
//   data/glyphs.json — Nerd Font icons (generated from nerd-fonts glyphnames.json);
//                      entries carry glyph:true → rendered in Theme.fontGlyph.
Scope {
  id: root

  property bool shown: false
  function toggle() { if (shown) close(); else open(); }
  function open() {
    // Capture the window to type into *before* we take keyboard focus.
    captureProc.running = false;
    captureProc.running = true;
    // Snapshot the current clipboard (preferred type + raw bytes) once, in the
    // background. The picker's exclusive grab means the clipboard can't change
    // while it's open, so a single save-on-open / restore-on-close is enough —
    // an insert borrows the clipboard and close() puts the original back.
    clipboardDirty = false;
    wantClose = false;
    saveProc.running = false;
    saveProc.running = true;
    query = "";
    results = currentSet();   // reset the grid to the active tab's full set on every open
    selectedIndex = 0;    // fresh open starts at the top (not a stale remap index)
    shown = true;
  }
  function close() {
    shown = false;
    wantClose = true;
    if (!pasteProc.running) finishClose();   // no insert in flight → restore now
  }
  // Restore the borrowed clipboard once, after the picker is dismissed. Skipped
  // entirely if no insert ever overwrote it (open→close without a pick leaves the
  // clipboard — and its snapshot — untouched, which also avoids a save/restore race).
  function finishClose() {
    wantClose = false;
    if (!clipboardDirty) return;
    clipboardDirty = false;
    restoreProc.running = false;
    restoreProc.running = true;
  }

  function focusedScreen() {
    const fm = Hyprland.focusedMonitor;
    if (!fm) return null;
    const screens = Quickshell.screens;
    for (let i = 0; i < screens.length; i++) {
      if (screens[i].name === fm.name) return screens[i];
    }
    return null;
  }

  // ---- dataset -------------------------------------------------------------
  // Two sources: color emoji (data/emoji.json) and Nerd Font glyph icons
  // (data/glyphs.json). Both share the { emoji, name, keywords, category } shape;
  // glyph entries carry glyph:true so the grid delegate renders them in the Nerd
  // Font (Theme.fontGlyph) rather than Noto Color Emoji. The `tab` property (All /
  // Emoji / Icons) picks which set the grid+search draw from; like query and
  // selectedIndex it's a root property so it survives the unmap/remap around an insert.
  property var allEmoji: []
  property var allGlyphs: []
  property string tab: "emoji"    // "all" | "emoji" | "icons"
  property var results: []
  property string query: ""
  property int selectedIndex: 0   // grid cell to restore after a stay-open remap

  function currentSet() {
    if (tab === "emoji") return allEmoji;
    if (tab === "icons") return allGlyphs;
    return allEmoji.concat(allGlyphs);   // "all" — emoji first, then icons
  }
  function setTab(t) { tab = t; selectedIndex = 0; setQuery(query); }

  // Quickshell.shellDir is the directory this config was loaded from, and Basalt
  // always sits at basalt/ in it (that is what `import qs.basalt` names), so the
  // data files are found wherever the shell lives: the nix store, a checkout, or
  // ~/.config/quickshell.
  FileView {
    id: emojiFile
    path: Quickshell.shellDir + "/basalt/data/emoji.json"
    blockLoading: true
  }

  FileView {
    id: glyphFile
    path: Quickshell.shellDir + "/basalt/data/glyphs.json"
    blockLoading: true
  }

  Component.onCompleted: {
    try { allEmoji = JSON.parse(emojiFile.text() || "[]"); }
    catch (e) { allEmoji = []; }
    try { allGlyphs = JSON.parse(glyphFile.text() || "[]"); }
    catch (e) { allGlyphs = []; }
    results = currentSet();
  }

  function setQuery(t) {
    query = t;
    const q = t.trim().toLowerCase();
    const src = currentSet();
    if (q.length === 0) { results = src; return; }
    const out = [];
    for (let i = 0; i < src.length; i++) {
      const e = src[i];
      if ((e.name || "").toLowerCase().indexOf(q) >= 0) { out.push(e); continue; }
      const kw = e.keywords || [];
      for (let k = 0; k < kw.length; k++) {
        if (String(kw[k]).toLowerCase().indexOf(q) >= 0) { out.push(e); break; }
      }
    }
    results = out;
  }

  // ---- insert --------------------------------------------------------------
  // Only the class is kept: it picks the paste chord (terminals want Ctrl+Shift+V).
  // The window's address is deliberately not tracked — see insert() for why there
  // is no explicit re-focus to aim at.
  property string targetClass: ""

  // Clipboard borrow state. clipboardDirty = an insert has overwritten the
  // clipboard this session (so it must be restored on close); wantClose = close()
  // was requested while an insert was still in flight (restore in pasteProc.onExited).
  property bool clipboardDirty: false
  property bool wantClose: false
  // Single ephemeral snapshot in the tmpfs runtime dir (not per-insert churn):
  // <base>.type holds the preferred MIME type, <base>.bin the raw bytes.
  readonly property string clipBase: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-emoji-clip"
  // Matched by equality, never as a substring — a window class is an identifier,
  // not prose. This used to be an indexOf() scan, and "st" is two characters, so
  // Vivaldi (class "vivaldi-stable") matched inside "stable" and got pasted into
  // with the terminal chord: Ctrl+Shift+V, which Chromium's omnibox reads as
  // "paste and go", so picking an emoji in the address bar ran a search. Every
  // class carrying an "st" was caught the same way — steam, obs-studio, postman —
  // and a stray Ctrl+Shift+V is not harmless elsewhere either (Markdown preview
  // in VS Code, Paste Special in LibreOffice).
  //
  // Because equality no longer lets a short entry stand in for its variants,
  // the app_ids each terminal really reports are spelled out. Extra entries are
  // free: an exact match cannot false-positive.
  readonly property var termClasses: [
    "kitty", "foot", "footclient", "alacritty",
    "wezterm", "org.wezfurlong.wezterm",
    "xterm", "st", "st-256color",
    "konsole", "org.kde.konsole",
    "gnome-terminal", "gnome-terminal-server", "terminator", "urxvt"
  ]
  function isTerminalClass(c) {
    return termClasses.indexOf(String(c || "").toLowerCase()) >= 0;
  }

  Process {
    id: captureProc
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector {
      id: captureOut
      onStreamFinished: {
        try {
          const j = JSON.parse(captureOut.text) || {};
          root.targetClass = j.class || "";
        } catch (e) {
          root.targetClass = "";
        }
      }
    }
  }

  // Snapshot the pre-picker clipboard once on open, robustly. A *text* clipboard
  // (any text/* or *STRING type) is saved as plain text and restored with a plain
  // wl-copy, which re-offers all the standard text types — this avoids restoring
  // under one narrow/rich type (e.g. text/html) or a first type that carries no
  // data, both of which can leave a plain paste seeing nothing. Non-text content
  // (images) keeps its primary MIME type + raw bytes; if that type yields no bytes
  // we record nothing (restore will clear) rather than an empty typed offer.
  // .type = MIME type ("" ⇒ restore as plain text); .bin = the bytes.
  Process {
    id: saveProc
    command: ["sh", "-c",
      "b=$1; tt=$(wl-paste --list-types 2>/dev/null); " +
      "t=$(printf '%s\\n' \"$tt\" | grep -v '^$' | head -n1); " +
      "if [ -n \"$t\" ] && ! printf '%s\\n' \"$tt\" | grep -qiE 'text|string'; then " +
      "if wl-paste --type \"$t\" > \"$b.bin\" 2>/dev/null && [ -s \"$b.bin\" ]; then " +
      "printf '%s' \"$t\" > \"$b.type\"; else : > \"$b.type\"; : > \"$b.bin\"; fi; " +
      "else : > \"$b.type\"; wl-paste --no-newline > \"$b.bin\" 2>/dev/null || : > \"$b.bin\"; fi",
      "sh", clipBase]
  }

  // Restore the snapshot on close (under its original type), then remove the file.
  // Empty snapshot (clipboard was empty) → clear, so the emoji doesn't linger.
  Process {
    id: restoreProc
    command: ["sh", "-c",
      "b=$1; " +
      "if [ -s \"$b.type\" ]; then wl-copy --type \"$(cat \"$b.type\")\" < \"$b.bin\"; " +
      "elif [ -s \"$b.bin\" ]; then wl-copy < \"$b.bin\"; else wl-copy --clear; fi; " +
      "rm -f \"$b.type\" \"$b.bin\"",
      "sh", clipBase]
  }

  // Re-show the picker as soon as the paste finishes so more emoji can be inserted
  // (~0.1s blink). If close() was requested mid-insert, restore the clipboard and
  // stay hidden instead. Search query/selection are root properties that survive
  // the unmap; the window restores them on load (see the card's Component.onCompleted).
  Process {
    id: pasteProc
    onExited: (code, status) => {
      if (root.wantClose) root.finishClose();   // closed during the insert → restore, don't re-show
      else root.shown = true;                    // normal → re-show for the next pick
    }
  }

  // Insert the glyph by pasting it into the previously-focused window. Pasting
  // (not `wtype <glyph>`) is required for cross-app coverage: synthesising astral
  // /multi-codepoint emoji through the virtual keyboard only works in terminals
  // and renders as tofu or nothing in toolkit apps (Electron/Chromium/GTK/Qt).
  // The picker's layer surface holds an Exclusive keyboard grab; on Hyprland that
  // grab is only released by *unmapping* the surface, so we hide the picker
  // (shown = false), copy the glyph, and paste; the original clipboard was
  // snapshotted on open (saveProc) and is put back on close
  // (finishClose/restoreProc), so nothing is clobbered and there is no per-insert
  // clipboard I/O. Terminals paste with Ctrl+Shift+V. The glyph is passed as
  // positional arg $1 (Qt marshals it to UTF-8 argv intact — no shell quoting).
  // Caveat: if no text field is focused the paste is a no-op and nothing inserts.
  // Known limitation: combined emoji (ZWJ/VS16) pasted at a zsh prompt in kitty can
  // strand un-erasable glyph fragments — a kitty/zsh line-editor width desync, not
  // a picker bug (see [[project_emoji_picker_paste_insert]] / the plan file).
  function insert(glyph) {
    if (pasteProc.running) return;         // ignore re-entrant picks while pasting
    root.shown = false;                    // unmap to release our keyboard grab
    root.clipboardDirty = true;            // clipboard now holds the emoji → restore on close
    const paste = isTerminalClass(targetClass)
                  ? "wtype -M ctrl -M shift -k v -m shift -m ctrl"
                  : "wtype -M ctrl -k v -m ctrl";
    // No explicit re-focus: unmapping the grab hands focus back to the window
    // that had it, which is the target by construction. There used to be a
    // `hyprctl dispatch focuswindow address:…` here, but the config is Lua, so
    // that spelling was the syntax error `return hl.dispatch(focuswindow …)` —
    // it had never once run, and the picker worked anyway. Restoring it would
    // only matter if the picker stayed mapped during the paste, and it cannot:
    // wtype's Ctrl+V would go to the Exclusive grab rather than the target.
    let script = "printf '%s' \"$1\" | wl-copy; ";
    script += "sleep 0.05; " + paste;
    pasteProc.running = false;
    pasteProc.command = ["sh", "-c", script, "sh", glyph];
    pasteProc.running = true;
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
      WlrLayershell.namespace: "quickshell:emoji"

      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
      }

      Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.14)
        width: 480
        height: 440
        radius: Theme.radiusXl
        color: Theme.popupBackground
        border.color: Theme.borderSubtle
        border.width: 1

        MouseArea { anchors.fill: parent }

        // Restore the search query and grid selection (root properties that
        // survive the unmap/remap around an insert) and put the caret back in the
        // box. The selection restore is deferred with Qt.callLater so it runs
        // *after* GridView.onModelChanged has reset currentIndex to 0.
        Component.onCompleted: {
          input.text = root.query;
          input.forceActiveFocus();
          Qt.callLater(() => {
            const i = Math.max(0, Math.min(root.selectedIndex, root.results.length - 1));
            grid.currentIndex = i;
            grid.positionViewAtIndex(i, GridView.Contain);
          });
        }

        Column {
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

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

              onTextChanged: root.setQuery(text)

              Keys.onEscapePressed: root.close()
              Keys.onLeftPressed:  (e) => { grid.moveInRow(-1); e.accepted = true; }
              Keys.onRightPressed: (e) => { grid.moveInRow(1);  e.accepted = true; }
              Keys.onUpPressed:    (e) => { grid.moveCurrentIndexUp();    e.accepted = true; }
              Keys.onDownPressed:  (e) => { grid.moveCurrentIndexDown();  e.accepted = true; }
              Keys.onReturnPressed: (e) => { const it = root.results[grid.currentIndex]; if (it) { root.selectedIndex = grid.currentIndex; root.insert(it.emoji); } e.accepted = true; }
              Keys.onEnterPressed:  (e) => { const it = root.results[grid.currentIndex]; if (it) { root.selectedIndex = grid.currentIndex; root.insert(it.emoji); } e.accepted = true; }
              // Tab cycles the source tab (all → emoji → icons) without leaving the box.
              Keys.onTabPressed: (e) => {
                const order = ["all", "emoji", "icons"];
                root.setTab(order[(order.indexOf(root.tab) + 1) % order.length]);
                e.accepted = true;
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: root.tab === "icons" ? "Search icons..."
                                           : root.tab === "all" ? "Search emoji & icons..."
                                                                : "Search emoji..."
                color: Theme.fgMuted
                font: input.font
              }
            }
          }

          // Source tabs — switch the grid+search between color emoji and Nerd Font icons.
          Row {
            spacing: 8
            Repeater {
              model: [{ id: "all", label: "All" },
                      { id: "emoji", label: "Emoji" },
                      { id: "icons", label: "Icons" }]
              delegate: Rectangle {
                required property var modelData
                height: 28
                width: 72
                radius: Theme.radiusLg
                color: root.tab === modelData.id ? Theme.bgSurfaceHover : Theme.bgSurface
                Text {
                  anchors.centerIn: parent
                  text: modelData.label
                  color: root.tab === modelData.id ? Theme.fgPrimary : Theme.fgMuted
                  font.family: Theme.fontFamily
                  font.pixelSize: 13
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setTab(modelData.id)
                }
              }
            }
          }

          GridView {
            id: grid
            width: parent.width
            height: parent.height - 44 - 12 - 28 - 12
            clip: true
            model: root.results
            cellWidth: 52
            cellHeight: 52
            currentIndex: 0
            keyNavigationEnabled: false
            boundsBehavior: Flickable.StopAtBounds

            onModelChanged: currentIndex = 0

            // Left/Right cycle within the current row rather than running off its
            // ends — Up/Down are the only way to change rows. GridView doesn't expose
            // its column count, so recompute it the way Qt does; the last row is
            // often short, hence clamping the row length to the items left in it.
            function moveInRow(d) {
              if (count === 0) return;
              const cols = Math.max(1, Math.floor(width / cellWidth));
              const start = Math.floor(currentIndex / cols) * cols;
              const len = Math.min(cols, count - start);
              currentIndex = start + (currentIndex - start + d + len) % len;
              positionViewAtIndex(currentIndex, GridView.Contain);
            }

            delegate: Rectangle {
              id: cell
              required property int index
              required property var modelData
              width: grid.cellWidth
              height: grid.cellHeight
              radius: Theme.radiusLg
              color: grid.currentIndex === index ? Theme.bgSurfaceHover : "transparent"

              Text {
                anchors.centerIn: parent
                text: cell.modelData.emoji
                font.family: cell.modelData.glyph ? Theme.fontGlyph : "Noto Color Emoji"
                font.pixelSize: 30
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: grid.currentIndex = cell.index
                onClicked: { root.selectedIndex = cell.index; root.insert(cell.modelData.emoji); }
              }
            }
          }
        }
      }
    }
  }
}
