import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "Model.js" as Model

// Watches BlueZ for the keyboard and reads both halves' battery levels with
// the bundled zmk-battery script while it is connected. Also finds ZMK Studio
// on PATH so the panel can offer to launch it.
Item {
  id: root

  property var settings: ({})

  readonly property string deviceName: String(setting("deviceName", "Cradio"))
  readonly property int pollSeconds: Math.max(10, parseInt(setting("pollSeconds", 90), 10) || 90)
  readonly property string centralSide: String(setting("centralSide", "left"))
  readonly property string scriptPath: Qt.resolvedUrl("zmk-battery").toString().replace(/^file:\/\//, "")

  // Connection state comes from the shell's own Bluetooth binding, so the
  // icon reacts the moment the keyboard appears or drops, with no polling.
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var device: findDevice(devices, deviceName)
  readonly property bool connected: device ? !!device.connected : false
  readonly property bool known: device !== null

  property var levels: []
  property string lastError: ""
  property double updatedAt: 0
  readonly property bool busy: readProc.running
  readonly property bool hasLevels: levels.length > 0

  property string studioPath: ""
  readonly property bool studioInstalled: studioPath !== ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function findDevice(list, name) {
    if (!list) return null
    for (var i = 0; i < list.length; i++) {
      var d = list[i]
      if (d && (d.name === name || d.deviceName === name)) return d
    }
    return null
  }

  function refresh() {
    if (!connected) { levels = []; return }
    if (readProc.running) return
    readProc.command = [scriptPath, "--json", deviceName]
    readProc.running = true
  }

  function checkStudio() {
    if (!studioProc.running) studioProc.running = true
  }

  function openStudio() {
    if (!studioInstalled) return false
    Quickshell.execDetached(["uwsm-app", "--", studioPath])
    return true
  }

  onConnectedChanged: {
    if (connected) settleTimer.restart()
    else { levels = []; lastError = "" }
  }

  Component.onCompleted: {
    checkStudio()
    if (connected) refresh()
  }

  // GATT attributes are still being resolved right after a connect; a read
  // fired instantly finds no Battery Service, so give BlueZ a moment.
  Timer {
    id: settleTimer
    interval: 2500
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: root.pollSeconds * 1000
    running: root.connected
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: readProc
    running: false
    command: []
    stdout: StdioCollector { id: readOut; waitForEnd: true }
    stderr: StdioCollector { id: readErr; waitForEnd: true }
    onExited: function (exitCode) {
      var result = Model.parse(readOut.text)
      if (!result.ok) {
        root.lastError = String(readErr.text || "").trim() || result.error
        return
      }
      root.levels = result.levels
      root.lastError = result.error
      if (result.levels.length > 0) root.updatedAt = Date.now()
    }
  }

  Process {
    id: studioProc
    running: false
    command: ["sh", "-c", "command -v zmk-studio"]
    stdout: StdioCollector { id: studioOut; waitForEnd: true }
    onExited: function (exitCode) {
      root.studioPath = exitCode === 0 ? String(studioOut.text || "").trim() : ""
    }
  }
}
