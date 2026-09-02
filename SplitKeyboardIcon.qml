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

  // Stagger + three rows + gap + a tilted two-key thumb row.
  readonly property real keyUnit: iconSize / 5.3
  readonly property real halfGap: keyUnit * 1.0
  implicitWidth: Math.ceil(keyUnit * 8 + halfGap)
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

    // Column offsets in key units, pinky to inner column. Four columns per
    // half rather than the Sweep's five: at icon sizes the keys need the room
    // more than the count needs to be exact.
    readonly property var stagger: [0.5, 0.15, 0.0, 0.3]
    readonly property int cols: 4
    readonly property int rows: 3

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = root.color

      var key = root.keyUnit
      var gap = root.halfGap                          // space between the halves
      var totalW = key * cols * 2 + gap
      var maxStagger = 0.5 * key
      var thumbTilt = 12 * Math.PI / 180                // thumb rows angle outward like a real split
      var thumb = key * 1.15                            // thumb keys are a touch larger than the grid
      var totalH = maxStagger + key * rows + key * 0.3 + thumb + key * 0.4
      var x0 = (width - totalW) / 2
      var y0 = (height - totalH) / 2
      // A one-pixel gutter separates the columns; the keys within a column
      // get a finer gutter at bar size so the column reads as a segmented bar
      // rather than dissolving into dots.
      var gutter = Math.min(1, key * 0.4)
      var rowGutter = key >= 3.5 ? gutter : Math.min(0.6, key * 0.25)
      var radius = Math.max(0.4, (key - gutter) * 0.25)

      for (var half = 0; half < 2; half++) {
        var hx = x0 + half * (key * cols + gap)
        for (var c = 0; c < cols; c++) {
          var stag = stagger[half === 0 ? c : cols - 1 - c]
          var x = hx + c * key
          var top = y0 + stag * key
          for (var r = 0; r < rows; r++)
            roundRect(ctx, x + gutter / 2, top + r * key + rowGutter / 2, key - gutter, key - rowGutter, radius)
        }
        // Thumb key sits under the two inner columns, pushed toward the middle.
        // Two thumb keys under the inner columns, the row rotated about its
        // outer end so the inner key sits lower, as on a Sweep.
        var ty = y0 + maxStagger + key * rows + key * 0.3
        var pivotX = half === 0 ? hx + key * cols - thumb * 2 : hx + thumb * 2
        ctx.save()
        ctx.translate(pivotX, ty)
        ctx.rotate(half === 0 ? thumbTilt : -thumbTilt)
        for (var t = 0; t < 2; t++) {
          var tx = half === 0 ? t * thumb : -(t + 1) * thumb
          roundRect(ctx, tx + gutter / 2, gutter / 2, thumb - gutter, thumb - gutter / 2, radius)
        }
        ctx.restore()
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
