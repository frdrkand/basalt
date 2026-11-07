import QtQuick
import qs.basalt.theme

// Small on/off switch. State always comes from the system (adapter powered, mute,
// …), so this only reports intent via toggled() — it never flips itself.
Rectangle {
  id: root

  property bool checked: false
  signal toggled(bool value)

  implicitWidth: 40
  implicitHeight: 22
  radius: Theme.radiusPill
  color: checked ? Theme.accentPrimary : Theme.bgSurfaceHover

  Rectangle {
    width: 16
    height: 16
    radius: Theme.radiusPill
    anchors.verticalCenter: parent.verticalCenter
    x: root.checked ? parent.width - width - 2 : 2
    color: Theme.fgEmphasis
    Behavior on x { NumberAnimation { duration: 120 } }
  }

  TapHandler { onTapped: root.toggled(!root.checked) }
}
