import QtQuick
import QtQuick.Layouts
import qs.basalt.bar
import qs.basalt.shared
import qs.basalt.theme

// CPU module. Icon + aggregate utilisation, tinted by Theme.loadTone. Click opens
// a popup with the load averages and a per-core meter grid.
//
// All the sampling lives in the SystemStats singleton — see the note there about
// why it cannot live in this file.
Rectangle {
  id: root
  readonly property int pct: SystemStats.cpuPct
  readonly property color tone: Theme.loadTone(pct)

  Layout.alignment: Qt.AlignVCenter
  implicitHeight: Theme.barHeight - 8
  implicitWidth: crow.implicitWidth + Theme.space4
  radius: Theme.radiusMd
  color: pop.visible ? Theme.accentTintHover
       : hover.hovered ? Theme.accentTintSoft : "transparent"

  // The readout changes every couple of seconds, and letting it size itself would
  // shove Battery and Power sideways on every tick. Pinned to the width of the
  // widest value it can ever show, right-aligned so the digits stay put.
  TextMetrics {
    id: pctMetrics
    font.family: Theme.fontFamily
    font.pixelSize: Theme.textLabel
    font.weight: Theme.weightMedium
    text: "100%"
  }

  RowLayout {
    id: crow
    anchors.centerIn: parent
    spacing: Theme.space2

    Text {
      // Surrogate pair, unlike the FontAwesome glyphs elsewhere in this bar: the
      // Material Design range Nerd Fonts puts these in is above the BMP.
      text: "󰻠"  // nf-md-cpu_64_bit
      font.family: Theme.fontGlyph
      font.pixelSize: Theme.textBody
      color: root.tone
    }
    Text {
      text: root.pct + "%"
      Layout.preferredWidth: pctMetrics.width
      horizontalAlignment: Text.AlignRight
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textLabel
      font.weight: Theme.weightMedium
      color: root.tone
    }
  }

  HoverHandler { id: hover }
  TapHandler { onTapped: pop.visible = !pop.visible }

  BarPopup {
    id: pop
    anchorItem: root
    contentWidth: 260

    Text {
      width: parent.width
      text: "CPU"
      color: Theme.fgEmphasis
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textLabel
      font.weight: Theme.weightBold
    }
    Text {
      width: parent.width
      text: root.pct + "%  ·  " + SystemStats.coreCount + " cores"
      color: Theme.fgSecondary
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }
    Text {
      width: parent.width
      text: "Load  " + SystemStats.loadText
      color: Theme.fgMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }

    // Per-core meters, wrapped six to a row so a 12-core box reads as two tidy
    // rows rather than a twelve-line list.
    Grid {
      id: cores
      width: parent.width
      spacing: Theme.space2
      columns: Math.min(6, Math.max(1, SystemStats.coreCount))
      readonly property real cellWidth: (width - (columns - 1) * spacing) / columns

      Repeater {
        model: SystemStats.coreLoads

        Rectangle {
          id: core
          required property var modelData

          width: cores.cellWidth
          height: 4
          radius: Theme.radiusSm
          color: Theme.bgSurfaceHover

          Rectangle {
            width: parent.width * core.modelData / 100
            height: parent.height
            radius: parent.radius
            color: Theme.loadTone(core.modelData)
          }
        }
      }
    }
  }
}
