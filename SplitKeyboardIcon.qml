import QtQuick

// A mini split keyboard: two halves of five column-staggered columns, each
// with a thumb key on its inner edge, the silhouette of a Ferris Sweep.
// Drawn as filled shapes so it stays crisp at bar size and reads as two
// separate blocks at a glance.
Item {
  id: root

  // Height of the glyph; a split keyboard is about twice as wide as it is tall.
  property real iconSize: 16
  property color color: "#ffffff"

  readonly property real keyUnit: iconSize / 5.0
  readonly property real halfGap: keyUnit * 1.1
  implicitWidth: Math.ceil(keyUnit * 10 + halfGap)
  implicitHeight: iconSize

  onColorChanged: canvas.requestPaint()
  onIconSizeChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true
    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // Column offsets in key units, pinky to inner column (Sweep stagger).
    readonly property var stagger: [0.55, 0.28, 0.0, 0.15, 0.4]
    readonly property int cols: 5
    readonly property int rows: 3

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = root.color

      var key = root.keyUnit
      var gap = root.halfGap                          // space between the halves
      var totalW = key * cols * 2 + gap
      var maxStagger = 0.55 * key
      var totalH = maxStagger + key * rows + key * 0.5 + key * 0.95
      var x0 = (width - totalW) / 2
      var y0 = (height - totalH) / 2
      // Column bodies touch below ~2.5px per key; above that a hairline gap shows the columns.
      var inset = key >= 2.5 ? key * 0.09 : 0
      var radius = Math.max(0.5, key * 0.28)

      for (var half = 0; half < 2; half++) {
        var hx = x0 + half * (key * cols + gap)
        for (var c = 0; c < cols; c++) {
          var stag = stagger[half === 0 ? c : cols - 1 - c]
          var x = hx + c * key
          var y = y0 + stag * key
          roundRect(ctx, x + inset, y, key - inset * 2, key * rows - inset, radius)
        }
        // Thumb key sits under the two inner columns, pushed toward the middle.
        var tw = key * 2.0, th = key * 0.95
        var tx = half === 0 ? hx + key * cols - tw - key * 0.05 : hx + key * 0.05
        var ty = y0 + maxStagger + key * rows + key * 0.5
        roundRect(ctx, tx, ty, tw, th, radius)
      }
    }

    function roundRect(ctx, x, y, w, h, r) {
      r = Math.min(r, w / 2, h / 2)
      ctx.beginPath()
      ctx.moveTo(x + r, y)
      ctx.lineTo(x + w - r, y)
      ctx.quadraticCurveTo(x + w, y, x + w, y + r)
      ctx.lineTo(x + w, y + h - r)
      ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
      ctx.lineTo(x + r, y + h)
      ctx.quadraticCurveTo(x, y + h, x, y + h - r)
      ctx.lineTo(x, y + r)
      ctx.quadraticCurveTo(x, y, x + r, y)
      ctx.closePath()
      ctx.fill()
    }
  }
}
