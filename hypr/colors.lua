-- Border and group colours, from the base16 palette: basalt.setup()'s
-- `palette`, or Basalt's own (palette.lua).
--
-- LOADED LAST, and it has to be: these override the `general` and `group`
-- blocks set in look-and-feel.lua. See the order in init.lua.
local palette = require("basalt.config").get().palette

--
-- active_border is base04 and inactive_border is base02 at 70% alpha — a plain
-- base00 inactive border would read as invisible against the wallpaper.
local function rgb(base)  return "rgb(" .. palette[base] .. ")"       end
local function rgba(base, a) return "rgba(" .. palette[base] .. a .. ")" end

hl.config({
  general = { col = {
    active_border   = rgb("base04"),
    inactive_border = rgba("base02", "B3"),
  } },
  group = {
    col = {
      border_active          = rgb("base0E"),
      border_inactive        = rgb("base00"),
      border_locked_active   = rgb("base08"),
      border_locked_inactive = rgb("base00"),
    },
    groupbar = { col = {
      active          = rgb("base0E"),
      inactive        = rgb("base00"),
      locked_active   = rgb("base08"),
      locked_inactive = rgb("base00"),
    } },
  },
})
