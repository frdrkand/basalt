import QtQuick
import Quickshell
import qs.basalt.theme

// Shared dropdown for bar modules: an opaque, rounded card anchored under the
// clicked module item. Declare content directly inside a BarPopup {} — children
// go into the padded Column. Toggle by setting `visible`.
PopupWindow {
  id: pop
  property var anchorItem
  property int contentWidth: 260
  default property alias contentData: holder.data

  visible: false
  color: "transparent"
  grabFocus: true

  // qmllint disable missing-property
  anchor.item: anchorItem
  anchor.edges: Edges.Bottom
  anchor.gravity: Edges.Bottom
  // qmllint enable missing-property

  implicitWidth: contentWidth
  implicitHeight: holder.implicitHeight + Theme.space5 * 2

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusLg
    color: Theme.popupBackground
    border.color: Theme.borderSubtle
    border.width: 1

    Column {
      id: holder
      anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space5 }
      spacing: Theme.space3
    }
  }
}
