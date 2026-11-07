-- `g m`: go to where removable media is mounted, which is not the same place
-- everywhere: udisks mounts under /run/media/$USER (NixOS, most distros), and
-- Ubuntu and Debian put it under /media/$USER. The first that exists wins.
return {
	entry = function()
		local user = os.getenv("USER") or ""
		for _, dir in ipairs({ "/run/media/" .. user, "/media/" .. user, "/run/media", "/media" }) do
			if fs.cha(Url(dir)) then
				return ya.emit("cd", { dir })
			end
		end
	end,
}
