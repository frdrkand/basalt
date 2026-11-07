import QtQuick
import QtQuick.Layouts
import qs.basalt.theme

// Right-side power button. Because the bar lives in the same quickshell process as
// the power menu, it calls powerMenu.toggle() directly (no `qs ipc call` hop like
// Waybar used). powerMenu is passed down from shell.qml via Bar.
Rectangle {
  id: root
  property var powerMenu

  Layout.alignment: Qt.AlignVCenter
  implicitWidth: 30
  implicitHeight: Theme.barHeight - 8
  radius: Theme.radiusMd
  color: hover.hovered ? Theme.accentTintHover : "transparent"

  Text {
    anchors.centerIn: parent
    text: String.fromCodePoint(0xf011)   // Nerd Font power-off glyph
    font.family: Theme.fontGlyph
    font.pixelSize: Theme.textBody
    color: hover.hovered ? Theme.accentDanger : Theme.fgSecondary
  }

  HoverHandler { id: hover }
  TapHandler { onTapped: if (root.powerMenu) root.powerMenu.toggle() }
}
