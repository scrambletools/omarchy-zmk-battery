import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "Model.js" as Model

// Watches BlueZ for the keyboard and reads both halves' battery levels with
// the bundled zmk-battery script while it is connected. Also checks whether
// ZMK Studio is installed in a system location so the panel can offer to
// launch it.
//
// Everything that leaves this file is a fixed absolute path: the bundled
// script (run with /usr/bin/python3), /usr/bin/omarchy to save a setting,
// /usr/bin/test to probe for binaries, and /usr/bin/uwsm-app to launch a
// ZMK Studio found in /usr/bin or /usr/local/bin. No shell is involved, each
// helper runs under a watchdog, and its output is bounded before use.
Item {
  id: root

  property var settings: ({})

  readonly property string pluginId: "io.github.scrambletools.zmk-battery"
  readonly property string python: "/usr/bin/python3"
  readonly property string omarchyBin: "/usr/bin/omarchy"
  readonly property string testBin: "/usr/bin/test"
  readonly property string launcher: "/usr/bin/uwsm-app"
  readonly property var studioCandidates: ["/usr/bin/zmk-studio", "/usr/local/bin/zmk-studio"]
  readonly property int helperTimeoutMs: 30000

  // The device name is user configuration; it becomes one argv element of the
  // bundled script, so keep it to a bounded, printable string.
  readonly property string deviceName: Model.cleanName(setting("deviceName", "Cradio"))
  readonly property int pollSeconds: Model.clampPoll(setting("pollSeconds", 90))
  readonly property string centralSide: String(setting("centralSide", "left")) === "right" ? "right" : "left"
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
  property bool launcherPresent: false
  readonly property bool studioInstalled: studioPath !== ""

  // Each helper start gets a generation number; a result from an earlier,
  // superseded start (killed by the watchdog, or racing a restart) is dropped.
  property int generation: 0

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
    generation++
    readProc.generation = generation
    readProc.command = [python, scriptPath, "--json", deviceName]
    readProc.running = true
    readWatchdog.restart()
  }

  // Look for ZMK Studio in the two system locations, one probe at a time.
  function checkStudio() {
    if (probeProc.running) return
    probeIndex = 0
    probeNext()
  }

  property int probeIndex: 0

  function probeNext() {
    if (probeIndex >= studioCandidates.length) {
      studioPath = ""
      probeLauncher()
      return
    }
    probeProc.target = studioCandidates[probeIndex]
    probeProc.command = [testBin, "-x", probeProc.target]
    probeProc.running = true
  }

  function probeLauncher() {
    launcherProc.command = [testBin, "-x", launcher]
    launcherProc.running = true
  }

  // Persist through Omarchy so the value lands in shell.json like any other
  // widget setting; the shell hands the new settings object back to us.
  function setPollSeconds(seconds) {
    if (settingProc.running) return
    settingProc.command = [omarchyBin, "bar", "set", pluginId, "pollSeconds", String(Model.clampPoll(seconds)), "--json"]
    settingProc.running = true
    settingWatchdog.restart()
  }

  function openStudio() {
    if (!studioInstalled) return false
    if (launcherPresent) Quickshell.execDetached([launcher, "--", studioPath])
    else Quickshell.execDetached([studioPath])
    return true
  }

  onConnectedChanged: {
    if (connected) settleTimer.restart()
    else { levels = []; lastError = "" }
  }

  Component.onCompleted: {
    depProc.command = [python, scriptPath, "--json", "--check"]
    depProc.running = true
    checkStudio()
    if (connected) refresh()
  }

  Component.onDestruction: {
    readProc.running = false
    settingProc.running = false
    probeProc.running = false
    launcherProc.running = false
    depProc.running = false
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

  // The script bounds itself to 20 s; this is the backstop if it does not.
  Timer {
    id: readWatchdog
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: {
      if (!readProc.running) return
      readProc.running = false
      root.lastError = "zmk-battery timed out"
    }
  }

  Timer {
    id: settingWatchdog
    interval: root.helperTimeoutMs
    repeat: false
    onTriggered: if (settingProc.running) settingProc.running = false
  }

  Process {
    id: readProc
    property int generation: 0
    running: false
    command: []
    stdout: StdioCollector { id: readOut; waitForEnd: true }
    stderr: StdioCollector { id: readErr; waitForEnd: true }
    onExited: function (exitCode) {
      readWatchdog.stop()
      if (generation !== root.generation) return
      var result = Model.parse(readOut.text)
      if (!result.ok) {
        root.lastError = Model.cleanText(readErr.text, Model.MAX_ERROR) || result.error
        return
      }
      root.levels = result.levels
      root.lastError = result.error
      if (result.levels.length > 0) root.updatedAt = Date.now()
    }
  }

  Process {
    id: depProc
    running: false
    command: []
    stdout: StdioCollector { id: depOut; waitForEnd: true }
    onExited: function (exitCode) {
      var check = Model.parseCheck(depOut.text)
      if (exitCode !== 0 || !check.ok) root.lastError = check.error || "zmk-battery cannot run"
    }
  }

  Process {
    id: settingProc
    running: false
    command: []
    stderr: StdioCollector { id: settingErr; waitForEnd: true }
    onExited: function (exitCode) {
      settingWatchdog.stop()
      if (exitCode !== 0) root.lastError = Model.cleanText(settingErr.text, Model.MAX_ERROR) || "could not save the setting"
    }
  }

  Process {
    id: probeProc
    property string target: ""
    running: false
    command: []
    onExited: function (exitCode) {
      if (exitCode === 0) {
        root.studioPath = target
        root.probeLauncher()
        return
      }
      root.probeIndex++
      root.probeNext()
    }
  }

  Process {
    id: launcherProc
    running: false
    command: []
    onExited: function (exitCode) { root.launcherPresent = exitCode === 0 }
  }
}
