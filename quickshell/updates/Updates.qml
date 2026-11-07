import QtQuick
import QtQuick.Layouts
import qs.basalt.bar
import qs.basalt.theme

// The bar's updates pill. Answers one question, whether anything has an
// update, from the host's status command (UpdatesStatus.qml), and shows it as
// one glyph, no number:
//
//    package (f487)          up to date, muted — the state you are in most days
//    cloud-download (f0ed)   something has an update, warning-toned
//    sync (f021)             checking, or never checked yet, muted
//    triangle (f071)         checking is failing, or the command gave no answer —
//                            the only time anything here is red
//
// The popup says which parts, and the package list belongs to the details
// window. Nothing here can start a check: the host's status command answers
// from what it already knows, and the only way to ask for a check from the
// shell is the window's "Check now", when the host offers one.
Rectangle {
  id: root
  property var window          // UpdatesWindow scope, from Basalt.qml

  readonly property var st: UpdatesStatus
  readonly property var parts: st.details ? st.details.parts : []
  // Notices worth raising here: the muted ones are the window's small print.
  readonly property var notices: st.details && st.details.notices
    ? st.details.notices.filter(n => n.tone === "warning" || n.tone === "danger") : []

  Layout.alignment: Qt.AlignVCenter
  implicitHeight: Theme.barHeight - 8
  implicitWidth: 26
  radius: Theme.radiusMd
  color: pop.visible ? Theme.accentTintHover
       : hover.hovered ? Theme.accentTintSoft : "transparent"

  Text {
    anchors.centerIn: parent
    text: root.st.failed ? ""                                // triangle
        : (root.st.busy || !root.st.known) ? ""               // sync
        : root.st.available ? ""                             // cloud-download
        : ""                                                // package
    font.family: Theme.fontGlyph
    font.pixelSize: Theme.textBody
    color: root.st.failed ? Theme.accentDanger
         : (root.st.available && !root.st.busy) ? Theme.accentWarning
         : Theme.fgMuted
  }

  HoverHandler { id: hover }
  TapHandler {
    onTapped: {
      pop.visible = !pop.visible;
      if (pop.visible) {
        root.st.poll();
        root.st.loadDetails();
      }
    }
  }

  BarPopup {
    id: pop
    anchorItem: root
    contentWidth: 280

    Text {
      width: parent.width
      text: "Updates"
      color: Theme.fgEmphasis
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textLabel
      font.weight: Theme.weightBold
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: root.st.summary
      color: root.st.failed ? Theme.accentDanger
           : root.st.available ? Theme.fgPrimary
           : Theme.fgSecondary
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      visible: root.st.error.length > 0
      text: root.st.error
      color: Theme.fgMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textMicro
    }

    // One row per part: how many updates, or why it can't say.
    Repeater {
      model: root.st.reachable ? root.parts : []
      delegate: RowLayout {
        id: partRow
        required property var modelData
        readonly property int count: (modelData.updates || []).length
        width: parent ? parent.width : 0
        spacing: Theme.space3

        Text {
          Layout.fillWidth: true
          text: partRow.modelData.name
          elide: Text.ElideRight
          color: partRow.count > 0 ? Theme.fgPrimary : Theme.fgSecondary
          font.family: Theme.fontFamily
          font.pixelSize: Theme.textCaption
        }
        Text {
          text: partRow.modelData.busy ? "checking"
              : partRow.modelData.error ? "failed"
              : partRow.count > 0 ? partRow.count
              : !partRow.modelData.checkedAt ? "—"
              : "up to date"
          color: partRow.modelData.error && !partRow.modelData.busy ? Theme.accentDanger
               : partRow.count > 0 ? Theme.accentWarning
               : Theme.fgMuted
          font.family: Theme.fontFamily
          font.pixelSize: Theme.textCaption
        }
      }
    }

    Repeater {
      model: root.notices
      delegate: Text {
        required property var modelData
        width: parent ? parent.width : 0
        wrapMode: Text.WordWrap
        text: modelData.text
        color: modelData.tone === "danger" ? Theme.accentDanger : Theme.fgMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textMicro
      }
    }

    Text {
      width: parent.width
      visible: root.st.reachable && root.st.known
      text: "Checked " + root.st.stamp(root.st.checkedAt)
      color: Theme.fgMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.textCaption
    }

    // One action, and it only opens a window.
    Rectangle {
      width: parent.width
      height: 28
      visible: root.st.hasDetails
      radius: Theme.radiusMd
      color: bhover.hovered ? Theme.bgSurfaceHover : Theme.bgSurface

      Text {
        anchors.centerIn: parent
        text: "Show details"
        color: Theme.fgSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
      }

      HoverHandler { id: bhover }
      TapHandler {
        onTapped: {
          if (root.window) root.window.open();
          pop.visible = false;
        }
      }
    }
  }
}
