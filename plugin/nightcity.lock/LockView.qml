import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: Commons.I18n.t("lock.enterPassword")
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Commons.Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Commons.Color.lock.borderActive, root.outlineThickness, "border-alpha")

  // A video wallpaper shows its still poster: nothing plays behind the lock.
  readonly property bool video: Util.isVideoPath(root.backgroundPath)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // Same broken frame as the windows: 1px, a different cut on each corner,
  // a gap in every run, and the two halves stepped so they do not meet.
  property int frameStep: 0

  Timer {
    interval: 1100
    repeat: true
    running: Style.duration(1) > 0
    onTriggered: root.frameStep = (root.frameStep + 1) % 8
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
    ctx.strokeStyle = tick
    if (longest === 0) ctx.moveTo(x + 4, y + cuts[0] + 3), ctx.lineTo(x + 4, y + cuts[0] + 14)
    else if (longest === 1) ctx.moveTo(x + w - 4, y + cuts[1] + 3), ctx.lineTo(x + w - 4, y + cuts[1] + 14)
    else if (longest === 2) ctx.moveTo(x + w - cuts[2] - 14, y + h - 4), ctx.lineTo(x + w - cuts[2] - 3, y + h - 4)
    else ctx.moveTo(x + cuts[3] + 3, y + h - 4), ctx.lineTo(x + cuts[3] + 15, y + h - 4)
    ctx.stroke()
    return cuts
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  // Waking a DPMS-blanked display can stall the compositor for seconds while
  // the monitor modesets, so the wake key's release arrives late and client-side
  // key repeat floods the field with that character. A held key has no business
  // typing a password; only holding Backspace/Delete to clear stays useful.
  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  // The field loses focus while a password is checked (it is disabled then),
  // and forcing focus onto it would not stick until the check ends.
  function restorePasswordFocus() {
    if (inputEnabled && passwordInput.enabled && !passwordInput.activeFocus) forcePasswordFocus()
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // A VT switch, which the NVIDIA driver forces around every suspend, takes the
  // keyboard away and Qt drops the field's focus with it. Nothing gives it back
  // when the keyboard returns, so typing went nowhere until the field was clicked.
  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background

    BackgroundMedia {
      id: wallpaper
      objectName: "lockWallpaper"
      anchors.fill: parent
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
      // Decode only once sized, at the lock's own size: an unsized first
      // request decoded the file at its native resolution, then again once
      // sized. That size is what the lock service keeps decoded ahead of the
      // lock, so the first frame has the wallpaper.
      cached: true
      constrainDecode: true
      decodeSize: Qt.size(width, height)
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    Canvas {
      id: screenPlate
      anchors.fill: parent
      anchors.margins: 16
      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (width < 40 || height < 40) return
        root.strokeFrame(ctx, 1, 1, width - 2, height - 2, 4, "#FCEE0A", "#00F0FF")
      }
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      Connections {
        target: root
        function onFrameStepChanged() { screenPlate.requestPaint() }
      }
    }

    Row {
      id: cityMark
      anchors.top: parent.top
      anchors.topMargin: 36
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 18

      Text {
        textFormat: Text.PlainText
        text: strings.t("lock.city")
        color: "#FCEE0A"
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.letterSpacing: 4
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: strings.t("lock.sealed")
        color: "#00F0FF"
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.letterSpacing: 4
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Item {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent
      readonly property real borderTop: 3
      readonly property real borderRight: 3
      readonly property real borderBottom: 3
      readonly property real borderLeft: 3
      readonly property color ink: root.errorState ? "#FE1038" : "#FCEE0A"
      readonly property color ink2: root.errorState ? "#FCEE0A" : "#00F0FF"
      onInkChanged: plate.requestPaint()
      onInk2Changed: plate.requestPaint()

      Canvas {
        id: plate
        anchors.fill: parent
        anchors.margins: -12
        antialiasing: true

        function draw() {
          requestPaint()
        }

        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var pad = 12
          var x = pad
          var y = pad
          var w = width - pad * 2
          var h = height - pad * 2
          if (w < 20 || h < 20) return
          var cuts = root.cutsFor(11, w, h)
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
          ctx.fillStyle = root.errorState ? "rgba(40, 8, 14, 0.88)" : "rgba(8, 12, 18, 0.86)"
          ctx.fill()
          root.strokeFrame(ctx, x, y, w, h, 11, inputField.ink, inputField.ink2)
        }
        Connections {
          target: root
          function onFrameStepChanged() { plate.requestPaint() }
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
      }

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: -11
        text: strings.t("lock.access")
        color: inputField.ink
        font.family: Style.font.family
        font.pixelSize: 12
        font.letterSpacing: 3
      }

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: Commons.Color.lock.text
        selectionColor: Commons.Color.lock.selection
        selectedTextColor: Commons.Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Commons.Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? Commons.I18n.t("lock.checking") : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Commons.Color.lock.text : (root.failureMessage.length > 0 ? Commons.Color.lock.textError : Commons.Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      // A reader the shell cannot reach crosses out rather than disappears, so
      // it stops inviting touches that can never unlock.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: root.fingerprintUnavailable ? "󰺱" : "󰈷"
        color: root.fingerprintUnavailable ? Commons.Color.lock.textError : Commons.Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    // The crossed-out icon has no meaning to a user who has never seen it — it
    // is not intuitive that it signals a broken reader — so the words carry the
    // explanation and the icon only reinforces it.
    Text {
      objectName: "fingerprintUnavailableNotice"
      textFormat: Text.PlainText
      anchors.top: inputField.bottom
      anchors.topMargin: 18
      anchors.horizontalCenter: inputField.horizontalCenter
      visible: root.fingerprintConfigured && root.fingerprintUnavailable
      text: Commons.I18n.t("lock.fingerprintUnavailable")
      color: Commons.Color.lock.textError
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.italic: true
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
