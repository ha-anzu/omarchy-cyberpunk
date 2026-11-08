import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// Hyprland draws one continuous border with one chamfer for every corner.
// This layer paints the real frame: a broken stroke, a different cut on
// each corner, gaps in the runs, and a 1px shift so the halves do not meet.
// The focused window is thicker and is the only one that glows.
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
    var gap = Math.round(6 + root.mix(seed, salt + 2) * 8)
    if (gap > span * 0.22) gap = Math.round(span * 0.18)
    var center = leadA + span * (0.28 + root.mix(seed, salt + 3) * 0.44) + slide
    var g0 = center - gap / 2
    var g1 = center + gap / 2
    // One pixel of inward jog, so the break is a step and not a second border.
    var shiftA = 0
    var shiftB = 1
    if ((root.step + salt) % 8 === 2) shiftA = 1
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
    var activeAddress = active ? String(active.address || "").toLowerCase().replace(/^0x/, "") : ""
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
      // IPC at/size are already in this layer's logical pixels. Dividing by
      // the output scale draws the frame inside the window.
      var x = ipc.at[0] - (monitor.x || 0) + 3
      var y = ipc.at[1] - (monitor.y || 0) + 3
      var w = ipc.size[0] - 6
      var h = ipc.size[1] - 6
      if (w < 24 || h < 24) continue
      var visW = Math.min(x + w, width) - Math.max(x, 0)
      var visH = Math.min(y + h, height) - Math.max(y, 0)
      if (visW < 48 || visH < 48) continue
      pending.push({
        x: x,
        y: y,
        w: w,
        h: h,
        seed: root.seedOf(ipc.address || toplevel.address),
        hot: toplevel.activated === true || (activeAddress !== "" && String(ipc.address || toplevel.address || "").toLowerCase().replace(/^0x/, "") === activeAddress)
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
      // Each edge keeps its own weight, and the weight breathes with the step.
      // The focused window is thicker and is the only one with a halo.
      var edges = [
        [x + cuts[0], y, x + w - cuts[1], y, 10, slide, false],
        [x + w, y + cuts[1], x + w, y + h - cuts[2], 20, -slide, false],
        [x + w - cuts[2], y + h, x + cuts[3], y + h, 30, slide * 0.6, false],
        [x, y + h - cuts[3], x, y + cuts[0], 40, -slide * 0.4, false],
        [x + cuts[0], y, x, y + cuts[0], 51, 0, true],
        [x + w - cuts[1], y, x + w, y + cuts[1], 52, 0, true],
        [x + w, y + h - cuts[2], x + w - cuts[2], y + h, 53, 0, true],
        [x, y + h - cuts[3], x + cuts[3], y + h, 54, 0, true]
      ]
      function weight(salt) {
        var pulse = ((root.step + salt) % 8) / 7
        var personality = root.mix(seed, salt + 8)
        if (win.hot) return 1.7 + personality * 1.5 + pulse * (0.35 + personality * 0.9)
        return 1.05 + personality * 0.55 + pulse * 0.25
      }
      function trace(edge) {
        if (edge[6]) root.drawChamfer(ctx, edge[0], edge[1], edge[2], edge[3], seed, edge[4])
        else root.drawRun(ctx, edge[0], edge[1], edge[2], edge[3], seed, edge[4], edge[5])
      }
      // One halo pass on the focused window. A wider stack reads as a second border.
      ctx.lineCap = "butt"
      var e
      if (win.hot) {
        for (e = 0; e < edges.length; e++) {
          ctx.beginPath()
          ctx.lineWidth = weight(edges[e][4]) + 7
          ctx.strokeStyle = "rgba(252, 238, 10, 0.22)"
          trace(edges[e])
          ctx.stroke()
        }
      }
      for (e = 0; e < edges.length; e++) {
        ctx.beginPath()
        ctx.lineWidth = weight(edges[e][4])
        ctx.strokeStyle = win.hot ? "#FCEE0A" : "rgba(252, 238, 10, 0.42)"
        trace(edges[e])
        ctx.stroke()
      }

      if (!win.hot) continue
      var longest = 0
      for (var c = 1; c < 4; c++) if (cuts[c] > cuts[longest]) longest = c
      function tickPath() {
        if (longest === 0) ctx.moveTo(x + 4, y + cuts[0] + 3), ctx.lineTo(x + 4, y + cuts[0] + 16)
        else if (longest === 1) ctx.moveTo(x + w - 4, y + cuts[1] + 3), ctx.lineTo(x + w - 4, y + cuts[1] + 16)
        else if (longest === 2) ctx.moveTo(x + w - cuts[2] - 16, y + h - 4), ctx.lineTo(x + w - cuts[2] - 3, y + h - 4)
        else ctx.moveTo(x + cuts[3] + 3, y + h - 4), ctx.lineTo(x + cuts[3] + 16, y + h - 4)
      }
      ctx.beginPath()
      ctx.lineWidth = 8
      ctx.strokeStyle = "rgba(0, 240, 255, 0.35)"
      tickPath()
      ctx.stroke()
      ctx.beginPath()
      ctx.lineWidth = 2.4
      ctx.strokeStyle = "#00F0FF"
      tickPath()
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
