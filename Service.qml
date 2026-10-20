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
      }
    }
  }

  // A shell restart may have missed a config reload, so start from a full apply.
  Component.onCompleted: {
    root.displaysChanged = true
    root.reloaded = true
    reconcile()
  }
}
