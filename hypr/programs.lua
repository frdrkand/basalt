-- The programs the config launches: what the binds reach for, and what starts
-- with the session. All of it comes from basalt.setup()'s `programs` and
-- `autostart` (config.lua).
local cfg = require("basalt.config").get()

local M = {}

M.terminal    = cfg.programs.terminal
M.fileManager = cfg.programs.fileManager
M.screenshot  = cfg.programs.screenshot
M.shell       = cfg.programs.shell
M.shellIpc    = cfg.programs.shellIpc

-- A dispatcher that sends the running quickshell instance an IPC call.
function M.ipc(args)
  return hl.dsp.exec_cmd(M.shellIpc .. " ipc call " .. args)
end

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
  for _, entry in ipairs(cfg.autostart) do
    if type(entry) == "function" then
      entry()
    else
      hl.exec_cmd(entry)
    end
  end
  -- The resident quickshell instance: bar, launcher, power menu, overlays.
  if M.shell then hl.exec_cmd(M.shell) end
end)

-- No `env` block: session variables are the host's to set, before Hyprland
-- starts, so they also reach everything started outside Hyprland's own exec.
-- Hyprland's mechanism, if it is ever needed:
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

return M
