import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

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

  // The output showing the card in Laptop screen only; bin/present writes it.
  property string cardOutput: ""
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
    id: cardState
    path: root.runtimeDir + "/card.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.cardOutput = JSON.parse(text()).output || "" } catch (e) { root.cardOutput = "" }
    }
    // Create it, so there is a file to watch before the first mode change.
    onLoadFailed: {
      root.cardOutput = ""
      setText(JSON.stringify({ output: "" }) + "\n")
    }
    onFileChanged: reload()
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
