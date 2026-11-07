-- Gaps, borders, rounding, shadow and blur, the animation curve and its leaves,
-- and the per-layout tuning.
--
-- Border *colours* are not here: they come from the shared palette and have to be
-- applied after everything else, so they live in colors.lua, which is
-- loaded last.
hl.config({
  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
  },
})

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        -- No gaps at all: windows tile edge to edge and sit flush against the
        -- screen. The border is what separates them.
        gaps_in  = 0,
        gaps_out = 0,

        border_size = 2,

        -- Border colors are set from the design-system palette in colors.lua,
        -- which is loaded last (so it wins over this block).

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 4,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- Dark, uncolored, punchier per current DS --shadow-window:
        -- 0 18px 48px rgba(0, 0, 0, 0.62).
        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            color        = 0x9e000000,
        },

        -- The shell is opaque, so this only affects transparent windows.
        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
-- The design allows only short, functional motion: 120-200ms ease-out, with no
-- bounce or spring anywhere. "dsOut" is the design's --ease-out curve exactly;
-- the stock "easy" spring is gone because springs overshoot. Hyprland's `speed`
-- is in 100ms units, so 2 = --duration-normal (200ms) and 1.2 = --duration-fast.
hl.curve("dsOut",          { type = "bezier", points = { {0.16, 1},    {0.3, 1}     } })

hl.animation({ leaf = "global",        enabled = true,  speed = 2,    bezier = "dsOut" })
hl.animation({ leaf = "border",        enabled = true,  speed = 1.2,  bezier = "dsOut" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 2,    bezier = "dsOut" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 2,    bezier = "dsOut",        style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 2,    bezier = "dsOut",        style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.2,  bezier = "dsOut" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.2,  bezier = "dsOut" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 1.2,  bezier = "dsOut" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 2,    bezier = "dsOut" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 2,    bezier = "dsOut",        style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 2,    bezier = "dsOut",        style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.2,  bezier = "dsOut" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.2,  bezier = "dsOut" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 2,    bezier = "dsOut",        style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 2,    bezier = "dsOut",        style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 2,    bezier = "dsOut",        style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 1.2,  bezier = "dsOut" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})
