import QtQuick
import qs.basalt.theme

// A column layout drawn as a picture: one bar per slice, as wide as its share
// (1 2 1 is a narrow, a wide and a narrow bar). Used small on the bar
// (Columns.qml) and large in the tiling chord popup (TilingChord.qml), so both
// draw a layout the same way.
//
// The width is picked rather than set: the picture is about `minWidth` wide,
// adjusted by a few pixels so the slices land on their true proportions.
Item {
  id: root

  property var weights: []          // relative widths, e.g. [1, 2, 1]
  property int minWidth: 24
  property int boxHeight: 14
  property int gap: 2
  property int radius: Theme.radiusSm
  property color color: Theme.fgSecondary

  // Each slice's share as a rounded percentage, written inside it when there is
  // room (the popup turns this on; the bar icon is too small for text).
  property bool labels: false
  property int labelSize: 13
  property color labelColor: Theme.bgCanvas

  readonly property int count: weights ? weights.length : 0
  readonly property real total: {
    var t = 0;
    for (var i = 0; i < count; i++) t += weights[i];
    return t;
  }

  // [{x, w, ideal, pct}] per slice for a picture `width` wide. Edges are
  // rounded from the running total, as the layout itself does, so the slices
  // fill the picture.
  function cut(width) {
    var room = width - gap * (count - 1);
    var out = [], acc = 0;
    for (var s = 0; s < count; s++) {
      var left = Math.round(room * acc / total);
      acc += weights[s];
      var right = Math.round(room * acc / total);
      out.push({
        x: left + s * gap,
        w: Math.max(1, right - left),
        ideal: room * weights[s] / total,
        pct: Math.round(100 * weights[s] / total)
      });
    }
    return out;
  }

  // At small sizes a pixel is a big share of a slice, so rounding shows: 1 1 1 1
  // in 24 px comes out 5/4/5/4. Of a few widths, use the one whose slices land
  // closest to their true proportions (that one is 26 px, 5/5/5/5).
  readonly property var picture: {
    if (count === 0) return { width: minWidth, slices: [] };
    var base = Math.max(minWidth, count * 5);
    var best = null;
    for (var width = base; width <= base + 6; width++) {
      var sl = cut(width), err = 0;
      for (var k = 0; k < sl.length; k++) err = Math.max(err, Math.abs(sl[k].w - sl[k].ideal));
      if (!best || err < best.err - 0.01) best = { width: width, slices: sl, err: err };
    }
    return best;
  }

  implicitWidth: picture.width
  implicitHeight: boxHeight

  Repeater {
    model: root.picture.slices
    delegate: Rectangle {
      id: slice
      required property var modelData
      x: modelData.x
      width: modelData.w
      height: root.boxHeight
      radius: root.radius
      color: root.color

      Text {
        anchors.centerIn: parent
        visible: root.labels && implicitWidth + 8 <= slice.width
        text: slice.modelData.pct + "%"
        font.family: Theme.fontFamily
        font.pixelSize: root.labelSize
        color: root.labelColor
      }
    }
  }
}
