-- Full-screen glitch. Clean between bursts. Super+Shift+Alt+G toggles it.
-- vfr stays off only while the glitch is on. Otherwise a still screen keeps
-- the last glitch frame until the next real redraw.
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
    debug = { damage_tracking = 2, vfr = true },
  })
else
  hl.config({
    debug = { damage_tracking = 0, vfr = false },
    decoration = { screen_shader = glitch_shader },
  })
end

local frame_active = { colors = { "rgba(fcee0aee)", "rgba(00f0ffee)" }, angle = 90 }
local frame_idle = "rgba(fcee0a77)"

-- The broken frame is drawn by the nightcity.frame shell layer. Hyprland's
-- own border is one even stroke, so it stays off and the window stays square.
-- This block must not set screen_shader or debug. The block above owns those.
hl.config({
  general = {
    border_size = 0,
    -- Tight gaps. A wide gap lets the yellow wallpaper read as a thick frame.
    gaps_in = 2,
    gaps_out = 3,
    col = {
      active_border = frame_active,
      inactive_border = frame_idle,
    },
  },
  decoration = {
    rounding = 0,
    rounding_power = 1.0,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled = false,
      range = 4,
      render_power = 2,
      color = "rgba(fcee0a33)",
      color_inactive = "rgba(00000000)",
    },
  },
  group = {
    col = {
      border_active = frame_active,
      border_inactive = frame_idle,
    },
    groupbar = {
      rounding = 0,
      rounding_power = 1.0,
      gradient_rounding = 0,
      gradient_rounding_power = 1.0,
    },
  },
})

hl.animation({ leaf = "windowsIn", enabled = true, speed = 8, bezier = "easeOutQuint", style = "popin 78%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.4, bezier = "linear", style = "popin 92%" })
hl.animation({ leaf = "border", enabled = true, speed = 12, bezier = "easeOutQuint" })
