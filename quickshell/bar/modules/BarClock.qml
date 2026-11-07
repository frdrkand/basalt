import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.basalt.bar.calendar
import qs.basalt.theme

// Center clock module: a clickable pill showing the date/time. Clicking (or
// scrolling) toggles/pages the calendar dropdown anchored beneath it. Replaces
// Waybar's clock module + its Pango calendar tooltip.
Rectangle {
  id: pill
  property var barWindow

  Layout.alignment: Qt.AlignVCenter
  implicitWidth: label.implicitWidth + Theme.space5 * 2
  implicitHeight: Theme.barHeight - 8
  radius: Theme.radiusMd
  color: cal.visible ? Theme.accentTintHover
       : (hover.hovered ? Theme.accentTintSoft : "transparent")

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: Qt.formatDateTime(clock.date, "yyyy-MM-dd  HH:mm")
    color: cal.visible ? Theme.fgEmphasis : Theme.fgPrimary
    font.family: Theme.fontFamily
    font.pixelSize: Theme.textLabel
    font.weight: Theme.weightMedium
  }

  HoverHandler { id: hover }
  TapHandler { onTapped: cal.visible = !cal.visible }
  WheelHandler {
    // scroll over the clock pages the (already-open) calendar month
    onWheel: (ev) => { if (cal.visible) cal.shift(ev.angleDelta.y < 0 ? 1 : -1); }
  }

  CalendarPopup {
    id: cal
    anchorItem: pill
  }
}
