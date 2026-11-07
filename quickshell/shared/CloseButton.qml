import QtQuick
import qs.basalt.theme

// Window close "×" for the shell's toplevel windows (Settings, Updates).
// Hyprland draws no title bar, so without this a FloatingWindow can only be
// closed by Esc or SUPER+Q. Mouse-only on purpose: Esc already closes from the
// keyboard, and taking Tab focus would break each window's key model.
Rectangle {
  id: root

  signal clicked()

  implicitWidth: 28
  implicitHeight: 28
  radius: Theme.radiusMd
  color: hover.hovered ? Theme.bgSurfaceHover : "transparent"

  Text {
    anchors.centerIn: parent
    text: "\uf00d"   // times
    color: hover.hovered ? Theme.fgEmphasis : Theme.fgMuted
    font.family: Theme.fontGlyph
    font.pixelSize: Theme.textBody
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: root.clicked() }
}
