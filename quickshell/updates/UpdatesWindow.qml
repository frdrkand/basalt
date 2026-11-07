import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.basalt.shared
import qs.basalt.theme

// Details window for the bar's Updates pill: what checking is doing, and every
// update, part by part. A real toplevel rather than a layer-shell overlay, for
// the same reason the Settings window is one — a list this long wants to be
// resized, moved and left open beside a terminal.
//
// Everything on it comes from the host's details command (UpdatesStatus.qml),
// already worded: the title, the notices, each part's note and what to say when
// it is empty. So the window is the same whatever is being updated.
//
// It never applies anything. With an updatesCheck command it has a "Check now"
// button; without one, nothing on it can start work.
//
// Instantiated once in Basalt.qml and handed to the bar, not owned by the
// pill — Bar.qml is a Variants over the screens, so a window per pill would mean
// one window per monitor.
Scope {
  id: root

  readonly property var st: UpdatesStatus
  readonly property var d: st.details

  property bool shown: false
  // Built on first open and then kept alive, hidden — same as Settings.qml.
  property bool built: false

  // Holds UpdatesStatus's details fresh while shown.
  onShownChanged: st.watchers += shown ? 1 : -1

  function open() {
    built = true;
    shown = true;
    st.poll();
    st.loadDetails();
  }
  function close()  { shown = false; }
  function toggle() { if (shown) close(); else open(); }

  readonly property var parts: d ? d.parts : []
  readonly property int count: d ? (d.count !== undefined ? d.count
    : parts.reduce((n, p) => n + (p.updates || []).length, 0)) : 0
  readonly property string title:
    !st.reachable ? "Updates unavailable"
    : d && d.title ? d.title
    : count > 0 ? (count === 1 ? "update available" : "updates available")
    : st.summary

  // The list, flattened: each part's updates, or one line saying why it has
  // none. Each row carries its part, so the delegate can head each run.
  readonly property var rows: {
    const out = [];
    for (const p of parts) {
      const updates = p.updates || [];
      const err = st.errorText(p.error);
      if (err && !p.busy)
        out.push({ part: p, info: "Check failed: " + err, danger: true });
      if (updates.length > 0)
        for (const u of updates) out.push({ part: p, update: u });
      else if (p.busy)
        out.push({ part: p, info: "Checking…" });
      else
        out.push({ part: p, info: p.message || (p.checkedAt ? "Up to date" : "Not checked yet") });
    }
    return out;
  }

  // A size column only when some update has a size to show.
  readonly property bool sized: parts.some(p => (p.updates || []).some(u => u.sizeDelta !== undefined))

  // Exact signed bytes, rendered here, with the 8 KiB gate diff-closures
  // applies: below it a size change is noise beside the version change it
  // came with.
  function sizeText(bytes) {
    if (bytes === undefined || bytes === null) return "";
    const n = bytes;
    if (n > -8192 && n < 8192) return "";
    const sign = n < 0 ? "-" : "+";
    let v = Math.abs(n);
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let i = 0;
    while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
    return sign + (i === 0 ? v : v.toFixed(1)) + " " + units[i];
  }

  function toneColor(tone) {
    switch (tone) {
    case "danger":  return Theme.accentDanger;
    case "warning": return Theme.accentWarning;
    case "muted":   return Theme.fgSecondary;
    default:        return Theme.fgPrimary;
    }
  }

  readonly property var notices: d && d.notices ? d.notices : []
  readonly property string errorLine: st.error || st.detailsError || st.checkError
  readonly property bool working: st.busy || st.checking

  LazyLoader {
    active: root.built

    FloatingWindow {
      id: win
      title: "Updates"
      color: Theme.bgCanvas
      implicitWidth: 760
      implicitHeight: 640
      minimumSize: Qt.size(560, 400)
      visible: root.shown

      // Keeps `shown` honest when the compositor closes the window (SUPER+C).
      onClosed: root.close()

      FocusScope {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onEscapePressed: root.close()

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Theme.space6
          spacing: Theme.space5

          // ---- header: the count and the title, check now, close ----
          RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space4

            Text {
              visible: root.st.reachable && root.count > 0
              text: root.count
              color: Theme.accentWarning
              font.family: Theme.fontUi
              font.pixelSize: Theme.textTitleLg
              font.weight: Theme.weightBold
            }
            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: root.title
              color: !root.st.reachable ? Theme.accentDanger : Theme.fgEmphasis
              font.family: Theme.fontUi
              font.pixelSize: Theme.textTitle
              font.weight: Theme.weightBold
            }

            // The one control in the shell that can start work, and only when
            // the host offers it.
            Rectangle {
              visible: root.st.canCheck
              implicitWidth: 104
              implicitHeight: 32
              radius: Theme.radiusMd
              opacity: root.working ? 0.5 : 1
              color: chover.hovered && !root.working ? Theme.accentPrimaryHover
                                                     : Theme.accentPrimary
              Text {
                anchors.centerIn: parent
                text: "Check now"
                color: Theme.fgOnAccent
                font.family: Theme.fontUi
                font.pixelSize: Theme.textCaption
              }
              HoverHandler { id: chover; enabled: !root.working }
              TapHandler { enabled: !root.working; onTapped: root.st.check() }
            }

            CloseButton { onClicked: root.close() }
          }

          // ---- what checking is doing: notices, progress, failures ----
          Rectangle {
            Layout.fillWidth: true
            visible: root.notices.length > 0 || root.working || root.errorLine.length > 0
                     || (root.d && root.d.about)
            implicitHeight: panel.implicitHeight + Theme.space5 * 2
            radius: Theme.radiusLg
            color: Theme.bgSurface
            border.width: 1
            border.color: root.errorLine.length > 0 && !root.working ? Theme.accentDanger
                                                                    : Theme.borderSubtle

            ColumnLayout {
              id: panel
              anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
              anchors.margins: Theme.space5
              spacing: Theme.space3

              Text {
                Layout.fillWidth: true
                visible: root.working
                elide: Text.ElideRight
                text: root.st.summary
                color: Theme.fgPrimary
                font.family: Theme.fontUi
                font.pixelSize: Theme.textLabel
              }

              GridLayout {
                Layout.fillWidth: true
                visible: root.notices.length > 0
                columns: 2
                columnSpacing: Theme.space6
                rowSpacing: Theme.space2

                Repeater {
                  model: root.notices
                  delegate: Text {
                    required property var modelData
                    text: modelData.label || ""
                    color: Theme.fgMuted
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.textCaption
                    Layout.row: index
                    Layout.column: 0
                    required property int index
                  }
                }
                Repeater {
                  model: root.notices
                  delegate: Text {
                    required property var modelData
                    required property int index
                    Layout.row: index
                    Layout.column: 1
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: modelData.text
                    color: root.toneColor(modelData.tone)
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.textCaption
                  }
                }
              }

              // Checking itself is failing. The answers below are the last ones
              // that worked; this is what stops them passing for current.
              Text {
                Layout.fillWidth: true
                visible: root.errorLine.length > 0
                wrapMode: Text.WordWrap
                text: root.errorLine
                color: Theme.accentDanger
                font.family: Theme.fontUi
                font.pixelSize: Theme.textCaption
              }

              Text {
                Layout.fillWidth: true
                visible: !!(root.d && root.d.about)
                elide: Text.ElideMiddle
                text: root.d && root.d.about ? root.d.about : ""
                color: Theme.fgMuted
                font.family: Theme.fontUi
                font.pixelSize: Theme.textMicro
              }
            }
          }

          // ---- the list: one run per part ----
          ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.rows
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds

            // Shared by every row, so the columns line up.
            readonly property int versionWidth: Math.max(130, Math.floor(width * 0.24))
            readonly property int sizeWidth: root.sized ? 84 : 0
            readonly property int pad: Theme.space4

            function fromText(u) { return u.from || (u.kind === "added" ? "new" : ""); }
            function toText(u)   { return u.to || (u.kind === "removed" ? "removed" : ""); }

            delegate: Column {
              id: entry
              required property int index
              required property var modelData

              // A JS-array model has no section roles, so the run boundary is
              // found by looking back one row. Guarded because the lookback
              // outlives the array for an instant when a newer list replaces it
              // with a shorter one.
              readonly property bool startsRun: {
                if (index === 0) return true;
                const prev = root.rows[index - 1];
                return !prev || prev.part.id !== modelData.part.id;
              }

              width: list.width
              spacing: Theme.space1

              // The part: its name, its note, and how to apply it.
              RowLayout {
                visible: entry.startsRun
                width: parent.width
                height: visible ? implicitHeight + (entry.index === 0 ? Theme.space2 : Theme.space6) : 0
                spacing: Theme.space4

                Text {
                  Layout.alignment: Qt.AlignBottom
                  text: entry.modelData.part.name
                  color: Theme.fgSecondary
                  font.family: Theme.fontUi
                  font.pixelSize: Theme.textCaption
                  font.weight: Theme.weightMedium
                }
                Text {
                  Layout.alignment: Qt.AlignBottom
                  Layout.fillWidth: true
                  text: entry.modelData.part.note || ""
                  elide: Text.ElideRight
                  color: Theme.fgMuted
                  font.family: Theme.fontUi
                  font.pixelSize: Theme.textMicro
                }
                Text {
                  Layout.alignment: Qt.AlignBottom
                  visible: (entry.modelData.part.updates || []).length > 0 && !!entry.modelData.part.apply
                  text: entry.modelData.part.apply || ""
                  color: Theme.fgMuted
                  font.family: Theme.fontMono
                  font.pixelSize: Theme.textMicro
                }
              }

              Text {
                visible: entry.modelData.info !== undefined
                width: parent.width
                leftPadding: list.pad
                topPadding: Theme.space1
                bottomPadding: Theme.space1
                wrapMode: Text.WordWrap
                text: entry.modelData.info || ""
                color: entry.modelData.danger ? Theme.accentDanger : Theme.fgMuted
                font.family: Theme.fontUi
                font.pixelSize: Theme.textCaption
              }

              Rectangle {
                visible: entry.modelData.update !== undefined
                width: parent.width
                height: visible ? 28 : 0
                radius: Theme.radiusMd
                color: ehover.hovered ? Theme.bgSurfaceHover : "transparent"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: list.pad
                  anchors.rightMargin: list.pad
                  spacing: Theme.space5

                  Text {
                    Layout.fillWidth: true
                    text: entry.modelData.update ? entry.modelData.update.name : ""
                    elide: Text.ElideRight
                    color: Theme.fgPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.textLabel
                  }
                  Text {
                    Layout.preferredWidth: list.versionWidth
                    text: entry.modelData.update ? list.fromText(entry.modelData.update) : ""
                    elide: Text.ElideMiddle
                    color: Theme.fgMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.textCaption
                  }
                  Text {
                    Layout.preferredWidth: list.versionWidth
                    text: entry.modelData.update ? list.toText(entry.modelData.update) : ""
                    elide: Text.ElideMiddle
                    color: Theme.fgSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.textCaption
                  }
                  // Size deltas are incidental — shown, never coloured. Tinting
                  // every row by whether the store grew would make a long list
                  // shout at you for no decision it helps you make.
                  Text {
                    visible: root.sized
                    Layout.preferredWidth: list.sizeWidth
                    horizontalAlignment: Text.AlignRight
                    text: entry.modelData.update ? root.sizeText(entry.modelData.update.sizeDelta) : ""
                    color: Theme.fgMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.textMicro
                  }
                }

                HoverHandler { id: ehover }
              }
            }

            Text {
              anchors.centerIn: parent
              width: parent.width - Theme.space8 * 2
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              visible: list.count === 0
              text: !root.st.reachable ? root.st.error
                  : root.d ? "Nothing to show."
                  : "No answer yet."
              color: Theme.fgMuted
              font.family: Theme.fontUi
              font.pixelSize: Theme.textCaption
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.borderSubtle
          }
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            text: "Read-only  ·  " + (root.d && root.d.hint ? root.d.hint + "  ·  " : "") + "Esc closes"
            color: Theme.fgMuted
            font.family: Theme.fontUi
            font.pixelSize: Theme.textMicro
          }
        }
      }
    }
  }
}
