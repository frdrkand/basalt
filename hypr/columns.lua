-- Column layouts: split a workspace into vertical slices of chosen proportions
-- (50/50, 25/50/25, 67/33, ...), set per workspace and switchable at any time,
-- with dwindle still one chord away. The tiling chord in binds.lua builds the
-- proportions from digits (SUPER+T, 1, 2, 1, Enter is 25/50/25).
--
-- It is a Lua layout (hl.layout.register), selected as "lua:columns". A
-- workspace is switched by adding a workspace rule at runtime that names the
-- layout; Hyprland merges it into the workspace's existing rule (the monitor
-- and persistence from display.lua stay), and the workspace re-tiles at once.
-- Switching back is the same rule naming dwindle.
--
-- HOW WINDOWS FILL THE SLICES. Every slice is a column that can hold several
-- windows, stacked top to bottom. The layout remembers which column each
-- window is in (Hyprland only hands a Lua layout a flat list of windows):
--
--   * a new window takes the first empty slice, left to right; once every
--     slice has a window, it stacks below the focused window, in its column;
--   * no slice is left empty while another has windows to spare: when a
--     window closes and empties its slice, the bottom window of the fullest
--     column moves out into a slice of its own;
--   * fewer windows than slices: the last window takes the unused slices too,
--     so the edges already drawn stay where the chord put them
--     (25/50/25 with two windows is 25/75, not 33/67).
--
-- MOVING WINDOWS (SUPER+SHIFT+arrows, see M.move):
--
--   * left/right moves the window into the next column, stacked where it
--     was vertically. A window alone in its column would leave that slice
--     empty, so it trades places with a window there instead (the one
--     focused most recently);
--   * up/down moves it within its column;
--   * at the edge of the workspace it goes to the monitor on that side, as
--     with dwindle.
--
-- Hyprland's own move can't do this here: on a Lua layout it ignores where
-- windows are and only steps through that flat list.
-- Mouse resizing has no effect here; run the chord again instead.
--
-- Weights the digits can't express work from a terminal:
--
--   hyprctl eval 'require("basalt.columns").set("40 35 25")'
--
-- The numbers are relative ("1 2 1" is 25/50/25), and "dwindle" switches back.
--
-- Choices and the columns' windows survive a config reload (a derived display
-- reloads it on every dock and undock): they are written to $XDG_RUNTIME_DIR, so they last until logout.
local M = {}

M.layout = "lua:columns"

-- For a workspace on lua:columns with nothing chosen for it (should not
-- happen, but a layout must place every window).
local fallback = { 1, 1 }

-- Workspace id -> list of relative widths. Only workspaces on lua:columns
-- are in here.
local ratios = {}

-- Workspace id -> its columns, left to right, each a list of window
-- addresses, top to bottom: { { "0x1" }, { "0x2" }, { "0x3", "0x4" } }.
local columnsOf = {}

-- Addresses of windows being opened right now, from window.open_early, which
-- Hyprland fires just before it gives the window to the layout. Tells a new
-- window apart from one that already existed (see reconcile).
local justOpened = {}
hl.on("window.open_early", function(win)
    if win and win.address then justOpened[win.address] = true end
end)
-- A window that never reached a columns workspace (dwindle, floating) would
-- otherwise stay listed.
hl.on("window.open", function(win)
    if win and win.address then justOpened[win.address] = nil end
end)

local runtimeDir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
-- "ws w1 w2 ...": read by the bar too (Columns.qml), so it keeps that shape.
local stateFile = runtimeDir .. "/hypr-columns.state"
-- "ws 0x1|0x2|0x3,0x4": columns split by |, windows in a column by commas.
-- Window addresses last as long as Hyprland does, so across a config reload.
local windowsFile = runtimeDir .. "/hypr-columns.windows"

