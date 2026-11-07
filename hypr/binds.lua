-- Every keybind in the config, in one file, so the whole keyboard is visible at
-- once when adding one or changing one.
--
-- ---------------------------------------------------------------------------
-- INDEX — what is currently taken
-- ---------------------------------------------------------------------------
--
--   SUPER +   Q  terminal           C  close window     V  float toggle
--             E  file manager       F  maximize         P  pseudo
--             SPACE   launcher      J  togglesplit      L  lock
--             period  emoji picker  S  screenshot, region
--             ESCAPE  power menu    SECTION  scratchpad toggle
--             arrows  move focus    1..2  workspace chord, step 1 (switch)
--             wheel   workspace ±1  mouse:272 / mouse:273  drag / resize
--             T  tiling chord, step 1 (column weights / dwindle)
--
--   SUPER + SHIFT +
--             F  true fullscreen    S  screenshot, all monitors
--             arrows  move window   SECTION  send to scratchpad
--             1..2  workspace chord, step 1 (move)
--
--   bare      Print  screenshot, focused monitor
--             1..5, escape  step 2 of a workspace chord — bound inside the
--                           submaps only, so they stay free in the default map
--             1..9, BackSpace, Return, KP_Enter, d, escape
--                           the rest of the tiling chord, likewise
--
--   XF86      AudioRaiseVolume / AudioLowerVolume / AudioMute / AudioMicMute
--             MonBrightnessUp / MonBrightnessDown
--             AudioNext / AudioPrev / AudioPlay / AudioPause
--
-- Free SUPER letters: A B D G H I K M N O R U W X Y Z.
--
-- SUPER + <digit> is NOT free to take. The chord block near the bottom binds one
-- digit per monitor: one per declared output, or display.maxMonitors when the
-- layout is derived (config.lua).
--
-- A host adds its own binds after basalt.setup(); to take one of these over,
-- hl.unbind it first.
--
-- ---------------------------------------------------------------------------

local programs = require("basalt.programs")
local display  = require("basalt.display")
local columns  = require("basalt.columns")
local terminal, fileManager, screenshot = programs.terminal, programs.fileManager, programs.screenshot
local qsIpc = programs.ipc

-- ---------------------------------------------------------------------------
-- MODIFIER
-- ---------------------------------------------------------------------------
local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- ---------------------------------------------------------------------------
-- APPLICATIONS, WINDOWS AND THE SHELL OVERLAYS
-- ---------------------------------------------------------------------------
-- See https://wiki.hypr.land/Configuring/Basics/Binds/
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + ESCAPE", qsIpc("powermenu toggle"))  -- quickshell power menu
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" })) -- maximize (keeps gaps/bar)
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())                              -- true fullscreen
hl.bind(mainMod .. " + SPACE", qsIpc("launcher toggle"))  -- quickshell launcher
hl.bind(mainMod .. " + period", qsIpc("emoji toggle"))  -- quickshell emoji picker (SUPER+.)
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))  -- hypridle's lock_cmd answers it; see hypridle.conf

-- ---------------------------------------------------------------------------
-- FOCUS, WINDOW MOVEMENT AND THE SCRATCHPAD
-- ---------------------------------------------------------------------------
-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Move the active window with mainMod + SHIFT + arrow keys.
--
-- On a column layout (columns.lua) a tiled window is moved by the layout
-- itself (columns.move): left/right into the next column, up/down within its
-- own. Hyprland's move doesn't look at geometry in a Lua layout, it only steps
-- through a flat list of the windows. Should the layout not know the window
-- yet, Hyprland's swap stands in: it at least picks the neighbour on screen.
-- Dwindle and floating windows keep the plain move.
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    local move = hl.dsp.window.move({ direction = dir })
    local swap = hl.dsp.window.swap({ direction = dir })
    hl.bind(mainMod .. " + SHIFT + " .. dir, function()
        local win = hl.get_active_window()
        local ws  = hl.get_active_workspace()
        if win and not win.floating and ws and columns.isColumns(ws.id) then
            if not columns.move(win, ws.id, dir) then hl.dispatch(swap) end
        else
            hl.dispatch(move)
        end
    end)
