import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// Hyprland draws one continuous border with one chamfer for every corner.
// This layer paints the real frame: a 1px stroke, a different cut on each
// corner, gaps in the runs, and a 1px shift so the halves do not meet.
Item {
  id: root

  property int step: 0
  property int revision: 0
  property string seen: ""

  function mix(seed, salt) {
    var n = (seed ^ Math.imul(salt + 1, 0x9e3779b1)) >>> 0
    n = Math.imul(n, 0x85ebca6b) >>> 0
    n = (n ^ (n >>> 13)) >>> 0
    return (n % 10000) / 10000
  }

  function seedOf(address) {
    var h = 2166136261
    var text = String(address || "")
    for (var i = 0; i < text.length; i++) {
      h ^= text.charCodeAt(i)
      h = Math.imul(h, 16777619) >>> 0
    }
    return h
  }

  function signature() {
    var parts = []
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var ipc = toplevels[i].lastIpcObject
      if (!ipc || !ipc.at || !ipc.size) continue
      parts.push(ipc.address + ":" + ipc.at[0] + "," + ipc.at[1] + ":" + ipc.size[0] + "x" + ipc.size[1] + ":" + ipc.fullscreen + ":" + (ipc.hidden ? 1 : 0) + ":" + (ipc.workspace ? ipc.workspace.id : ""))
    }
    var active = Hyprland.activeToplevel
    parts.push("#" + (active ? active.address : "") + "@" + root.step)
    return parts.join(";")
  }

  function refresh() {
    Hyprland.refreshToplevels()
    Qt.callLater(function() {
      var next = root.signature()
      if (next === root.seen) return
      root.seen = next
      root.revision++
    })
  }

  Timer {
    interval: 160
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 1100
    repeat: true
    running: Style.duration(1) > 0
    onTriggered: {
      root.step = (root.step + 1) % 8
      root.seen = ""
      root.refresh()
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event.name
      if (name === "openwindow" || name === "closewindow" || name === "movewindow"
          || name === "changefloatingmode" || name === "fullscreen" || name === "workspace"
          || name === "focusedmon" || name === "activewindow" || name === "pin") {
        root.refresh()
      }
    }
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
    // Both halves step inward, by different amounts, so the run is broken
    // and the two pieces are not colinear.
    var shiftA = root.mix(seed, salt + 4) > 0.45 ? 1 : 0
    var shiftB = 1 + (root.mix(seed, salt + 5) > 0.55 ? 1 : 0)
    if ((root.step + salt) % 8 === 2) shiftA = shiftA === 0 ? 1 : 0
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

  function paint(ctx, monitor, width, height) {
    ctx.clearRect(0, 0, width, height)
    if (!monitor || !monitor.activeWorkspace) return
    var workspaceId = monitor.activeWorkspace.id
    var special = monitor.lastIpcObject && monitor.lastIpcObject.specialWorkspace
    var specialId = special && special.id ? special.id : 0
    var active = Hyprland.activeToplevel
    var activeAddress = active ? String(active.address) : ""
    var toplevels = Hyprland.toplevels.values
    var pending = []
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      var ipc = toplevel.lastIpcObject
      if (!ipc || !ipc.at || !ipc.size || !ipc.mapped) continue
      if (ipc.hidden) continue
      if (ipc.fullscreen >= 2) continue
      if (!toplevel.monitor || toplevel.monitor.id !== monitor.id) continue
      var onWorkspace = toplevel.workspace && (toplevel.workspace.id === workspaceId || (specialId !== 0 && toplevel.workspace.id === specialId))
      if (!onWorkspace && !ipc.pinned) continue
      var scale = monitor.scale > 0 ? monitor.scale : 1
      var w = ipc.size[0] / scale - 6
      var h = ipc.size[1] / scale - 6
      if (w < 24 || h < 24) continue
      pending.push({
        x: (ipc.at[0] - monitor.x) / scale + 3,
        y: (ipc.at[1] - monitor.y) / scale + 3,
        w: w,
        h: h,
        seed: root.seedOf(ipc.address || toplevel.address),
        hot: String(ipc.address || toplevel.address) === activeAddress
      })
    }
    pending.sort(function(a, b) { return (a.hot ? 1 : 0) - (b.hot ? 1 : 0) })

    for (var n = 0; n < pending.length; n++) {
      var win = pending[n]
      var seed = win.seed
      var x = win.x
      var y = win.y
      var w = win.w
      var h = win.h
      var maxCut = Math.max(4, Math.min(w, h) * 0.22)
      var cuts = [
        Math.min(maxCut, 5 + Math.round(root.mix(seed, 1) * 14)),
        Math.min(maxCut, 3 + Math.round(root.mix(seed, 2) * 11)),
        Math.min(maxCut, 7 + Math.round(root.mix(seed, 3) * 13)),
        Math.min(maxCut, 4 + Math.round(root.mix(seed, 4) * 16))
      ]
      var slide = (root.step - 3.5) * 1.4
      ctx.beginPath()
      ctx.lineWidth = 1
      ctx.strokeStyle = win.hot ? "#FCEE0A" : "rgba(252, 238, 10, 0.42)"
      root.drawRun(ctx, x + cuts[0], y, x + w - cuts[1], y, seed, 10, slide)
      root.drawRun(ctx, x + w, y + cuts[1], x + w, y + h - cuts[2], seed, 20, -slide)
      root.drawRun(ctx, x + w - cuts[2], y + h, x + cuts[3], y + h, seed, 30, slide * 0.6)
      root.drawRun(ctx, x, y + h - cuts[3], x, y + cuts[0], seed, 40, -slide * 0.4)
      root.drawChamfer(ctx, x + cuts[0], y, x, y + cuts[0], seed, 51)
      root.drawChamfer(ctx, x + w - cuts[1], y, x + w, y + cuts[1], seed, 52)
      root.drawChamfer(ctx, x + w, y + h - cuts[2], x + w - cuts[2], y + h, seed, 53)
      root.drawChamfer(ctx, x, y + h - cuts[3], x + cuts[3], y + h, seed, 54)
      ctx.stroke()

      if (!win.hot) continue
      var longest = 0
      for (var c = 1; c < 4; c++) if (cuts[c] > cuts[longest]) longest = c
      ctx.beginPath()
      ctx.strokeStyle = "#00F0FF"
      if (longest === 0) ctx.moveTo(x + 4, y + cuts[0] + 3), ctx.lineTo(x + 4, y + cuts[0] + 3 + 11)
      else if (longest === 1) ctx.moveTo(x + w - 4, y + cuts[1] + 3), ctx.lineTo(x + w - 4, y + cuts[1] + 14)
      else if (longest === 2) ctx.moveTo(x + w - cuts[2] - 14, y + h - 4), ctx.lineTo(x + w - cuts[2] - 3, y + h - 4)
      else ctx.moveTo(x + cuts[3] + 3, y + h - 4), ctx.lineTo(x + cuts[3] + 15, y + h - 4)
      ctx.stroke()
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: frameWindow
      required property var modelData

      screen: modelData
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "nightcity-frame"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      anchors { top: true; bottom: true; left: true; right: true }
      mask: Region {}

      readonly property var monitor: Hyprland.monitorFor(screen)

      Canvas {
        id: plate
        anchors.fill: parent
        onPaint: root.paint(getContext("2d"), frameWindow.monitor, width, height)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
          target: root
          function onRevisionChanged() { plate.requestPaint() }
        }
      }
    }
  }
}
