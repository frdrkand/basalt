import QtQuick
import QtQuick.Layouts
import qs.basalt.bar
import qs.basalt.shared
import qs.basalt.theme

// Memory module. Icon + used percentage, tinted by Theme.loadTone. Click opens a
// popup with the used/total split, what is still available and cached, and swap
// where the host has any.
//
// Sampling lives in the SystemStats singleton, alongside the note on why "used"
// is total minus available rather than total minus free.
Rectangle {
  id: root
  readonly property int pct: SystemStats.memPct
  readonly property color tone: Theme.loadTone(pct)

  Layout.alignment: Qt.AlignVCenter
  implicitHeight: Theme.barHeight - 8
  implicitWidth: mrow.implicitWidth + Theme.space4
  radius: Theme.radiusMd
  color: pop.visible ? Theme.accentTintHover
       : hover.hovered ? Theme.accentTintSoft : "transparent"

  // Same reasoning as Cpu.qml: pin the readout so a changing number does not
  // reflow the modules to its right.
  TextMetrics {
    id: pctMetrics
    font.family: Theme.fontFamily
    font.pixelSize: Theme.textLabel
    font.weight: Theme.weightMedium
    text: "100%"
  }

  RowLayout {
    id: mrow
    anchors.centerIn: parent
    spacing: Theme.space2

    Text {
      // Above the BMP, hence the surrogate pair — see the note in Cpu.qml.
      text: "󰍛"  // nf-md-memory
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
    contentWidth: 240

    Text {
      width: parent.width
      text: "Memory"
      color: Theme.fgEmphasis
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textLabel
      font.weight: Theme.weightBold
    }
    Text {
      width: parent.width
      text: root.pct + "%  ·  " + SystemStats.fmtGiB(SystemStats.memUsedKb)
          + " / " + SystemStats.fmtGiB(SystemStats.memTotalKb)
      color: Theme.fgSecondary
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }
    Text {
      width: parent.width
      text: "Available  " + SystemStats.fmtGiB(SystemStats.memAvailableKb)
      color: Theme.fgMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }
    Text {
      width: parent.width
      text: "Cached  " + SystemStats.fmtGiB(SystemStats.cachedKb)
      color: Theme.fgMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }
    Text {
      width: parent.width
      visible: SystemStats.hasSwap
      text: "Swap  " + SystemStats.fmtGiB(SystemStats.swapUsedKb)
          + " / " + SystemStats.fmtGiB(SystemStats.swapTotalKb)
      color: Theme.fgMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }
  }
}
