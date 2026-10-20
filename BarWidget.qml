import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Present the Screen in the bar: shows the current mode while an external
// display is connected. Click opens the picker; scrolling changes the
// display's brightness.
BarWidget {
  id: root
  moduleName: "io.github.akashanil-dev.present"

  readonly property string pluginId: "io.github.akashanil-dev.present"
  readonly property string cli: String(Qt.resolvedUrl("bin/present")).replace(/^file:\/\//, "")
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/" + pluginId
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/" + pluginId

  property var status: ({ connected: false })

  readonly property var modeNames: ({
    internal: "Laptop screen only",
    duplicate: "Duplicate",
    match: "Match the TV",
    extend: "Extend",
    external: "Second screen only",
    ignore: "Not managed"
  })

  readonly property string icon: {
    switch (status.display) {
      case "internal": return "󰌢"
      case "external": return "󰍹"
      case "ignore": return "󰍹"
      default: return "󰍺"
    }
  }

  readonly property string activeSound: {
    var outputs = status.audio || []
    for (var i = 0; i < outputs.length; i++) if (outputs[i].active) return outputs[i].label
    return ""
  }

  function refresh() {
    if (statusProc.running) refreshAgain.restart()
    else statusProc.running = true
  }

  function openPicker() {
    if (root.bar && root.bar.shell && typeof root.bar.shell.summon === "function")
      root.bar.shell.summon(root.pluginId, JSON.stringify({ reason: "bar" }))
  }

  visible: status.connected === true
  implicitWidth: visible ? (vertical ? barSize : button.implicitWidth) : 0
  implicitHeight: visible ? button.implicitHeight : 0

  Process {
    id: statusProc
    command: [root.cli, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.status = JSON.parse(text) } catch (e) { root.status = { connected: false } }
      }
    }
  }

  // A change while a status read is running gets one more read after it.
  Timer {
    id: refreshAgain
    interval: 300
    onTriggered: root.refresh()
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  // Modes, brightness and sound choices land in these files.
  FileView {
    path: root.stateDir + "/displays.json"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }
  FileView {
    path: root.runtimeDir + "/overlay.json"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "monitoraddedv2" || event.name === "monitorremovedv2" || event.name === "configreloaded")
        refreshAgain.restart()
    }
  }

  // Sound can change outside Present (a headset connecting), so look again now
  // and then while there is something to show.
  Timer {
    interval: 15000
    running: root.status.connected === true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    dimmed: root.status.display === "ignore"
    tooltipText: !root.status.connected ? "Present the Screen"
      : "Present the Screen · " + (root.modeNames[root.status.display] || "Duplicate")
        + "\n" + root.status.label
        + (root.activeSound !== "" ? "\nSound: " + root.activeSound : "")
        + "\nBrightness " + (root.status.brightness || 100) + "%"
        + (root.status.brightnessMethod === "dim" ? " (dimmed)" : "")
        + "\nClick to change · scroll for brightness"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.openPicker()
    }
    onWheelMoved: function(delta) {
      if (actionProc.running) return
      actionProc.command = [root.cli, "brightness", delta > 0 ? "up" : "down"]
      actionProc.running = true
    }
  }
}
