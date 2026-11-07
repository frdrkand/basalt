import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.basalt.theme

// Audio page of the Settings window: every output and input device in one list,
// each with its own volume slider and mute, plus which one is the default.
// Built on the same Pipewire idioms as the bar's Audio module — device lists come
// from a plain loop over Pipewire.nodes.values (a model list, not a JS array) and
// PwObjectTracker keeps every listed node's audio bindable.
//
// The last row is an escape hatch to the full PipeWire mixer (hyprpwcenter), kept
// in the list rather than as a stray button so it is keyboard-reachable too.
FocusScope {
  id: root

  property bool active: false
  signal backToNav()

  function focusFirst() { list.forceActiveFocus(); }

  readonly property var sinks: {
    var out = [];
    var vs = Pipewire.nodes ? Pipewire.nodes.values : [];
    for (var i = 0; i < vs.length; i++) {
      var n = vs[i];
      if (n && n.isSink && !n.isStream) out.push(n);
    }
    return out;
  }
  readonly property var sources: {
    var out = [];
    var vs = Pipewire.nodes ? Pipewire.nodes.values : [];
    for (var i = 0; i < vs.length; i++) {
      var n = vs[i];
      if (n && !n.isSink && !n.isStream) out.push(n);
    }
    return out;
  }

  PwObjectTracker { objects: root.sinks }
  PwObjectTracker { objects: root.sources }

  // One flat list so a single ListView owns navigation; `header` is set on the
  // first entry of each group and drawn by the delegate.
  readonly property var rows: {
    var out = [];
    for (var i = 0; i < sinks.length; i++)
      out.push({ kind: "sink", node: sinks[i], header: i === 0 ? "Output" : "" });
    for (var j = 0; j < sources.length; j++)
      out.push({ kind: "source", node: sources[j], header: j === 0 ? "Input" : "" });
    out.push({ kind: "action", node: null, header: "Advanced" });
    return out;
  }

  function label(n) {
    if (!n) return "";
    return n.description || n.nickname || n.name || "";
  }
  function isDefault(entry) {
    if (!entry || !entry.node) return false;
    const d = entry.kind === "sink" ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource;
    return d && d.id === entry.node.id;
  }
  function makeDefault(entry) {
    if (!entry || !entry.node) return;
    if (entry.kind === "sink") Pipewire.preferredDefaultAudioSink = entry.node;
    else Pipewire.preferredDefaultAudioSource = entry.node;
  }
  function vol(n)          { return n && n.audio ? n.audio.volume : 0; }
  function muted(n)        { return n && n.audio ? n.audio.muted : false; }
  function setVol(n, v)    { if (n && n.audio) n.audio.volume = Math.max(0, Math.min(1, v)); }
  function toggleMute(n)   { if (n && n.audio) n.audio.muted = !n.audio.muted; }

  function activate(entry) {
    if (!entry) return;
    if (entry.kind === "action") Quickshell.execDetached(["hyprpwcenter"]);
    else makeDefault(entry);
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Theme.space4

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: "\uf028  Audio"   // volume-high
        color: Theme.fgEmphasis
        font.family: Theme.fontGlyph
        font.pixelSize: Theme.textTitle
        font.weight: Theme.weightBold
      }
      Item { Layout.fillWidth: true }
      Text {
        text: "Enter sets default  ·  ←/→ volume  ·  M mute"
        color: Theme.fgMuted
        font.family: Theme.fontUi
        font.pixelSize: Theme.textMicro
      }
    }

    ListView {
      id: list
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      model: root.rows
      spacing: Theme.space2
      currentIndex: 0
      focus: true
      keyNavigationEnabled: false
      boundsBehavior: Flickable.StopAtBounds

      function move(d) {
        if (count === 0) return;
        currentIndex = Math.max(0, Math.min(count - 1, currentIndex + d));
        positionViewAtIndex(currentIndex, ListView.Contain);
      }
      onModelChanged: if (currentIndex >= count) currentIndex = 0

      readonly property var currentEntry: root.rows[currentIndex]

      Keys.onEscapePressed: root.backToNav()
      Keys.onDownPressed:   (e) => { list.move(1); e.accepted = true; }
      Keys.onUpPressed:     (e) => { list.move(-1); e.accepted = true; }
      Keys.onLeftPressed:   (e) => {
        const en = list.currentEntry;
        if (en && en.node) root.setVol(en.node, root.vol(en.node) - 0.05);
        e.accepted = true;
      }
      Keys.onRightPressed:  (e) => {
        const en = list.currentEntry;
        if (en && en.node) root.setVol(en.node, root.vol(en.node) + 0.05);
        e.accepted = true;
      }
      Keys.onReturnPressed: (e) => { root.activate(list.currentEntry); e.accepted = true; }
      Keys.onEnterPressed:  (e) => { root.activate(list.currentEntry); e.accepted = true; }
      Keys.onPressed: (e) => {
        if (e.key === Qt.Key_M) {
          const en = list.currentEntry;
          if (en && en.node) root.toggleMute(en.node);
          e.accepted = true;
        }
      }

      delegate: Column {
        id: rowItem
        required property int index
        required property var modelData
        readonly property bool current: list.currentIndex === index && root.activeFocus
        readonly property bool isAction: modelData.kind === "action"
        readonly property bool isDefault: root.isDefault(modelData)

        width: list.width
        spacing: Theme.space2

        Text {
          visible: rowItem.modelData.header.length > 0
          topPadding: rowItem.index === 0 ? 0 : Theme.space4
          text: rowItem.modelData.header
          color: Theme.fgMuted
          font.family: Theme.fontUi
          font.pixelSize: Theme.textMicro
          font.weight: Theme.weightMedium
        }

        Rectangle {
          width: parent.width
          height: rowItem.isAction ? 36 : 60
          radius: Theme.radiusMd
          color: rowItem.current || rhover.hovered ? Theme.bgSurfaceHover
               : rowItem.isDefault ? Theme.accentTintSoft : "transparent"
          border.width: 1
          border.color: rowItem.current ? Theme.borderFocus : "transparent"

          ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.space4
            anchors.rightMargin: Theme.space4
            anchors.topMargin: rowItem.isAction ? 0 : Theme.space3
            anchors.bottomMargin: rowItem.isAction ? 0 : Theme.space3
            spacing: Theme.space2

            RowLayout {
              Layout.fillWidth: true
              spacing: Theme.space4

              Text {
                text: rowItem.isAction ? "\uf1de"                                    // sliders
                    : rowItem.modelData.kind === "sink"
                      ? (root.muted(rowItem.modelData.node) ? "\uf026" : "\uf028")       // mute / volume
                      : (root.muted(rowItem.modelData.node) ? "\uf131" : "\uf130")       // mic-off / mic
                font.family: Theme.fontGlyph
                font.pixelSize: Theme.textBody
                color: rowItem.isDefault ? Theme.accentPrimary : Theme.fgMuted
              }
              Text {
                Layout.fillWidth: true
                text: rowItem.isAction ? "Advanced (PipeWire mixer)" : root.label(rowItem.modelData.node)
                elide: Text.ElideRight
                color: rowItem.isAction ? Theme.fgSecondary : Theme.fgPrimary
                font.family: Theme.fontUi
                font.pixelSize: rowItem.isAction ? Theme.textCaption : Theme.textLabel
              }
              Text {
                visible: !rowItem.isAction
                text: root.muted(rowItem.modelData.node)
                      ? "muted" : Math.round(root.vol(rowItem.modelData.node) * 100) + "%"
                color: Theme.fgMuted
                font.family: Theme.fontUi
                font.pixelSize: Theme.textMicro
              }
              Text {
                visible: rowItem.isDefault
                text: "\uf00c"   // check
                color: Theme.accentSuccess
                font.family: Theme.fontGlyph
                font.pixelSize: Theme.textCaption
              }
            }

            // per-device volume track (click / drag anywhere)
            Rectangle {
              visible: !rowItem.isAction
              Layout.fillWidth: true
              Layout.preferredHeight: 8
              radius: Theme.radiusPill
              color: Theme.bgSurface
              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.vol(rowItem.modelData.node)))
                height: parent.height
                radius: Theme.radiusPill
                color: root.muted(rowItem.modelData.node) ? Theme.fgMuted
                     : rowItem.isDefault ? Theme.accentPrimary : Theme.fgSecondary
              }
              MouseArea {
                anchors.fill: parent
                onPressed: (m) => { list.currentIndex = rowItem.index; root.setVol(rowItem.modelData.node, m.x / width); }
                onPositionChanged: (m) => root.setVol(rowItem.modelData.node, m.x / width)
              }
            }
          }

          HoverHandler { id: rhover }
          TapHandler {
            onTapped: {
              list.currentIndex = rowItem.index;
              list.forceActiveFocus();
              root.activate(rowItem.modelData);
            }
          }
        }
      }
    }
  }
}