end
-- The special workspace (scratchpad).
-- "section" is the correct keysym for the §-key on the Swedish (se) layout;
-- "GRAVE" doesn't exist on this layout (that key produces section/onehalf here).
hl.bind(mainMod .. " + SECTION",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + SECTION", hl.dsp.window.move({ workspace = "special:magic" }))

-- ---------------------------------------------------------------------------
-- SCREENSHOTS
-- ---------------------------------------------------------------------------
-- Screenshot via grim/slurp, opened in satty for annotation.
-- In satty: Ctrl+S saves to ~/Pictures/Screenshots, Ctrl+C copies to clipboard.
-- No native active-window mode: region covers it by dragging over the window.
hl.bind(mainMod .. " + S",         hl.dsp.exec_cmd(screenshot .. " region"))   -- region
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot .. " all"))      -- all monitors
hl.bind("Print",                   hl.dsp.exec_cmd(screenshot .. " focused"))  -- focused monitor

-- ---------------------------------------------------------------------------
-- POINTER
-- ---------------------------------------------------------------------------
-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ---------------------------------------------------------------------------
-- WORKSPACE CHORDS
-- ---------------------------------------------------------------------------
-- The two-step ("chord") workspace binds, built as submaps. Step 1 (with SUPER)
-- picks the MONITOR and the gesture; step 2 is a bare 1-5 tap (no modifier needed,
-- and you may release SUPER/SHIFT first):
--   SUPER + <m>          -> SWITCH on monitor m, then tap 1-5 to focus
--   SUPER + SHIFT + <m>  -> MOVE the active window to monitor m, then tap 1-5
-- The monitor number is the position in display.outputs() (display.lua): with
-- five workspaces each, monitor 1 holds 1-5 and monitor 2 holds 6-10. Examples:
--   SUPER+1 then 2        = focus workspace 2  (2nd workspace, monitor 1)
--   SUPER+2 then 1        = focus workspace 6  (1st workspace, monitor 2)
--   SUPER+SHIFT+2 then 1  = move active window to workspace 6
-- Holding the entry modifiers through step 2 also works; Escape cancels.
--
-- Workspace ids depend only on the monitor number, so the submaps are fixed.
-- Which monitor a number means is looked up when the key is pressed, so on a
-- derived layout the chords follow a dock/undock without anything rebuilt.

-- Entering a submap also pops up a quickshell hint (WorkspaceChord.qml); it is
-- hidden again the moment the chord resolves (a slot pressed) or is cancelled
-- (Escape). The hint is passive: it takes no keyboard focus, so these keys are
-- still handled here.
local function hideChord() return qsIpc("wschord hide") end

-- Build one submap: `name` is entered from the default map, each slot key runs
-- `action(ws)`, hides the hint, then returns to the default map. `mods` lists
-- the modifier prefixes accepted on the slot key, so holding (or releasing)
-- SUPER/SHIFT between the two presses is optional.
local function defineWorkspaceSubmap(name, first, slots, mods, action)
    hl.define_submap(name, "reset", function()
        for slot = 1, slots do
            local ws = first + slot
            for _, mod in ipairs(mods) do
                hl.bind(mod .. slot, function()
                    hl.dispatch(action(ws))
                    hl.dispatch(hideChord())
                    hl.dispatch(hl.dsp.submap("reset"))
                end)
            end
        end
        hl.bind("escape", function()
            hl.dispatch(hideChord())
            hl.dispatch(hl.dsp.submap("reset"))
        end)
    end)
end

-- Slot modifiers to tolerate in step 2. Switch is entered with SUPER only; move
-- is entered with SUPER+SHIFT, so also accept a still-held SHIFT.
local switchMods = { "", mainMod .. " + " }
local moveMods   = { "", "SHIFT + ", mainMod .. " + ", mainMod .. " + SHIFT + " }

