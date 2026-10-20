import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// The card Laptop screen only shows on the projector: an optional line for the
// room ("Back at 3:15"), your name and site, a QR code to it, and the time. The
// projector stays driven underneath, so TVs that drop off HDMI when their
// signal stops never do. Settings live in ~/.config/<plugin id>/card.json; with
// none, the card is just a clock.
Item {
  id: root

  property string output: ""
  property string pluginId: "io.github.akashanil-dev.present"

  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/" + pluginId
  readonly property string qrPath: runtimeDir + "/qr.png"

  property var config: ({})
  readonly property string title: config.title || ""
  readonly property string name: config.name || ""
  readonly property string site: config.site || ""
  // The QR code opens `qr`, or the site when only that is set.
  readonly property string qrText: config.qr !== undefined ? String(config.qr)
    : (site === "" ? "" : (/^[a-z]+:\/\//i.test(site) ? site : "https://" + site))
  readonly property bool showClock: config.clock !== false
  property int qrVersion: 0
  property bool qrReady: false

  FileView {
    id: configFile
    path: root.configHome + "/" + root.pluginId + "/card.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.config = JSON.parse(text()) || {} } catch (e) { root.config = {} }
    }
    onLoadFailed: root.config = {}
    onFileChanged: reload()
  }

  onQrTextChanged: makeQr()
  onOutputChanged: if (output !== "") { configFile.reload(); makeQr() }

  function makeQr() {
    root.qrReady = false
    if (root.qrText === "" || root.output === "") return
    qrencode.running = false
    qrencode.command = ["qrencode", "-o", root.qrPath, "-s", "16", "-m", "0", "-l", "M", "--", root.qrText]
    qrencode.running = true
  }

  // Optional: without qrencode the card simply has no code.
  Process {
    id: qrencode
    onExited: function(code) {
      root.qrVersion++
      root.qrReady = code === 0
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Variants {
    model: root.output === "" ? [] : Quickshell.screens.filter(function(s) { return s.name === root.output })

    PanelWindow {
      id: card
      required property var modelData

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omarchy-present-card"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      color: Color.background

      // Everything is sized from the screen height, so it reads the same on a
      // 1080p projector and a 4K TV.
      readonly property real u: Math.max(1, height / 1080)
      readonly property string font: Style.font.menuFamily
      readonly property bool hasIdentity: root.name !== "" || root.site !== "" || root.title !== ""

      // Drift a little every minute so nothing burns into a TV left on all day.
      property real driftX: 0
      property real driftY: 0
      Behavior on driftX { NumberAnimation { duration: 6000; easing.type: Easing.InOutSine } }
      Behavior on driftY { NumberAnimation { duration: 6000; easing.type: Easing.InOutSine } }
      Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
          card.driftX = (Math.random() * 2 - 1) * 24 * card.u
          card.driftY = (Math.random() * 2 - 1) * 16 * card.u
        }
      }

      Item {
        id: stage
        anchors.fill: parent
        anchors.margins: 96 * card.u
        transform: Translate { x: card.driftX; y: card.driftY }

        // Who you are, left of centre.
        Column {
          visible: card.hasIdentity
          anchors.left: parent.left
          anchors.leftMargin: 48 * card.u
          anchors.right: qrTile.visible ? qrTile.left : parent.right
          anchors.rightMargin: 96 * card.u
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -40 * card.u
          spacing: 20 * card.u

          Text {
            visible: root.title !== ""
            width: parent.width
            text: root.title
            color: Color.accent
            font.family: card.font
            font.pixelSize: 48 * card.u
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
          }

          Rectangle {
            visible: root.title !== ""
            width: 96 * card.u
            height: 4 * card.u
            radius: height / 2
            color: Color.accent
            opacity: 0.6
          }

          Text {
            visible: root.name !== ""
            width: parent.width
            text: root.name
            color: Color.foreground
            font.family: card.font
            font.pixelSize: 150 * card.u
            font.weight: Font.Bold
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 72 * card.u
          }

          Text {
            visible: root.site !== ""
            width: parent.width
            text: root.site
            color: Color.foreground
            opacity: 0.65
            font.family: card.font
            font.pixelSize: 52 * card.u
            elide: Text.ElideRight
          }
        }

        // A QR code to the site. Dark on light whatever the theme, so every
        // phone camera reads it.
        Column {
          id: qrTile
          visible: card.hasIdentity && root.qrReady
          anchors.right: parent.right
          anchors.rightMargin: 48 * card.u
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -40 * card.u
          spacing: 24 * card.u

          Rectangle {
            width: 380 * card.u
            height: width
            radius: 28 * card.u
            color: "#ffffff"

            Image {
              anchors.fill: parent
              anchors.margins: 32 * card.u
              source: root.qrReady ? "file://" + root.qrPath + "?" + root.qrVersion : ""
              smooth: false
              cache: false
              fillMode: Image.PreserveAspectFit
            }
          }

          Text {
            width: 380 * card.u
            horizontalAlignment: Text.AlignHCenter
            text: "Scan to open"
            color: Color.foreground
            opacity: 0.55
            font.family: card.font
            font.pixelSize: 28 * card.u
          }
        }

        // The time: in the corner beside your details, or the whole card when
        // nothing else is set.
        Item {
          id: clockBlock
          visible: root.showClock || !card.hasIdentity
          width: date.x + date.width
          height: time.height
          x: card.hasIdentity ? 48 * card.u : (stage.width - width) / 2
          y: card.hasIdentity ? stage.height - height : (stage.height - height) / 2

          // 12- or 24-hour, as the locale says; AM/PM set smaller after the time.
          readonly property bool twelveHour: /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat))

          Text {
            id: time
            text: Qt.formatTime(clock.date, clockBlock.twelveHour ? "h:mm" : "HH:mm")
            color: Color.foreground
            font.family: card.font
            font.pixelSize: (card.hasIdentity ? 88 : 220) * card.u
            font.weight: Font.Light
          }

          Text {
            id: meridiem
            visible: clockBlock.twelveHour
            anchors.left: time.right
            anchors.leftMargin: 12 * card.u
            anchors.baseline: time.baseline
            text: clock.date.getHours() < 12 ? "AM" : "PM"
            color: Color.foreground
            font.family: card.font
            font.pixelSize: (card.hasIdentity ? 36 : 80) * card.u
          }

          Text {
            id: date
            anchors.left: meridiem.visible ? meridiem.right : time.right
            anchors.leftMargin: 32 * card.u
            anchors.baseline: time.baseline
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            color: Color.foreground
            opacity: 0.55
            font.family: card.font
            font.pixelSize: (card.hasIdentity ? 32 : 56) * card.u
          }
        }
      }
    }
  }
}
