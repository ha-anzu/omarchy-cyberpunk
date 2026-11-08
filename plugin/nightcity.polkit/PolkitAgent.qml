import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PolkitModel.js" as PolkitModel

Item {
  id: root

  property string fontFamily: Style.font.menuFamily
  // Bound to the central [polkit] section in shell.toml via Commons.Color.qml.
  property color accent: Commons.Color.polkit.accent
  property color background: Commons.Color.polkit.background
  property color foreground: Commons.Color.polkit.text
  property color border: Commons.Color.polkit.border
  property color borderError: Commons.Color.polkit.borderError
  property var borderSpec: Border.surfaceSpec("polkit", errorFlash ? "border-error" : "border", errorFlash ? borderError : border, Math.max(1, Style.space(2)), "border-alpha")
  property color scrim: Commons.Color.polkit.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int fieldHeight: Math.max(Style.space(42), Style.spacing.controlHeight)

  property bool closing: false
  property bool submitted: false
  property string currentMessage: ""
  property string currentPrompt: ""
  property string currentSupplementary: ""
  property bool responseRequired: false
  property bool responseVisible: false
  property bool failed: false
  property bool errorFlash: false
  // pam_fprintd appears in the polkit PAM stack (a sensor is enrolled).
  property bool fingerprintConfigured: false
  // Lid shut right now — the reader is physically unreachable, so we fall back
  // to the password even when a sensor is enrolled. Refreshed per request.
  property bool laptopClosed: false
  property int shakeOffset: 0
  property int frameStep: 0
  readonly property int fingerSide: 168
  readonly property color readerInk: "#FCEE0A"
  readonly property color readerTick: "#00F0FF"

  readonly property bool dialogVisible: polkitAgent.isActive || closing
  // We show one method at a time. Fingerprint owns the dialog while PAM is
  // waiting on the reader (lid open, sensor enrolled); the moment PAM asks for
  // a password — including immediately when the lid is shut and the clamshell
  // gate skips pam_fprintd — we switch to the password field instead.
  readonly property bool fingerprintMode: fingerprintConfigured && !laptopClosed && dialogVisible && !responseRequired && !submitted && !errorFlash
  readonly property int cardHeight: fingerprintMode ? fingerSide : (panel.height > 0 ? Math.min(fieldHeight + contentMargin * 2, panel.height - Style.gapsOut * 2) : fieldHeight + contentMargin * 2)
  // Password mode stays a wide field. Fingerprint mode is a square plate with
  // the same broken yellow stroke as the lock screen.
  readonly property int cardWidth: fingerprintMode ? fingerSide : Math.min(Style.space(312), Math.max(Style.space(260), panel.width - Style.gapsOut * 2))

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  Timer {
    interval: 1100
    repeat: true
    running: root.fingerprintMode && Style.duration(1) > 0
    onTriggered: root.frameStep = (root.frameStep + 1) % 8
  }

  function authorizationLabel(message) {
    return message ? PolkitModel.authorizationLabel(message, I18n.t) : I18n.t("polkit.authenticationNeeded")
  }

  function mix(seed, salt) {
    var n = (seed ^ Math.imul(salt + 1, 0x9e3779b1)) >>> 0
    n = Math.imul(n, 0x85ebca6b) >>> 0
    n = (n ^ (n >>> 13)) >>> 0
    return (n % 10000) / 10000
  }

  function drawRun(ctx, x0, y0, x1, y1, seed, salt, slide) {
    var dx = x1 - x0
    var dy = y1 - y0
    var len = Math.abs(dx) + Math.abs(dy)
    if (len < 10) return
    var horizontal = Math.abs(dx) >= Math.abs(dy)
    var leadA = 2 + Math.round(root.mix(seed, salt) * 6)
    var leadB = 2 + Math.round(root.mix(seed, salt + 1) * 7)
    var span = len - leadA - leadB
    if (span < 8) return
    var gap = Math.round(12 + root.mix(seed, salt + 2) * 22)
    if (gap > span * 0.5) gap = Math.round(span * 0.38)
    var center = leadA + span * (0.22 + root.mix(seed, salt + 3) * 0.52) + slide
    var g0 = center - gap / 2
    var g1 = center + gap / 2
    var shiftA = root.mix(seed, salt + 4) > 0.45 ? 1 : 0
    var shiftB = 1 + (root.mix(seed, salt + 5) > 0.55 ? 1 : 0)
    if ((root.frameStep + salt) % 8 === 2) shiftA = shiftA === 0 ? 1 : 0
    var nx = horizontal ? 0 : (dy >= 0 ? -1 : 1)
    var ny = horizontal ? (dx >= 0 ? 1 : -1) : 0
    function point(distance, shift) {
      var t = distance / len
      return Qt.point(x0 + dx * t + nx * shift, y0 + dy * t + ny * shift)
    }
    var a = point(leadA, shiftA)
    var b = point(Math.max(leadA + 2, Math.min(g0, len - leadB)), shiftA)
    var c = point(Math.min(len - leadB, Math.max(g1, leadA)), shiftB)
    var d = point(len - leadB, shiftB)
    ctx.moveTo(a.x, a.y)
    ctx.lineTo(b.x, b.y)
    ctx.moveTo(c.x, c.y)
    ctx.lineTo(d.x, d.y)
  }

  function drawChamfer(ctx, x0, y0, x1, y1, seed, salt) {
    var dx = x1 - x0
    var dy = y1 - y0
    var broken = root.mix(seed, salt) > 0.62
    ctx.moveTo(x0, y0)
    if (!broken) {
      ctx.lineTo(x1, y1)
      return
    }
    ctx.lineTo(x0 + dx * 0.42, y0 + dy * 0.42)
    ctx.moveTo(x0 + dx * 0.68, y0 + dy * 0.68)
    ctx.lineTo(x1, y1)
  }

  function cutsFor(seed, w, h) {
    var maxCut = Math.max(4, Math.min(w, h) * 0.22)
    return [
      Math.min(maxCut, 5 + Math.round(root.mix(seed, 1) * 14)),
      Math.min(maxCut, 3 + Math.round(root.mix(seed, 2) * 11)),
      Math.min(maxCut, 7 + Math.round(root.mix(seed, 3) * 13)),
      Math.min(maxCut, 4 + Math.round(root.mix(seed, 4) * 16))
    ]
  }

  function strokeFrame(ctx, x, y, w, h, seed, stroke, tick) {
    var cuts = root.cutsFor(seed, w, h)
    var slide = (root.frameStep - 3.5) * 1.4
    ctx.beginPath()
    ctx.lineWidth = 1
    ctx.strokeStyle = stroke
    root.drawRun(ctx, x + cuts[0], y, x + w - cuts[1], y, seed, 10, slide)
    root.drawRun(ctx, x + w, y + cuts[1], x + w, y + h - cuts[2], seed, 20, -slide)
    root.drawRun(ctx, x + w - cuts[2], y + h, x + cuts[3], y + h, seed, 30, slide * 0.6)
    root.drawRun(ctx, x, y + h - cuts[3], x, y + cuts[0], seed, 40, -slide * 0.4)
    root.drawChamfer(ctx, x + cuts[0], y, x, y + cuts[0], seed, 51)
    root.drawChamfer(ctx, x + w - cuts[1], y, x + w, y + cuts[1], seed, 52)
    root.drawChamfer(ctx, x + w, y + h - cuts[2], x + w - cuts[2], y + h, seed, 53)
    root.drawChamfer(ctx, x, y + h - cuts[3], x + cuts[3], y + h, seed, 54)
    ctx.stroke()

    var longest = 0
    for (var c = 1; c < 4; c++) if (cuts[c] > cuts[longest]) longest = c
    ctx.beginPath()
    ctx.lineWidth = 1
    ctx.strokeStyle = tick
    if (longest === 0) ctx.moveTo(x + 4, y + cuts[0] + 3), ctx.lineTo(x + 4, y + cuts[0] + 14)
    else if (longest === 1) ctx.moveTo(x + w - 4, y + cuts[1] + 3), ctx.lineTo(x + w - 4, y + cuts[1] + 14)
    else if (longest === 2) ctx.moveTo(x + w - cuts[2] - 14, y + h - 4), ctx.lineTo(x + w - cuts[2] - 3, y + h - 4)
    else ctx.moveTo(x + cuts[3] + 3, y + h - 4), ctx.lineTo(x + cuts[3] + 15, y + h - 4)
    ctx.stroke()
  }

  function loadPamConfig(raw) {
    fingerprintConfigured = PolkitModel.fingerprintConfiguredFromPamConfig(raw)
  }

  function refreshLidState() {
    if (!laptopClosedProc.running) laptopClosedProc.running = true
  }

  function resetSnapshot() {
    currentMessage = ""
    currentPrompt = ""
    currentSupplementary = ""
    responseRequired = false
    responseVisible = false
    failed = false
    errorFlash = false
    submitted = false
    passwordInput.text = ""
  }

  function syncFromFlow() {
    var flow = polkitAgent.flow
    if (!flow) return

    currentMessage = String(flow.message || "")
    currentPrompt = String(flow.inputPrompt || "")
    currentSupplementary = String(flow.supplementaryMessage || "")
    responseRequired = !!flow.isResponseRequired
    responseVisible = !!flow.responseVisible
    failed = !!flow.failed

    if (responseRequired) submitted = false
  }

  function beginFlow() {
    closeTimer.stop()
    closing = false
    submitted = false
    passwordInput.text = ""
    refreshLidState()
    syncFromFlow()
    Qt.callLater(refocus)
  }

  function refocus() {
    if (!dialogVisible) return
    // In fingerprint mode there is no field to type into — park focus on the
    // key catcher so Escape still cancels; otherwise focus the password field.
    if (fingerprintMode) keyCatcher.forceActiveFocus()
    else passwordInput.forceActiveFocus()
  }

  function submitResponse() {
    var flow = polkitAgent.flow
    if (!flow || !flow.isResponseRequired) return
    submitted = true
    errorFlash = false
    flow.submit(passwordInput.text)
    passwordInput.text = ""
    keyCatcher.forceActiveFocus()
  }

  function cancelRequest() {
    var flow = polkitAgent.flow
    passwordInput.text = ""
    submitted = false
    closing = true
    closeTimer.restart()
    if (flow) flow.cancelAuthenticationRequest()
  }

  function triggerFailureFeedback() {
    submitted = false
    errorFlash = true
    passwordInput.text = ""
    errorTimer.restart()
    shakeAnimation.restart()
    Qt.callLater(refocus)
  }

  Timer {
    id: closeTimer
    interval: 300
    repeat: false
    onTriggered: {
      closing = false
      resetSnapshot()
    }
  }

  Timer {
    id: errorTimer
    interval: 1200
    repeat: false
    onTriggered: root.errorFlash = false
  }

  SequentialAnimation {
    id: shakeAnimation
    NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: Style.duration(35); easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 8; duration: Style.duration(50); easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: Style.duration(55); easing.type: Easing.OutQuad }
  }
  FileView {
    path: "/etc/pam.d/polkit-1"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadPamConfig(text())
    onLoadFailed: root.fingerprintConfigured = false
    onFileChanged: reload()
  }

  Process {
    id: laptopClosedProc
    command: ["bash", "-c", "omarchy-hw-laptop-closed && echo closed || echo open"]
    stdout: StdioCollector { id: laptopClosedOut; waitForEnd: true }
    onExited: root.laptopClosed = String(laptopClosedOut.text || "").trim() === "closed"
  }

  PolkitAgent {
    id: polkitAgent
    path: "/org/omarchy/PolkitAgent"

    onAuthenticationRequestStarted: root.beginFlow()
    onIsActiveChanged: {
      if (isActive) root.syncFromFlow()
      else if (!root.closing) root.resetSnapshot()
    }
    onIsRegisteredChanged: {
      if (isRegistered) console.log("omarchy polkit agent registered")
      else console.warn("omarchy polkit agent is not registered; another agent may be running")
    }
  }

  Connections {
    target: polkitAgent.flow

    function onIsResponseRequiredChanged() {
      root.syncFromFlow()
      if (!polkitAgent.flow || !polkitAgent.flow.isResponseRequired) passwordInput.text = ""
      Qt.callLater(root.refocus)
    }

    function onInputPromptChanged() { root.syncFromFlow() }
    function onResponseVisibleChanged() { root.syncFromFlow() }
    function onSupplementaryMessageChanged() { root.syncFromFlow() }
    function onFailedChanged() { root.syncFromFlow() }

    function onAuthenticationFailed() {
      root.syncFromFlow()
      root.triggerFailureFeedback()
    }

    function onAuthenticationSucceeded() {
      root.closing = true
      closeTimer.restart()
    }

    function onAuthenticationRequestCancelled() {
      root.closing = true
      closeTimer.restart()
    }
  }

  PanelWindow {
    id: panel
    // Right-to-left languages read this window mirrored.
    Binding { target: panel.contentItem; property: "LayoutMirroring.enabled"; value: Commons.I18n.rightToLeft }
    Binding { target: panel.contentItem; property: "LayoutMirroring.childrenInherit"; value: true }

    visible: root.dialogVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.refocus()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.fingerprintMode ? 0 : root.cornerRadius
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: root.shakeOffset
      color: root.fingerprintMode ? "transparent" : root.background
      borderSpec: root.fingerprintMode ? Border.surfaceSpec("polkit", "border", "#00000000", 0, "border-alpha") : root.borderSpec
      padding: root.contentMargin

      Canvas {
        id: readerCanvas
        anchors.fill: parent
        visible: root.fingerprintMode
        antialiasing: true
        onPaint: {
          if (!root.fingerprintMode) return
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var pad = 8
          var x = pad
          var y = pad
          var w = width - pad * 2
          var h = height - pad * 2
          if (w < 20 || h < 20) return
          var cuts = root.cutsFor(19, w, h)
          ctx.beginPath()
          ctx.moveTo(x + cuts[0], y)
          ctx.lineTo(x + w - cuts[1], y)
          ctx.lineTo(x + w, y + cuts[1])
          ctx.lineTo(x + w, y + h - cuts[2])
          ctx.lineTo(x + w - cuts[2], y + h)
          ctx.lineTo(x + cuts[3], y + h)
          ctx.lineTo(x, y + h - cuts[3])
          ctx.lineTo(x, y + cuts[0])
          ctx.closePath()
          ctx.fillStyle = "rgba(8, 12, 18, 0.92)"
          ctx.fill()
          root.strokeFrame(ctx, x, y, w, h, 19, root.readerInk, root.readerTick)
        }
        Connections {
          target: root
          function onFrameStepChanged() { readerCanvas.requestPaint() }
          function onFingerprintModeChanged() { readerCanvas.requestPaint() }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
      }

      Text {
        visible: root.fingerprintMode
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 2
        text: strings.t("reader.touch")
        color: root.readerInk
        font.family: root.fontFamily
        font.pixelSize: 12
        font.letterSpacing: 3
      }

      MouseArea { anchors.fill: parent; onClicked: root.refocus() }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.cancelRequest()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.responseRequired) root.submitResponse()
            event.accepted = true
          }
        }
      }

      // Fingerprint mode shows just the sensor icon, centered and alone \u2014 no
      // padlock, no field, no prompt text.
      OpticalGlyph {
        anchors.centerIn: parent
        width: Math.round(root.fingerSide * 0.28)
        height: width
        visible: root.fingerprintMode
        text: "\udb80\ude37"
        fontFamily: root.fontFamily
        fontSize: Math.round(root.fingerSide * 0.28)
        color: root.readerInk
      }

      Row {
        id: cardRow
        visible: !root.fingerprintMode
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(14)

        Text {
          text: "\uf023"
          color: root.errorFlash ? Commons.Color.polkit.textError : root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.iconLarge
          width: Style.space(26)
          height: root.fieldHeight
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        Item {
          width: parent.width - Style.space(40)
          height: root.fieldHeight

          TextInput {
            id: passwordInput
            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            activeFocusOnPress: true
            clip: true
            selectionColor: Util.alpha(root.accent, 0.45)
            selectedTextColor: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.iconLarge
            echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "\u2022"
            color: root.errorFlash ? Commons.Color.polkit.textError : root.foreground
            cursorVisible: activeFocus && !root.submitted && !root.errorFlash
            readOnly: root.submitted || root.errorFlash
            enabled: root.dialogVisible
            onAccepted: root.submitResponse()
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.cancelRequest()
                event.accepted = true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.errorFlash ? I18n.t("polkit.wrong") : (root.submitted ? I18n.t("polkit.checking") : I18n.t("polkit.enterPassword"))
            color: root.errorFlash ? Commons.Color.polkit.textError : root.foreground
            opacity: root.errorFlash ? 1 : 0.36
            font.family: root.fontFamily
            font.pixelSize: Style.font.iconLarge
            elide: Text.ElideRight
            visible: passwordInput.text.length === 0
          }

          Rectangle {
            width: Math.max(1, Style.space(2))
            height: Style.space(24)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: root.errorFlash ? Commons.Color.polkit.textError : root.foreground
            visible: passwordInput.visible && passwordInput.activeFocus && passwordInput.text.length === 0 && !root.submitted && !root.errorFlash
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: passwordInput.visible
            onClicked: passwordInput.forceActiveFocus()
          }
        }
      }
    }

    Rectangle {
      width: Math.min(justificationText.implicitWidth + Style.space(24), panel.width - Style.gapsOut * 2)
      height: Style.space(28)
      anchors.horizontalCenter: card.horizontalCenter
      anchors.bottom: card.top
      anchors.bottomMargin: Style.space(10)
      radius: root.fingerprintMode ? 0 : root.cornerRadius
      color: root.fingerprintMode ? "transparent" : root.background

      Text {
        id: justificationText
        textFormat: Text.PlainText
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        text: root.authorizationLabel(root.currentMessage)
        color: root.fingerprintMode ? root.readerInk : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideMiddle
      }
    }
  }
}