for monitor = 1, display.maxMonitors do
    local slots = display.slots(monitor)
    local first = display.base(monitor) -- this monitor holds workspaces first+1 .. first+slots

    defineWorkspaceSubmap("switch" .. monitor, first, slots, switchMods,
        function(ws) return hl.dsp.focus({ workspace = ws }) end)
    defineWorkspaceSubmap("move" .. monitor, first, slots, moveMods,
        function(ws) return hl.dsp.window.move({ workspace = ws }) end)

    -- Step 1: SUPER + monitor to switch there; add SHIFT to move a window there.
    -- Switch shows the hint on the chosen monitor; move shows it on the active
    -- monitor (quickshell resolves that) and names the chosen target. Either
    -- does nothing if that monitor is not connected right now.
    hl.bind(mainMod .. " + " .. monitor, function()
        local monName = display.outputs()[monitor]
        if not monName then return end
        hl.dispatch(hl.dsp.submap("switch" .. monitor))
        hl.dispatch(qsIpc("wschord showSwitch " .. monName))
    end)
    hl.bind(mainMod .. " + SHIFT + " .. monitor, function()
        if not display.outputs()[monitor] then return end
        hl.dispatch(hl.dsp.submap("move" .. monitor))
        hl.dispatch(qsIpc("wschord showMove " .. monitor))
    end)
end

-- ---------------------------------------------------------------------------
-- TILING CHORD
-- ---------------------------------------------------------------------------
-- SUPER + T starts the chord; then type the slices' relative widths, one
-- digit per slice, left to right, and press Enter to apply them to the active
-- workspace (columns.lua is the layout):
--
--   SUPER+T  1 1  Enter    = 50 / 50
--   SUPER+T  2 1  Enter    = 67 / 33
--   SUPER+T  1 2 1  Enter  = 25 / 50 / 25
--   SUPER+T  2 1 1  Enter  = 50 / 25 / 25
--   SUPER+T  d             = back to dwindle (no Enter needed)
--
-- BackSpace drops the last digit, Escape (or Enter with no digits) cancels.
-- The keys are bare, but a still-held SUPER is accepted too. A quickshell
-- popup (TilingChord.qml) draws the slices while you type, and the result
-- after; like the workspace hint it takes no keyboard focus.
--
-- Each call is numbered: every one is a separate process, so two sent close
-- together can arrive out of order, and the popup drops the older one.
local tilingSeq = 0
local function tilingIpc(call, arg)
    tilingSeq = tilingSeq + 1
    local args = "tiling " .. call .. " " .. tilingSeq
    -- Single-quoted for the shell exec_cmd runs it in.
    if arg then args = args .. " '" .. arg:gsub("'", "'\\''") .. "'" end
    hl.dispatch(qsIpc(args))
end

local maxSlices = 9
local weights = {} -- the digits typed so far in this chord

local function showProgress()
    tilingIpc("update", table.concat(weights))
end

local function finish(call, arg)
    weights = {}
    tilingIpc(call, arg)
    hl.dispatch(hl.dsp.submap("reset"))
end

local function apply(spec)
    local digits = table.concat(weights)
    local done, err = columns.set(spec)
    if not done then return finish("failed", err) end
    if spec == "dwindle" then return finish("dwindle") end
    finish("applied", digits)
end

-- No "reset" argument here, unlike the workspace submaps: that makes a submap
-- one-shot (any bind in it drops back to the default map), and this chord
-- takes several keys. Every way out goes through finish().
hl.define_submap("tiling", function()
    for _, mod in ipairs({ "", mainMod .. " + " }) do
        for digit = 1, 9 do
            hl.bind(mod .. digit, function()
                if #weights < maxSlices then weights[#weights + 1] = digit end
                showProgress()
            end)
        end
        hl.bind(mod .. "BackSpace", function()
            weights[#weights] = nil
            showProgress()
        end)
        for _, key in ipairs({ "Return", "KP_Enter" }) do
            hl.bind(mod .. key, function()
                if #weights == 0 then return finish("hide") end
                apply(table.concat(weights, " "))
            end)
        end
        hl.bind(mod .. "d", function() apply("dwindle") end)
    end
    hl.bind("escape", function() finish("hide") end)
end)

hl.bind(mainMod .. " + T", function()
    weights = {}
    hl.dispatch(hl.dsp.submap("tiling"))
    tilingIpc("start")
end)

-- ---------------------------------------------------------------------------
-- MEDIA AND BRIGHTNESS KEYS
-- ---------------------------------------------------------------------------
-- All `locked` so they still work on the lock screen; the volume and brightness
-- ones repeat while held.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
