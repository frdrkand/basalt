-- A host's Hyprland config: Basalt, set up for this machine, then anything of
-- the host's own. Basalt is linked (or copied) at ./basalt.
require("basalt").setup({
  -- Derived from what is connected: the built-in panel, then externals.
  display = { maxMonitors = 2 },

  programs = {
    terminal = "kitty",
    fileManager = "kitty -e yazi",
  },

  autostart = {
    "hyprpaper",
    "hypridle",
    "dunst",
    "systemctl --user start hyprpolkitagent",
  },

  touchpad = { natural_scroll = true },
})

-- The host's own, after Basalt: a setting set again wins, binds add up.
hl.config({ cursor = { no_hardware_cursors = 0 } })
