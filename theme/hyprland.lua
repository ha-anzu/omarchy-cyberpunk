-- Site chrome. Hyprland draws one continuous border, so that border stays off.
-- plugin/nightcity.frame paints the broken yellow stroke. Wide gaps would
-- show the wallpaper as a thick frame, so the gaps stay at 2 and 3.
-- Cyan stays a focus color in the shell.

local active_border_color = "rgba(fcee0aee)"
local inactive_border_color = "rgba(4c4c4c99)"

hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 3,
    border_size = 0,
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  decoration = {
    rounding = 0,
    dim_inactive = true,
    dim_strength = 0.28,
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
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
    groupbar = {
      font_family = "monospace",
      text_color = "rgb(000000)",
      text_color_inactive = "rgb(ffffff)",
      gradients = false,
      gradient_rounding = 0,
      col = {
        active = "rgb(fcee0a)",
        inactive = "rgba(000000ee)",
      },
    },
  },
})
