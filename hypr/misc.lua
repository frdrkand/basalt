-- Startup cosmetics (no stock wallpaper, no logo or splash before hyprpaper
-- paints), plus the one setting that makes a blanked screen recoverable.
hl.config({
    misc = {
        force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- Solid dark background at startup instead of the logo, so
                                        -- there's no logo flash before hyprpaper paints the wallpaper.
        disable_splash_rendering = true,

        -- Let a keypress power the monitors back on. Hyprland defaults this to
        -- false, and with it false a DPMS off that nothing undoes leaves the
        -- machine reachable only from a TTY. That is not a hypothetical: it
        -- stranded a machine twice while its idle blanking was being debugged.
        --
        -- mouse_move_enables_dpms is deliberately left off. A mouse that nudges
        -- itself would defeat the blanking entirely; a keypress is deliberate.
        key_press_enables_dpms = true
    },
})

