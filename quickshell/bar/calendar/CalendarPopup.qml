import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.basalt.theme

// Calendar dropdown, ported from the design system's CalendarPopup
// (ui_kits/status_bar/StatusBarScreen.jsx): Monday-first grid, muted weekday row,
// secondary day numbers, and TODAY rendered as a rounded radius-sm chip in
// fg-on-accent over accent-primary — the rounded chip Waybar's Pango calendar
// couldn't produce. Prev/next arrows and mouse-wheel both page the month.
PopupWindow {
  id: pop
  property var anchorItem

  visible: false
  color: "transparent"
  grabFocus: true

  anchor.item: anchorItem
  anchor.edges: Edges.Bottom
  anchor.gravity: Edges.Bottom

  implicitWidth: 280
  implicitHeight: content.height + Theme.space6 * 2

  // ---- month state ----
  property date today: new Date()
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()   // 0-11

  // day the pointer is hovering (0 = none); drives the holiday name line below.
  property int hoveredDay: 0

  function shift(n) {
    var m = viewMonth + n;
    var y = viewYear + Math.floor(m / 12);
    viewYear = y;
    viewMonth = ((m % 12) + 12) % 12;
    hoveredDay = 0;
  }
  function resetToday() {
    today = new Date();
    viewYear = today.getFullYear();
    viewMonth = today.getMonth();
    hoveredDay = 0;
  }
  function isToday(d) {
    return d === today.getDate()
        && viewMonth === today.getMonth()
        && viewYear === today.getFullYear();
  }

  // Swedish holidays ("röda dagar") for the visible month. The name line prefers
  // the hovered red day, else falls back to today when today itself is a red day.
  readonly property int todayInView:
    (viewMonth === today.getMonth() && viewYear === today.getFullYear()) ? today.getDate() : 0
  readonly property int nameDay:
    (hoveredDay > 0 && Holidays.isRedDay(viewYear, viewMonth, hoveredDay)) ? hoveredDay
      : (todayInView > 0 && Holidays.isRedDay(viewYear, viewMonth, todayInView)) ? todayInView : 0
  readonly property string holidayLabel:
    nameDay > 0 ? Holidays.labelFor(viewYear, viewMonth, nameDay) : ""
  readonly property color softRed: Qt.lighter(Theme.accentDanger, 1.5)

  // Monday-first cell list: leading blanks (0) then day numbers.
  readonly property var cells: {
    var first = new Date(viewYear, viewMonth, 1);
    var lead = (first.getDay() + 6) % 7;
    var dim = new Date(viewYear, viewMonth + 1, 0).getDate();
    var arr = [];
    for (var i = 0; i < lead; i++) arr.push(0);
    for (var d = 1; d <= dim; d++) arr.push(d);
    return arr;
  }

  // snap back to the current month whenever it re-opens
  onVisibleChanged: if (visible) resetToday()

  Rectangle {
    id: card
    anchors.fill: parent
    radius: Theme.radiusLg
    color: Theme.popupBackground
    border.color: Theme.borderSubtle
    border.width: 1

    WheelHandler {
      onWheel: (ev) => pop.shift(ev.angleDelta.y < 0 ? 1 : -1)
    }

    ColumnLayout {
      id: content
      anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space6 }
      spacing: Theme.space4

      // ---- header:  <  Month Year  >  ----
      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        // prev-month arrow (Nerd Font chevron-left)
        Rectangle {
          implicitWidth: 24; implicitHeight: 24
          radius: Theme.radiusSm
          color: prevHover.hovered ? Theme.accentTintSoft : "transparent"
          Text {
            anchors.centerIn: parent
            text: ""
            color: Theme.fgSecondary
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textCaption
          }
          HoverHandler { id: prevHover }
          TapHandler { onTapped: pop.shift(-1) }
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: new Date(pop.viewYear, pop.viewMonth, 1)
                  .toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy")
          color: Theme.fgEmphasis
          font.family: Theme.fontFamily
          font.pixelSize: Theme.textTitle
          font.weight: Theme.weightBold
        }

        // next-month arrow (chevron-right)
        Rectangle {
          implicitWidth: 24; implicitHeight: 24
          radius: Theme.radiusSm
          color: nextHover.hovered ? Theme.accentTintSoft : "transparent"
          Text {
            anchors.centerIn: parent
            text: ""
            color: Theme.fgSecondary
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textCaption
          }
          HoverHandler { id: nextHover }
          TapHandler { onTapped: pop.shift(1) }
        }
      }

      // ---- weekday header (Monday-first) ----
      GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: Theme.space2
        rowSpacing: 0
        Repeater {
          model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
          Text {
            required property var modelData
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: modelData
            color: Theme.fgMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textCaption
          }
        }
      }

      // ---- day grid ----
      GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: Theme.space1
        rowSpacing: Theme.space1
        Repeater {
          model: pop.cells
          Item {
            id: dayCell
            required property var modelData
            readonly property bool real: modelData > 0
            readonly property bool today: real && pop.isToday(modelData)
            readonly property bool red: real && Holidays.isRedDay(pop.viewYear, pop.viewMonth, modelData)
            readonly property bool official: red && Holidays.isOfficial(pop.viewYear, pop.viewMonth, modelData)
            Layout.fillWidth: true
            implicitHeight: 26

            Rectangle {
              anchors.centerIn: parent
              width: 24; height: 24
              radius: Theme.radiusSm
              visible: dayCell.real
              // today = filled chip (red chip if today is itself a red day);
              // other red days tint the text (full red official, soft red de-facto).
              color: dayCell.today ? (dayCell.red ? Theme.accentDanger : Theme.accentPrimary)
                                   : "transparent"
              Text {
                anchors.centerIn: parent
                text: dayCell.real ? dayCell.modelData : ""
                color: dayCell.today ? Theme.fgOnAccent
                     : dayCell.official ? Theme.accentDanger
                     : dayCell.red ? pop.softRed
                     : Theme.fgSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textCaption
              }
              HoverHandler {
                enabled: dayCell.real
                onHoveredChanged: if (hovered) pop.hoveredDay = dayCell.modelData
              }
            }
          }
        }
      }

      // ---- Swedish holiday name line (hovered red day, else today) ----
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.borderSubtle
        visible: pop.holidayLabel.length > 0
      }
      Text {
        Layout.fillWidth: true
        visible: pop.holidayLabel.length > 0
        text: pop.holidayLabel
        color: pop.softRed
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
      }
    }
  }
}
