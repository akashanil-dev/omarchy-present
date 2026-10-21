import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// The SUPER + P picker: Laptop screen only, Duplicate, Extend, Second screen
// only, like Windows' Win+P. Arrows or 1-4 choose, Enter applies, P cycles.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) || "io.github.akashanil-dev.present"
  readonly property string cli: String(Qt.resolvedUrl("bin/present")).replace(/^file:\/\//, "")

  // The picker belongs on the laptop screen: SUPER + P should open where you
  // are looking, not on the TV you are about to configure. With the laptop
  // panel off (Second screen only) it falls back to whatever screen is left.
  readonly property var pickerScreen: {
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++)
      if (/^(eDP|LVDS|DSI)-/.test(screens[i].name)) return screens[i]
    return screens.length > 0 ? screens[0] : null
  }

  property bool opened: false
  property var status: ({ connected: false })
  property int selectedIndex: 1

  readonly property var modes: [
    { id: "internal", title: "Laptop screen only", hint: "Name card on the projector" },
    { id: "duplicate", title: "Duplicate", hint: "Same picture, no stretching" },
    { id: "extend", title: "Extend", hint: "Second desktop" },
    { id: "external", title: "Second screen only", hint: "Laptop screen off" },
    { id: "match", title: "Match the TV", hint: "Duplicate, no bars" }
  ]

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color accent: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int pad: Style.spacing.panelPadding
  // Wide enough for the longest label in any font or text size.
  property int tileWidth: Math.max(Style.space(150), Math.ceil(longestLabel.width) + Style.spacing.xxl * 2)
  property int tileHeight: Style.space(132)

  TextMetrics {
    id: longestLabel
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
    text: "4  Second screen only"
  }

  function open(payloadJson) {
    root.opened = true
    root.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function indexOfMode(id) {
    for (var i = 0; i < modes.length; i++) if (modes[i].id === id) return i
    return 1
  }

  function select(delta) {
    selectedIndex = (selectedIndex + delta + modes.length) % modes.length
  }

  function rateLabel(rate) {
    var n = Math.round(Number(rate) * 100) / 100
    return n + " Hz"
  }

  function sameRate(a, b) {
    return Math.abs(Number(a) - Number(b)) < 0.6
  }

  function run(args) {
    Quickshell.execDetached([root.cli].concat(args))
  }

  function apply(index) {
    if (!status.connected) return
    var mode = modes[index].id
    if ((mode === "duplicate" || mode === "match") && !status.mirrorAvailable) return
    // Launch first: dismiss() makes the shell unload this overlay, and nothing
    // on it can run afterwards.
    root.run(["set", mode])
    root.dismiss()
  }

  // Position and size apply right away and keep the picker open.
  function adjust(args) {
    if (!status.connected) return
    actionProc.command = [root.cli].concat(args)
    actionProc.running = true
  }

  Process {
    id: statusProc
    command: [root.cli, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.status = JSON.parse(text)
          root.selectedIndex = root.indexOfMode(root.status.display || "duplicate")
        } catch (e) {
          root.status = { connected: false }
        }
      }
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: root.pickerScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-present"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: content.implicitWidth + root.pad * 2
      height: content.implicitHeight + root.pad * 2
      radius: root.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: root.pad

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var k = event.key
          if (k === Qt.Key_Escape) root.dismiss()
          else if (k === Qt.Key_Left || k === Qt.Key_H) root.select(-1)
          else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_P || k === Qt.Key_Tab) root.select(1)
          else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.apply(root.selectedIndex)
          else if (k >= Qt.Key_1 && k <= Qt.Key_5) root.apply(k - Qt.Key_1)
          else if (k === Qt.Key_Equal || k === Qt.Key_Plus) root.adjust(["scale", "up"])
          else if (k === Qt.Key_Minus) root.adjust(["scale", "down"])
          else if (k === Qt.Key_0) root.adjust(["scale", "reset"])
          else if (k === Qt.Key_BracketRight) root.adjust(["fps", "up"])
          else if (k === Qt.Key_BracketLeft) root.adjust(["fps", "down"])
          else return
          event.accepted = true
        }
      }

      Column {
        id: content
        x: card.contentLeftInset
        y: card.contentTopInset
        spacing: Style.spacing.xxl

        Column {
          spacing: Style.spacing.xs
          Text {
            textFormat: Text.PlainText
            text: "Present the Screen"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: !root.status.connected ? "No external display connected"
              : (root.status.displayName || root.status.label) + "  ·  " + root.status.resolution
                + "  ·  " + root.rateLabel(root.status.fps || 0)
                + (root.status.display === "ignore" ? "  ·  left to your Hyprland config" : "")
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Row {
          spacing: Style.spacing.lg

          Repeater {
            model: root.modes

            delegate: Rectangle {
              id: tile
              required property var modelData
              required property int index
              readonly property bool current: root.status.connected && root.status.display === modelData.id
              readonly property bool unavailable: !root.status.connected
                || ((modelData.id === "duplicate" || modelData.id === "match") && !root.status.mirrorAvailable)

              width: root.tileWidth
              height: root.tileHeight
              radius: root.cornerRadius
              color: index === root.selectedIndex ? root.selectedBackground : "transparent"
              border.width: Math.max(1, Style.space(1))
              border.color: index === root.selectedIndex ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
              opacity: unavailable ? 0.4 : 1

              ScreenDiagram {
                id: diagram
                mode: tile.modelData.id
                ink: tile.index === root.selectedIndex ? root.accent : root.foreground
                anchors.horizontalCenter: parent.horizontalCenter
                y: Style.spacing.xxl
              }

              Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: diagram.bottom
                anchors.topMargin: Style.spacing.lg
                spacing: Style.spacing.xxs

                Text {
                  textFormat: Text.PlainText
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: (tile.index + 1) + "  " + tile.modelData.title
                  color: tile.index === root.selectedIndex ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: tile.current
                }
                Text {
                  textFormat: Text.PlainText
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: (tile.modelData.id === "duplicate" || tile.modelData.id === "match") && !root.status.mirrorAvailable
                    ? "Needs wl-mirror" : (tile.current ? "Current" : tile.modelData.hint)
                  color: root.foreground
                  opacity: 0.55
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: tile.unavailable ? Qt.ArrowCursor : Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.selectedIndex = tile.index
                onClicked: root.apply(tile.index)
              }
            }
          }
        }

        // The external display itself: refresh rate, text size, and where an
        // extended desktop sits. Refresh rate and size apply at once and keep
        // the picker open.
        Column {
          visible: root.status.connected
          spacing: Style.spacing.md

          Row {
            spacing: Style.spacing.sm
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "Refresh rate"
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Repeater {
              model: root.status.fpsRates || []
              delegate: Chip {
                required property var modelData
                label: root.rateLabel(modelData)
                active: root.sameRate(modelData, root.status.fps)
                onClicked: root.adjust(["fps", "set", String(modelData)])
              }
            }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              visible: (root.status.fpsRates || []).length < 2
              text: "The only rate at this resolution"
              color: root.foreground
              opacity: 0.45
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            spacing: Style.spacing.sm
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "Text size " + Math.round((root.status.scale || 1) * 100) + "%"
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Chip { label: "Bigger"; onClicked: root.adjust(["scale", "up"]) }
            Chip { label: "Smaller"; onClicked: root.adjust(["scale", "down"]) }
            Chip { label: "Auto"; onClicked: root.adjust(["scale", "reset"]) }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "Applies to Extend and Second screen only"
              color: root.foreground
              opacity: 0.45
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            spacing: Style.spacing.xxl

            Row {
              spacing: Style.spacing.sm
              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: "Extend to"
                color: root.foreground
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Repeater {
                model: [
                  { id: "left", label: "Left" },
                  { id: "up", label: "Above" },
                  { id: "right", label: "Right" },
                  { id: "down", label: "Below" }
                ]
                delegate: Chip {
                  required property var modelData
                  label: modelData.label
                  active: root.status.position === modelData.id
                  onClicked: root.adjust(["position", modelData.id])
                }
              }
            }

            // For a desk monitor already set up in your own monitors.lua.
            Chip {
              label: "Don't manage"
              active: root.status.display === "ignore"
              onClicked: {
                root.run(["set", "ignore"])
                root.dismiss()
              }
            }
          }
        }

        // Sound: every output that isn't known to be unplugged; the active one
        // is highlighted. Brightness: the display's own when it takes DDC/CI,
        // otherwise a dimming layer, and the picker says which.
        Column {
          visible: root.status.connected
          spacing: Style.spacing.md

          Row {
            spacing: Style.spacing.sm
            visible: (root.status.audio || []).length > 0
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "Sound"
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Repeater {
              model: root.status.audio || []
              delegate: Chip {
                required property var modelData
                label: modelData.label
                active: modelData.active === true
                onClicked: root.adjust(["audio", "set", modelData.id])
              }
            }
          }

          Row {
            spacing: Style.spacing.sm
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "Brightness " + (root.status.brightness || 100) + "%"
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Chip { label: "Dimmer"; onClicked: root.adjust(["brightness", "down"]) }
            Chip { label: "Brighter"; onClicked: root.adjust(["brightness", "up"]) }
            Chip { label: "Full"; onClicked: root.adjust(["brightness", "reset"]) }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              visible: text !== ""
              text: root.status.brightnessMethod === "ddc" ? "Set on the display itself"
                : root.status.brightnessMethod !== "dim" ? ""
                : root.status.ddcutil ? "This display doesn't accept brightness commands, so the picture is dimmed instead"
                : "Dimming the picture. Install ddcutil to control a monitor's own brightness"
              color: root.foreground
              opacity: 0.45
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          text: "←/→ or P to choose   Enter to apply   1–5 apply directly   [ ] refresh rate   +/− text size   Esc to close"
          color: root.foreground
          opacity: 0.4
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  component Chip: Rectangle {
    id: chip
    property string label: ""
    property bool active: false
    signal clicked()

    width: chipText.implicitWidth + Style.spacing.controlPaddingX * 2
    height: chipText.implicitHeight + Style.spacing.controlPaddingY * 2
    radius: root.cornerRadius
    color: active || chipMouse.containsMouse ? root.selectedBackground : "transparent"
    border.width: Math.max(1, Style.space(1))
    border.color: active ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

    Text {
      textFormat: Text.PlainText
      id: chipText
      anchors.centerIn: parent
      text: chip.label
      color: chip.active ? root.accent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  // Two little screens, filled when on: 1 = laptop, 2 = external.
  component ScreenDiagram: Item {
    id: diagramRoot
    property string mode: "duplicate"
    property color ink: "white"
    readonly property int screenW: Style.space(40)
    readonly property int screenH: Style.space(28)

    width: screenW * 2 + Style.spacing.md
    height: screenH

    Repeater {
      model: 2
      delegate: Rectangle {
        required property int index
        readonly property bool on: diagramRoot.mode === "duplicate" || diagramRoot.mode === "match" || diagramRoot.mode === "extend"
          || (diagramRoot.mode === "internal" && index === 0)
          || (diagramRoot.mode === "external" && index === 1)
        x: index * (diagramRoot.screenW + Style.spacing.md)
        width: diagramRoot.screenW
        height: diagramRoot.screenH
        radius: Math.max(1, Style.space(2))
        color: on ? Qt.rgba(diagramRoot.ink.r, diagramRoot.ink.g, diagramRoot.ink.b, 0.85) : "transparent"
        border.width: Math.max(1, Style.space(1))
        border.color: Qt.rgba(diagramRoot.ink.r, diagramRoot.ink.g, diagramRoot.ink.b, on ? 0.85 : 0.35)

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: parent.on
          text: diagramRoot.mode === "duplicate" || diagramRoot.mode === "match" ? "1" : String(index + 1)
          color: root.background
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
      }
    }
  }
}
