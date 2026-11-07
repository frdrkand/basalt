import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.basalt.bar
import qs.basalt.theme

// Audio module (Pipewire, default sink). Icon + percent. Scroll adjusts volume,
// right-click toggles mute, left-click opens a popup with a slider, mute toggle,
// an output-device switcher, and a shortcut to the Settings window's Audio tab.
// PwObjectTracker keeps the sink's audio (and every listed sink) bindable/live.
Rectangle {
  id: root
  property var settings          // Settings window (from shell.qml)
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var au: sink ? sink.audio : null
  readonly property real vol: au ? au.volume : 0
  readonly property bool muted: au ? au.muted : false

  // all real output devices (audio sinks, excluding per-app streams). Built with a
  // plain loop — Pipewire.nodes.values is a quickshell model list, not a JS array.
  readonly property var sinks: {
    var out = [];
    var vs = Pipewire.nodes ? Pipewire.nodes.values : []; // qmllint disable missing-property
    for (var i = 0; i < vs.length; i++) {
      var n = vs[i];
      if (n && n.isSink && !n.isStream) out.push(n);
    }
    return out;
  }

  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  PwObjectTracker { objects: root.sinks }

  function setVol(v) { if (root.au) root.au.volume = Math.max(0, Math.min(1, v)); }
  function setSink(n) { if (n) Pipewire.preferredDefaultAudioSink = n; }

  Layout.alignment: Qt.AlignVCenter
  implicitHeight: Theme.barHeight - 8
  implicitWidth: arow.implicitWidth + Theme.space4
  radius: Theme.radiusMd
  color: pop.visible ? Theme.accentTintHover
       : hover.hovered ? Theme.accentTintSoft : "transparent"

  RowLayout {
    id: arow
    anchors.centerIn: parent
    spacing: Theme.space2
    Text {
      text: root.muted ? "" : ""   // volume-mute / volume-high
      font.family: Theme.fontGlyph
      font.pixelSize: Theme.textBody
      color: root.muted ? Theme.fgMuted : Theme.fgSecondary
    }
    Text {
      text: Math.round(root.vol * 100) + "%"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textLabel
      font.weight: Theme.weightMedium
      color: Theme.fgSecondary
    }
  }

  HoverHandler { id: hover }
  TapHandler { acceptedButtons: Qt.LeftButton; onTapped: pop.visible = !pop.visible }
  TapHandler { acceptedButtons: Qt.RightButton; onTapped: if (root.au) root.au.muted = !root.au.muted }
  WheelHandler { onWheel: (ev) => root.setVol(root.vol + (ev.angleDelta.y > 0 ? 0.05 : -0.05)) }

  BarPopup {
    id: pop
    anchorItem: root
    contentWidth: 260

    RowLayout {
      width: parent.width
      Text {
        Layout.fillWidth: true
        text: "Volume"
        color: Theme.fgEmphasis
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textLabel
        font.weight: Theme.weightBold
      }
      Text {
        text: Math.round(root.vol * 100) + "%"
        color: Theme.fgSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
      }
    }

    // volume slider (click / drag anywhere on the track)
    Rectangle {
      width: parent.width
      height: 10
      radius: Theme.radiusPill
      color: Theme.bgSurface
      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.vol))
        height: parent.height
        radius: Theme.radiusPill
        color: root.muted ? Theme.fgMuted : Theme.accentPrimary
      }
      MouseArea {
        anchors.fill: parent
        onPressed: (m) => root.setVol(m.x / width)
        onPositionChanged: (m) => root.setVol(m.x / width)
      }
    }

    // mute toggle button
    Rectangle {
      width: parent.width
      height: 28
      radius: Theme.radiusMd
      color: mhover.hovered ? Theme.bgSurfaceHover : Theme.bgSurface
      Text {
        anchors.centerIn: parent
        text: root.muted ? "Unmute" : "Mute"
        color: Theme.fgPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
      }
      HoverHandler { id: mhover }
      TapHandler { onTapped: if (root.au) root.au.muted = !root.au.muted }
    }

    // ---- output-device switcher ----
    Rectangle {
      width: parent.width
      height: 1
      color: Theme.borderSubtle
    }
    Text {
      width: parent.width
      text: "Output"
      color: Theme.fgMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textMicro
    }
    Repeater {
      model: root.sinks
      delegate: Rectangle {
        id: sinkRow
        required property var modelData
        readonly property bool isDefault: root.sink && modelData.id === root.sink.id
        width: parent.width
        height: 30
        radius: Theme.radiusMd
        color: shover.hovered ? Theme.bgSurfaceHover
             : isDefault ? Theme.accentTintSoft : "transparent"
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.space3
          anchors.rightMargin: Theme.space3
          spacing: Theme.space3
          Text {
            text: ""   // volume-high
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textCaption
            color: sinkRow.isDefault ? Theme.accentPrimary : Theme.fgMuted
          }
          Text {
            Layout.fillWidth: true
            text: sinkRow.modelData.description || sinkRow.modelData.nickname || sinkRow.modelData.name
            elide: Text.ElideRight
            color: Theme.fgPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textCaption
          }
          Text {
            visible: sinkRow.isDefault
            text: ""   // check
            color: Theme.accentSuccess
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textMicro
          }
        }
        HoverHandler { id: shover }
        TapHandler { onTapped: root.setSink(sinkRow.modelData) }
      }
    }

    // ---- full audio settings (inputs, per-device volumes, PipeWire mixer) ----
    Rectangle {
      width: parent.width
      height: 28
      radius: Theme.radiusMd
      color: pwhover.hovered ? Theme.bgSurfaceHover : Theme.bgSurface
      Text {
        anchors.centerIn: parent
        text: "Sound settings"
        color: Theme.fgSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
      }
      HoverHandler { id: pwhover }
      TapHandler { onTapped: { if (root.settings) root.settings.open("audio"); pop.visible = false; } }
    }
  }
}