-- "25 50 25" -> { 25, 50, 25 }; nil if it is not a list of positive numbers.
local function parse(spec)
    local list = {}
    for word in spec:gmatch("%S+") do
        local n = tonumber(word)
        if not n or n <= 0 then return nil end
        list[#list + 1] = n
    end
    if #list == 0 then return nil end
    return list
end

local function save()
    local f = io.open(stateFile, "w")
    if not f then return end
    for ws, list in pairs(ratios) do
        f:write(ws, " ", table.concat(list, " "), "\n")
    end
    f:close()
end

local function load()
    local f = io.open(stateFile, "r")
    if not f then return end
    for line in f:lines() do
        local ws, rest = line:match("^(%d+)%s+(.+)$")
        local list = rest and parse(rest)
        if list then ratios[tonumber(ws)] = list end
    end
    f:close()
end

local function saveWindows()
    local f = io.open(windowsFile, "w")
    if not f then return end
    for ws, cols in pairs(columnsOf) do
        local parts = {}
        for i, col in ipairs(cols) do parts[i] = table.concat(col, ",") end
        f:write(ws, " ", table.concat(parts, "|"), "\n")
    end
    f:close()
end

local function loadWindows()
    local f = io.open(windowsFile, "r")
    if not f then return end
    for line in f:lines() do
        local ws, rest = line:match("^(%d+)%s+(%S+)$")
        if ws then
            local cols = {}
            for part in rest:gmatch("[^|]+") do
                local col = {}
                for addr in part:gmatch("[^,]+") do col[#col + 1] = addr end
                cols[#cols + 1] = col
            end
            columnsOf[tonumber(ws)] = cols
        end
    end
    f:close()
end

local function round(x) return math.floor(x + 0.5) end

-- { 2, 1 } -> "67 · 33": the weights as rounded percentages, which set() returns
-- (so `hyprctl eval` answers with what it did).
function M.describe(list)
    local total = 0
    for _, r in ipairs(list) do total = total + r end
    local parts = {}
    for i, r in ipairs(list) do parts[i] = tostring(round(100 * r / total)) end
    return table.concat(parts, " · ")
end

-- The workspace a layout context belongs to. The context does not say, so ask
-- one of its windows.
local function workspaceOf(ctx)
    for _, t in ipairs(ctx.targets) do
        local ws = t.window and t.window.workspace
        if ws and ws.id then return ws.id end
    end
    return nil
end

-- A target's window address: what the columns remember it by. A target with
-- no window (should not happen on a tiled workspace) gets a key for this
-- pass only.
local function keyOf(t)
    if t.window and t.window.address then return t.window.address end
    return "target:" .. tostring(t.index)
end

-- How recently a window was focused: 0 is the focused one, higher is longer
-- ago; never focused sorts last.
local function recency(win)
    local id = win and win.focus_history_id
    if not id or id < 0 then return math.huge end
    return id
end

-- The column and row of the most recently focused window in `cols`, out of
-- the windows in `byKey` (address -> window). Defaults to the bottom of the
-- last column.
local function focusedSpot(cols, byKey)
    local bestC, bestR, best = #cols, #cols[#cols], math.huge
    for c, col in ipairs(cols) do
        for r, k in ipairs(col) do
            local age = recency(byKey[k])
            if age < best then bestC, bestR, best = c, r, age end
        end
    end
    return bestC, bestR
end

-- Brings the remembered columns of workspace `ws` in line with the windows it
-- has now (`targets`) and its number of slices, following the rules at the
-- top of the file. Returns the columns and address -> target.
local function reconcile(ws, targets, slices)
    local live, byKey = {}, {}
    for _, t in ipairs(targets) do
        local k = keyOf(t)
        live[k] = t
        byKey[k] = t.window
    end

    local changed = false
    local known = {}

    -- Drop windows that are gone (or listed twice), then empty columns.
    local cols = {}
    for _, col in ipairs(columnsOf[ws] or {}) do
        local kept = {}
        for _, k in ipairs(col) do
            if live[k] and not known[k] then
                kept[#kept + 1] = k
                known[k] = true
            else
                changed = true
            end
        end
        if #kept > 0 then cols[#cols + 1] = kept else changed = true end
    end

    -- Fewer slices than columns (the chord was run again): the columns that
    -- no longer fit stack into the last one.
    while #cols > slices do
        local extra = table.remove(cols)
        for _, k in ipairs(extra) do table.insert(cols[#cols], k) end
        changed = true
    end

    -- Windows the columns don't know: an empty slice if there is one. Else a
    -- window that was just opened goes below the focused window (it is not
    -- focused itself yet: Hyprland focuses it after the layout has placed it),
    -- and any other (the windows already there when a workspace switches to
    -- columns or the config reloads, which arrive one by one, or one moved in
    -- from another workspace) joins the last column.
    for _, t in ipairs(targets) do
        local k = keyOf(t)
        if not known[k] then
            known[k] = true
            changed = true
            if #cols < slices then
                cols[#cols + 1] = { k }
            elseif justOpened[k] then
                local c, r = focusedSpot(cols, byKey)
                table.insert(cols[c], r + 1, k)
            else
                table.insert(cols[#cols], k)
            end
            justOpened[k] = nil
        end
    end

    -- Empty slices while a column holds several windows: the fullest column
    -- (the leftmost, on a tie) gives up its bottom window to a new column
    -- right after it.
    while #cols < slices do
        local fullest
        for i, col in ipairs(cols) do
            if #col > 1 and (not fullest or #col > #cols[fullest]) then fullest = i end
        end
        if not fullest then break end
        table.insert(cols, fullest + 1, { table.remove(cols[fullest]) })
        changed = true
    end

    if ws then
        columnsOf[ws] = cols
        if changed then saveWindows() end
    end
    return cols, live
end

local function recalculate(ctx)
    if #ctx.targets == 0 then return end

    local ws = workspaceOf(ctx)
    local list = ratios[ws] or fallback
    local cols, live = reconcile(ws, ctx.targets, #list)

    local total = 0
    for _, r in ipairs(list) do total = total + r end

    local a = ctx.area
    local acc = 0
    for s, col in ipairs(cols) do
        -- Edges are rounded from the running total, so the slices tile the
        -- area exactly with no pixel lost to rounding. The last column takes
        -- the slices that have no window.
        local left = a.x + round(a.w * acc / total)
        acc = acc + list[s]
        local right = (s == #cols) and (a.x + a.w) or (a.x + round(a.w * acc / total))

        local rows = #col
        for r, k in ipairs(col) do
            local top    = a.y + round(a.h * (r - 1) / rows)
            local bottom = a.y + round(a.h * r / rows)
            live[k]:place({ x = left, y = top, w = right - left, h = bottom - top })
        end
    end
end

-- Re-tiles the workspace even when it is already on `layout`, which is how a
-- new set of proportions (or a moved window) takes effect.
local function useLayout(ws, layout)
    hl.workspace_rule({ workspace = tostring(ws), layout = layout })
end

-- Whether workspace `id` is on lua:columns (binds.lua moves windows with
-- M.move there).
function M.isColumns(id)
    return ratios[id] ~= nil
end

-- The monitor next to `mon` on side `dir`, the nearest if there are several.
local function monitorBeside(mon, dir)
    local function box(m)
        local s = (m.scale and m.scale > 0) and m.scale or 1
        return { x = m.x, y = m.y, w = m.width / s, h = m.height / s }
    end
    local b = box(mon)
    local best, bestGap
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= mon.name then
            local o = box(m)
            local overlapsX = o.x < b.x + b.w and o.x + o.w > b.x
            local overlapsY = o.y < b.y + b.h and o.y + o.h > b.y
            local gap
            if dir == "left" and overlapsY and o.x + o.w <= b.x then gap = b.x - (o.x + o.w)
            elseif dir == "right" and overlapsY and o.x >= b.x + b.w then gap = o.x - (b.x + b.w)
            elseif dir == "up" and overlapsX and o.y + o.h <= b.y then gap = b.y - (o.y + o.h)
            elseif dir == "down" and overlapsX and o.y >= b.y + b.h then gap = o.y - (b.y + b.h)
            end
            if gap and (not bestGap or gap < bestGap) then best, bestGap = m, gap end
        end
    end
    return best
end

-- Off the edge of the workspace: to the workspace shown on the monitor on that
-- side, if there is one.
local function moveToMonitor(win, dir)
    local mon = win.monitor
    local other = mon and monitorBeside(mon, dir)
    local ws = other and other.active_workspace
    if not ws then return end
    hl.dispatch(hl.dsp.window.move({ workspace = ws.id, follow = true }))
end

-- SUPER+SHIFT+<dir> for tiled window `win` on columns workspace `wsId`.
-- Returns false if the layout doesn't know the window (yet), so the caller
-- can fall back to Hyprland's own swap.
function M.move(win, wsId, dir)
    local cols = columnsOf[wsId]
    if not cols then return false end
    local c, r
    for ci, col in ipairs(cols) do
        for ri, k in ipairs(col) do
            if k == win.address then c, r = ci, ri end
        end
    end
    if not c then return false end
    local col = cols[c]

    if dir == "up" or dir == "down" then
        local to = (dir == "up") and r - 1 or r + 1
        if to < 1 or to > #col then
            moveToMonitor(win, dir)
            return true
        end
        col[r], col[to] = col[to], col[r]
    else
        local j = (dir == "left") and c - 1 or c + 1
        local other = cols[j]
        if not other then
            moveToMonitor(win, dir)
            return true
        end
        if #col > 1 then
            -- Into the other column, at about the height it had in this one
            -- (row r of #col has its middle at (r - 0.5) / #col).
            local at = math.floor((r - 0.5) / #col * (#other + 1)) + 1
            table.remove(col, r)
            table.insert(other, math.max(1, math.min(at, #other + 1)), win.address)
        else
            -- Alone in its column: trade places with the window there that
            -- was focused most recently.
            local byKey = {}
            for _, w in ipairs(hl.get_windows()) do
                if w.address then byKey[w.address] = w end
            end
            local pick, best = 1, math.huge
            for ri, k in ipairs(other) do
                local age = recency(byKey[k])
                if age < best then pick, best = ri, age end
            end
            col[1], other[pick] = other[pick], col[1]
        end
    end

    saveWindows()
    useLayout(wsId, M.layout)
    return true
end

-- Switch a workspace (the active one if `wsId` is nil) to `spec`: "dwindle",
-- or relative widths such as "25 50 25". Returns a short description for the
-- hint, or nil and an error.
function M.set(spec, wsId)
    local ws
    if wsId then ws = hl.get_workspace(wsId) else ws = hl.get_active_workspace() end
    if not ws or ws.special or not ws.id then
        return nil, "columns: no such regular workspace"
    end
    local id = ws.id

    if spec == "dwindle" then
        ratios[id] = nil
        columnsOf[id] = nil
        save()
        saveWindows()
        useLayout(id, "dwindle")
        return "dwindle"
    end

    local list = parse(spec)
    if not list then return nil, "columns: expected \"dwindle\" or numbers, got " .. tostring(spec) end

    ratios[id] = list
    save()
    useLayout(id, M.layout)
    return M.describe(list)
end

-- Registering a name that is already taken is silently ignored: the first
-- provider stays. So in a live session (hyprctl eval) re-requiring this file
-- does not replace the layout; only a config reload does.
hl.layout.register("columns", { recalculate = recalculate })

-- Put the workspaces chosen before the reload back on lua:columns, with their
-- windows in the columns they were in. Only ones that still exist matter, but
-- a rule for a missing one does no harm.
load()
loadWindows()
for ws in pairs(columnsOf) do
    if not ratios[ws] then columnsOf[ws] = nil end
end
for ws in pairs(ratios) do useLayout(ws, M.layout) end
-- Writes the files even when there were none, so the bar (Columns.qml) has a
-- file to watch from the start.
save()
saveWindows()

return M
