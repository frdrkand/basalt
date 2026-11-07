-- Yazi init.lua — vanilla, built-in Lua API only (no external plugins).
-- Adds a persistent "? help" hint to the right of the status line so the
-- Help overlay is discoverable. Press ? or F1 in Yazi for the full keybind list.

Status:children_add(function()
	return ui.Line({
		ui.Span(" ? "):fg("#f2f4f3"):bg("#6e7371"):bold(),
		ui.Span(" help "):fg("#cdd0cf"):bg("#222725"),
	})
end, 500, Status.RIGHT)
