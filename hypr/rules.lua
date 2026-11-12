-- Window and layer rules.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.window_rule({
    -- Ignore maximize requests from all apps.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- The quickshell Settings window is a real toplevel (FloatingWindow), not a
-- layer-shell overlay, so it needs a rule to float instead of joining the tiling
-- layout. Its own implicit size is 980x660; centering keeps it off the corner.
hl.window_rule({
    name  = "quickshell-settings",
    match = { class = "^(org\\.quickshell)$", title = "^(Settings)$" },

    float  = true,
    size   = "980 660",
    center = true,
})

-- Same for the Updates window (UpdatesWindow.qml, implicit size 760x640).
hl.window_rule({
    name  = "quickshell-updates",
    match = { class = "^(org\\.quickshell)$", title = "^(Updates)$" },

    float  = true,
    size   = "760 640",
    center = true,
})

-- disktree floats at the size its README suggests: the treemap wants room, and
-- below its 900x600 minimum it stops being readable, which a narrow column
-- would push it under.
hl.window_rule({
    name  = "disktree",
    match = { class = "^(disktree)$" },

    float  = true,
    size   = "1400 900",
    center = true,
})

-- Frosted glass for dunst toasts, matching the design system's NotificationCard
-- (--bg-glass-strong panel over a blurred backdrop). dunst renders on the
-- "notifications" layer; ignore_alpha keeps the transparent rounded-corner
-- margins out of the blur so only the ~88%-opaque panel is frosted.
hl.layer_rule({
    name         = "dunst-glass",
    match        = { namespace = "^notifications$" },
    blur         = true,
    ignore_alpha = 0.5,
})
