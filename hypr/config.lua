-- The options basalt.setup() takes, and their defaults. Every part reads its
-- settings from here, so this file is the whole list of what a host can set
-- without writing Hyprland config of its own.
--
-- Each top-level table is merged key by key over its default, so a host names
-- only what it changes: `programs = { terminal = "foot" }` keeps the rest.
-- Lists (autostart, display.outputs) are replaced whole, not merged.
local M = {}

local defaults = {
  -- The base16 palette, as bare six-digit hex without a leading '#'. Used for
  -- the borders (colors.lua). The default is Basalt's own, the same values as
  -- palette.lua; a host passes its own table to recolour.
  palette = nil, -- nil: require("basalt.palette")

  -- The monitors, and the persistent workspaces bound to each.
  --
  -- Two ways to say which monitors there are:
  --
  --   DECLARED: `outputs` lists them, in layout order. For a machine whose
  --   monitors do not change:
  --
  --     outputs = {
  --       { name = "DP-1", mode = "2560x1440@59.95", position = "1920x0" },
  --       { name = "HDMI-A-1", mode = "1920x1080@60", position = "0x100" },
  --     }
  --
  --   Each may also set `scale` (default 1) and `workspaces` (default the
  --   `workspaces` below).
  --
  --   DERIVED: no `outputs`. The layout is whatever is connected, ordered
  --   built-in panel first (the connector matching `internal`), then the rest
  --   by connector name. The first sits at 0x0, the second centred above a
  --   panel, any more to the right; every one at its preferred mode. Plugging
  --   or unplugging a monitor reloads the config.
  --
  -- Either way the order is the monitor number in the SUPER+<n> chords, and
  -- workspace ids are handed out in it: monitor 1 holds 1..n, monitor 2 the
  -- next n, and so on.
  display = {
    outputs = nil,
    workspaces = 5,      -- per monitor
    internal = "^eDP%-", -- derived only: the built-in panel, as a Lua pattern
    scale = 1,           -- derived only
    maxMonitors = 2,     -- derived only: how many SUPER+<n> chords to bind
  },

  -- What the binds launch, and how the shell is started and reached.
  programs = {
    terminal = "kitty",
    fileManager = "kitty -e yazi",
    -- Called with region | all | focused. basalt-screenshot is in Basalt's
    -- bin/.
    screenshot = "basalt-screenshot",
    -- Starts the resident quickshell instance, after `autostart`.
    shell = "qs",
    -- Sends it an IPC call: `<shellIpc> ipc call <target> <fn> ...`. Separate
    -- from `shell` for a host whose `shell` is a wrapper with a cost (a GPU
    -- shim, say) that a message to the running instance does not need.
    shellIpc = "qs",
  },

  -- What starts with the session, in order, before the shell. Each entry is a
  -- command line, or a function to call (to set the environment the commands
  -- after it inherit, say). Replaces the default list whole.
  autostart = { "hyprpaper", "hypridle", "dunst" },

  -- The keyboard, as Hyprland's input.kb_* settings take it. The default is
  -- Swedish without dead keys (´ ` ¨ ^ ~ type themselves), with Compose on
  -- Right Ctrl, not Right Alt, which is AltGr there and carries @ $ { } [ ] \ |.
  keyboard = {
    layout = "se",
    variant = "nodeadkeys",
    model = "",
    options = "compose:rctrl",
    rules = "",
  },

  -- Touchpad settings, merged into Hyprland's input.touchpad.
  touchpad = {
    natural_scroll = false,
  },
}

local current = nil

local function merge(base, over)
  if type(base) ~= "table" or type(over) ~= "table" then
    if over == nil then return base end
    return over
  end
  -- A list replaces; a table of settings merges.
  if over[1] ~= nil then return over end
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  for k, v in pairs(over) do out[k] = v end
  return out
end

function M.set(opts)
  local c = {}
  for k, v in pairs(defaults) do c[k] = merge(v, opts[k]) end
  for k, v in pairs(opts) do
    if defaults[k] == nil and k ~= "palette" then
      error("basalt.setup: unknown option '" .. tostring(k) .. "'")
    end
  end
  c.palette = opts.palette or require("basalt.palette")
  current = c
end

-- The settings in force. A part loaded without setup() (from `hyprctl eval`,
-- say) sees the defaults rather than failing.
function M.get()
  if not current then M.set({}) end
  return current
end

return M
