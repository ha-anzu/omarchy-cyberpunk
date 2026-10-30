-- Site chrome: 1px-equivalent yellow rule, square corners, black field.
-- The menu on cyberpunk.net is a solid #fcee0a stroke with a cut corner,
-- not a rainbow gradient. Cyan stays a focus color in the shell.

local active_border_color = "rgba(fcee0aee)"
local inactive_border_color = "rgba(4c4c4c99)"

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
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
      enabled = true,
      range = 6,
      render_power = 2,
      color = "rgba(fcee0a44)",
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
