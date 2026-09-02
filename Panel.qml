import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.scrambletools.zmk-battery"
  ipcTarget: "zmk-battery"
  manageIpc: false

  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", true) === true
  readonly property int lowBatteryPercent: parseInt(setting("lowPercent", 20), 10) || 20
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color barIconColor: kb.connected ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property bool cursorActive: false

  readonly property string heroMeta: kb.connected
    ? (kb.hasLevels ? "Connected" : (kb.lastError !== "" ? kb.lastError : "Reading battery…"))
    : (kb.known ? "Not connected" : "Not paired")

  visible: !hideWhenDisconnected || kb.connected
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    kb.checkStudio()
    kb.refresh()
    agoTick.restart()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: kb
    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { kb.refresh(); return "ok" }
    function studio(): string { return kb.openStudio() ? "ok" : "zmk-studio not installed" }
    function status(): string {
      if (!kb.connected) return kb.deviceName + ": not connected"
      var parts = []
      for (var i = 0; i < kb.levels.length; i++)
        parts.push(Model.halfLabel(i, kb.levels.length, kb.centralSide).toLowerCase() + " " + Model.levelText(kb.levels[i]))
      return kb.deviceName + ": " + (parts.length ? parts.join(", ") : "no battery data")
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        SplitKeyboardIcon {
          anchors.centerIn: parent
          // Two halves side by side are wide for their height, so a size above the stock 12 keeps them legible.
          iconSize: Style.space(14)
          color: root.barIconColor
        }
      }
    }
    tooltipText: kb.connected ? kb.deviceName : kb.deviceName + " (not connected)"
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) kb.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(420))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) { root.cursorActive = true }
      onActivateRequested: if (root.cursorActive) kb.openStudio()
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        var key = String(t).toLowerCase()
        if (key === "r") kb.refresh()
        else if (key === "s") kb.openStudio()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: kb.deviceName
            meta: root.heroMeta
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: kb.connected ? 1.0 : 0.5
            iconComponent: Component {
              SplitKeyboardIcon {
                iconSize: Style.font.displayLarge
                color: kb.connected ? root.foreground : root.dim
              }
            }
          }

          Column {
            visible: kb.connected && kb.hasLevels
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "BATTERY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: kb.levels
                HalfRow {
                  required property int index
                  required property var modelData
                  width: parent.width
                  label: Model.halfLabel(index, kb.levels.length, kb.centralSide)
                  level: modelData
                  meta: Model.halfRole(index, kb.levels.length)
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: kb.busy ? "Refreshing…" : "Updated " + Model.agoText(kb.updatedAt).toLowerCase()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              rightPadding: Style.space(10)
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          ActionRow {
            width: parent.width
            label: "Open ZMK Studio"
            caption: kb.studioInstalled
              ? "Edit the keymap over USB"
              : "zmk-studio is not installed"
            iconText: ""
            enabled: kb.studioInstalled
            onActivated: kb.openStudio()
          }

          Text {
            textFormat: Text.PlainText
            visible: !kb.connected
            width: parent.width
            text: kb.known
              ? "Turn the keyboard on to see the battery of each half."
              : "Pair the keyboard over Bluetooth to see the battery of each half."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  // Keeps the "updated … ago" line honest while the panel is open.
  Timer {
    id: agoTick
    interval: 10000
    running: root.opened
    repeat: true
    onTriggered: kb.updatedAt = kb.updatedAt + 0
  }

  component HalfRow: Item {
    id: halfRow
    property string label: ""
    property int level: Model.LEVEL_UNKNOWN
    property string meta: ""

    readonly property bool low: level !== Model.LEVEL_UNKNOWN && level <= root.lowBatteryPercent

    implicitHeight: halfLayout.implicitHeight

    RowLayout {
      id: halfLayout
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: halfRow.label
        color: root.foreground
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Layout.preferredWidth: Math.max(Style.space(44), implicitWidth + Style.space(10))
      }

      Rectangle {
        id: meterTrack
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: Style.space(6)
        radius: height / 2
        color: Qt.darker(root.foreground, 3.2)

        Rectangle {
          width: meterTrack.width * Model.levelFraction(halfRow.level)
          height: parent.height
          radius: parent.radius
          color: halfRow.low ? root.urgent : root.foreground
          Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        }
      }

      Text {
        textFormat: Text.PlainText
        text: Model.levelText(halfRow.level)
        color: halfRow.low ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Style.space(38)
      }

      Text {
        textFormat: Text.PlainText
        text: halfRow.meta
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        // Wide enough for "peripheral"; the meter is the flexible column, not this one.
        Layout.preferredWidth: Style.space(72)
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property string label: ""
    property string caption: ""
    property string iconText: ""

    signal activated()

    hasCursor: root.cursorActive && enabled
    foreground: root.foreground
    opacity: enabled ? 1.0 : 0.45
    implicitHeight: actionContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      enabled: actionRow.enabled
      cursorShape: actionRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: root.cursorActive = true
      onExited: root.cursorActive = false
      onClicked: actionRow.activated()
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      ColumnLayout {
        id: actionContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: actionRow.label
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: actionRow.caption
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        textFormat: Text.PlainText
        Layout.alignment: Qt.AlignVCenter
        text: actionRow.iconText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }
    }
  }
}
