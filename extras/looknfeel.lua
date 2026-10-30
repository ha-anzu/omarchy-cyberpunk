-- Full-screen glitch. Clean between bursts. Super+Shift+Alt+G toggles it.
-- The time uniform only moves when damage tracking is off, which keeps the
-- GPU drawing every frame.
local glitch_shader = (os.getenv("HOME") or "") .. "/.config/hypr/shaders/cp2077.frag"
local glitch_off = (os.getenv("HOME") or "") .. "/.local/state/omarchy/cp2077-glitch-off"
local glitch_flag = io.open(glitch_off, "r")
local glitch_disabled = glitch_flag ~= nil
if glitch_flag then
  glitch_flag:close()
end

if glitch_disabled then
  hl.config({
    decoration = { screen_shader = "" },
    debug = { damage_tracking = 2 },
  })
else
  hl.config({
    debug = { damage_tracking = 0 },
    decoration = { screen_shader = glitch_shader },
  })
end

hl.config({
  decoration = {
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled = true,
      range = 6,
      render_power = 2,
      color = "rgba(fcee0a44)",
      color_inactive = "rgba(00000000)",
    },
  },
})

hl.animation({ leaf = "windowsIn", enabled = true, speed = 8, bezier = "easeOutQuint", style = "popin 78%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.4, bezier = "linear", style = "popin 92%" })
hl.animation({ leaf = "border", enabled = true, speed = 12, bezier = "easeOutQuint" })
