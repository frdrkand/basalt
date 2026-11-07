-- Basalt's Hyprland config: one call from a host's hyprland.lua.
--
--   local basalt = require("basalt")
--   basalt.setup({
--     display   = { ... },   -- declared monitors, or derived from what is plugged in
--     programs  = { ... },   -- terminal, file manager, screenshot, the shell
--     autostart = { ... },   -- what starts with the session, before the shell
--   })
--   -- then anything of the host's own: hl.config, hl.bind, hl.window_rule ...
--
-- Every option is described, with its default, in config.lua. setup() applies
-- the whole config; what comes after it in the host's file runs later, so a
-- host overrides a setting by setting it again and adds binds and rules by
-- adding them.
--
-- Basalt is required as "basalt", so it lives at basalt/ next to the host's
-- hyprland.lua: Hyprland puts the config file's directory on Lua's
-- package.path. Each part is also a module of its own, which is what lets a
-- terminal reach one:
--
--   hyprctl eval 'require("basalt.columns").set("40 35 25")'
local M = {}

-- The order is load-bearing:
--
--   * display first: it binds the persistent workspaces the rest refers to.
--   * colors last: it re-sets `general.col` and `group.col` over what
--     look-and-feel established.
--
-- Parts that need a value from another one (binds needs the terminal from
-- programs and the layout from display) require it themselves; require()
-- caches, so nothing runs twice.
local parts = {
  "display",
  "programs",
  "permissions",
  "look-and-feel",
  "misc",
  "input",
  "binds",
  "rules",
  "colors",
}

function M.setup(opts)
  require("basalt.config").set(opts or {})
  require("basalt.display").apply()
  for i = 2, #parts do
    require("basalt." .. parts[i])
  end
  return M
end

return M
