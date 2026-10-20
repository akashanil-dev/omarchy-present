import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Watches displays come and go. A display seen before gets its saved mode back
// silently; a new one starts in Duplicate and opens the picker, like Windows.
// Present's display rules live only at runtime, so they are applied again after
// every Hyprland config reload.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) || "io.github.akashanil-dev.present"
  readonly property string cli: String(Qt.resolvedUrl("bin/present")).replace(/^file:\/\//, "")

  property bool reloaded: false
  property bool displaysChanged: false

  // What bin/present asks to draw: the card in Laptop screen only, and the
  // black layer that dims a display without DDC/CI brightness.
  property string cardOutput: ""
  property string dimOutput: ""
  property real dimLevel: 0
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/" + pluginId

  // Displays need a moment to settle; a config reload only needs Present's
  // runtime rules back quickly, before anyone notices them gone.
  function reconcile() {
    settle.interval = root.displaysChanged ? 1200 : 200
    settle.restart()
  }

  function openPicker() {
    if (root.shell && typeof root.shell.summon === "function")
      root.shell.summon(root.pluginId, JSON.stringify({ reason: "connected" }))
  }

  // Hotplug and reload events come in bursts, and our own changes add more. Act
  // once things settle; the script is idempotent, so a late extra run changes
  // nothing.
  Timer {
    id: settle
    interval: 1200
    onTriggered: {
      if (hotplug.running) {
        settle.restart()
        return
      }
      hotplug.command = root.reloaded ? [root.cli, "hotplug", "--force"] : [root.cli, "hotplug"]
      root.reloaded = false
      root.displaysChanged = false
      hotplug.running = true
    }
  }

  Process {
    id: fit
    command: [root.cli, "fit"]
  }

  Process {
    id: hotplug
    stdout: StdioCollector {
      onStreamFinished: if (text.trim() === "new") root.openPicker()
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") {
        root.reloaded = true
        root.reconcile()
      } else if (event.name === "monitoraddedv2" || event.name === "monitorremovedv2") {
        root.displaysChanged = true
        root.reconcile()
      } else if (event.name === "fullscreen" && event.data === "1" && !fit.running) {
        // Match the TV keeps fullscreen windows inside the mirrored area; the
        // script returns at once in every other mode.
        fit.running = true
      }
    }
  }

  FileView {
    id: overlayState
    path: root.runtimeDir + "/overlay.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var state = {}
      try { state = JSON.parse(text()) || {} } catch (e) {}
      root.cardOutput = state.card || ""
      root.dimOutput = state.dimOutput || ""
      root.dimLevel = Math.max(0, Math.min(0.8, Number(state.dim) || 0))
    }
    // Create it, so there is a file to watch before the first mode change.
    onLoadFailed: {
      root.cardOutput = ""
      root.dimOutput = ""
      root.dimLevel = 0
      setText(JSON.stringify({ card: "", dimOutput: "", dim: 0 }) + "\n")
    }
    onFileChanged: reload()
  }

  // Dimming: black at the chosen opacity over everything on that display,
  // letting every click through.
  Variants {
    model: root.dimOutput === "" || root.dimLevel <= 0 ? []
      : Quickshell.screens.filter(function(s) { return s.name === root.dimOutput })

    PanelWindow {
      required property var modelData
      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omarchy-present-dim"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}
      color: Qt.rgba(0, 0, 0, root.dimLevel)
    }
  }

  Card {
    output: root.cardOutput
    pluginId: root.pluginId
  }

  // A shell restart may have missed a config reload, so start from a full apply.
  Component.onCompleted: {
    root.displaysChanged = true
    root.reloaded = true
    reconcile()
  }
}
