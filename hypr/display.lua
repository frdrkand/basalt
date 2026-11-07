-- Monitors, and the persistent workspaces bound to them.
--
-- A machine either declares its monitors (`display.outputs`, see config.lua)
-- or has them derived from whatever is connected: a laptop cannot declare an
-- external monitor that comes and goes. Derived, the whole config is reloaded
-- whenever a monitor is plugged or unplugged; the reload re-runs this file
-- against the new set, and Hyprland moves the persistent workspaces onto the
-- monitors their new rules name.
--
-- THE ORDERING RULE, when derived:
--
--     the built-in panel first, then external monitors sorted by connector name
--
-- The first is the primary at 0x0, holds workspaces 1-5 and is monitor 1 in
-- the SUPER+<n> chords. Docked, an external gets 6-10 and sits centred above
-- the panel. (With the panel absent, the first external takes its place.)
--
-- THE SHELL READS THE RESULT. Every load writes the layout to
-- $XDG_RUNTIME_DIR/basalt-display.state, one line per monitor in layout order:
--
--     <connector> <first workspace id> <workspace count>
--
-- quickshell's Display.qml watches that file, so the bar's workspace pips
-- follow this file's decisions instead of repeating its rule.
local M = {}

local cfg = require("basalt.config").get().display

local stateFile = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/basalt-display.state"

M.declared = cfg.outputs ~= nil

-- How many monitors the SUPER+<n> chords are bound for (binds.lua). A chord for
-- a monitor that is not connected does nothing.
M.maxMonitors = M.declared and #cfg.outputs or cfg.maxMonitors

function M.isInternal(name)
  return name:match(cfg.internal) ~= nil
end

-- Connector names in layout order. Called at load and again at keypress time by
-- the chord binds, so derived, it always reflects what is plugged in now.
function M.outputs()
  local names = {}
  if M.declared then
    for _, out in ipairs(cfg.outputs) do names[#names + 1] = out.name end
    return names
  end
  for _, mon in ipairs(hl.get_monitors()) do
    if not mon.is_mirror then names[#names + 1] = mon.name end
  end
  table.sort(names, function(a, b)
    local ia, ib = M.isInternal(a), M.isInternal(b)
    if ia ~= ib then return ia end -- internal before external
    return a < b
  end)
  return names
end

-- How many workspaces monitor `index` (1-based) holds.
function M.slots(index)
  if M.declared then
    local out = cfg.outputs[index]
    return out and (out.workspaces or cfg.workspaces) or 0
  end
  return cfg.workspaces
end

-- Workspace ids on monitor `index` are base(index) + 1 .. base(index) + slots(index).
function M.base(index)
  local base = 0
  for i = 1, index - 1 do base = base + M.slots(i) end
  return base
end

-- Where monitor `i` of `names` goes, derived. The primary is fixed at 0x0; the
-- rest are auto-placed around it, so the first external centres above the
-- panel and any further ones line up to the right.
local function position(names, i)
  if i == 1 then return "0x0" end
  if i == 2 and M.isInternal(names[1]) then return "auto-center-up" end
  return "auto-right"
end

local function reload()
  hl.exec_cmd("hyprctl reload")
end

local function writeState(names)
  local f = io.open(stateFile, "w")
  if not f then return end
  for i, name in ipairs(names) do
    f:write(name, " ", M.base(i) + 1, " ", M.slots(i), "\n")
  end
  f:close()
end

function M.apply()
  local names = M.outputs()

  if M.declared then
    for _, out in ipairs(cfg.outputs) do
      hl.monitor({
        output   = out.name,
        mode     = out.mode or "preferred",
        position = out.position or "auto",
        scale    = out.scale or 1,
      })
    end
  else
    -- Catch-all for a monitor that has only just been plugged in. It only has
    -- to hold for the moment until the reload below gives it its real rule.
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = cfg.scale })
    for i, name in ipairs(names) do
      hl.monitor({ output = name, mode = "preferred", position = position(names, i), scale = cfg.scale })
    end
  end

  for i, name in ipairs(names) do
    local base = M.base(i)
    for slot = 1, M.slots(i) do
      hl.workspace_rule({
        workspace  = tostring(base + slot),
        monitor    = name,
        persistent = true,
        default    = (slot == 1),
      })
    end
  end

  writeState(names)

  if not M.declared then
    hl.on("monitor.added", reload)
    hl.on("monitor.removed", reload)

    -- The very first load happens before any output exists, so it found no
    -- monitors and bound no workspaces. Normally monitor.added fixes that a
    -- moment later; this covers a start where it fired before anything was
    -- listening.
    if #names == 0 then
      hl.on("hyprland.start", reload)
    end
  end
end

return M
