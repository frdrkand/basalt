-- Keyboard layout, pointer behaviour and touchpad gestures. The layout and the
-- touchpad come from basalt.setup()'s `keyboard` and `touchpad` (config.lua).
-- Per-device overrides: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
--
-- A login screen has a keyboard setting of its own; this one only applies once
-- Hyprland is running.
local cfg = require("basalt.config").get()
local kb = cfg.keyboard

hl.config({
    input = {
        kb_layout  = kb.layout,
        kb_variant = kb.variant,
        kb_model   = kb.model,
        kb_options = kb.options,
        kb_rules   = kb.rules,

        numlock_by_default = true,

        follow_mouse = 2,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = cfg.touchpad,
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})
