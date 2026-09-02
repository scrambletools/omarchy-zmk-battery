.pragma library

// Shared between the service and the panel: parsing of the zmk-battery
// script's JSON line, and the small formatting helpers the rows use.

var LEVEL_UNKNOWN = -1

function parse(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: false, error: "no output from zmk-battery" }
  var data
  try {
    data = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "unreadable output from zmk-battery" }
  }
  var levels = []
  if (Array.isArray(data.levels)) {
    for (var i = 0; i < data.levels.length; i++) {
      var v = data.levels[i]
      levels.push(typeof v === "number" && v >= 0 ? Math.min(100, Math.round(v)) : LEVEL_UNKNOWN)
    }
  }
  return {
    ok: true,
    connected: !!data.connected,
    levels: levels,
    error: data.error ? String(data.error) : ""
  }
}

function levelText(level) {
  return level === LEVEL_UNKNOWN || level === undefined || level === null ? "--" : String(level) + "%"
}

function levelFraction(level) {
  if (level === LEVEL_UNKNOWN || level === undefined || level === null) return 0
  return Math.max(0, Math.min(1, level / 100))
}

// The first Battery Service belongs to the central half, the second to the
// peripheral it fetched from. Which side is central is a build choice, so the
// side label comes from a setting and the role goes in the meta column.
function halfLabel(index, count, centralSide) {
  // One Battery Service means the firmware does not forward the peripheral's
  // level (or the keyboard is not a split), so there is no side to name.
  if (count <= 1) return "Keyboard"
  var central = centralSide === "right" ? "Right" : "Left"
  var peripheral = central === "Left" ? "Right" : "Left"
  if (index === 0) return central
  if (index === 1) return peripheral
  return "Battery " + (index + 1)
}

function halfRole(index, count) {
  if (count <= 1) return ""
  return index === 0 ? "central" : index === 1 ? "peripheral" : ""
}

// Refresh interval choices the panel cycles through, in seconds.
var POLL_PRESETS = [30, 60, 120, 300, 600, 1800]

function nextPollSeconds(current) {
  for (var i = 0; i < POLL_PRESETS.length; i++)
    if (POLL_PRESETS[i] > current) return POLL_PRESETS[i]
  return POLL_PRESETS[0]
}

function intervalText(seconds) {
  if (seconds < 60) return seconds + " s"
  var mins = seconds / 60
  if (mins < 60) return (Number.isInteger(mins) ? mins : mins.toFixed(1)) + " min"
  return (seconds / 3600) + " h"
}
