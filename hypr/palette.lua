-- Basalt's base16 palette, as bare six-digit hex without a leading '#'. The
-- default for basalt.setup()'s `palette`.
--
-- theme.json at the top of the repo is the canonical copy; this file, the
-- QML defaults (HostConfig.qml), palette.conf and dunst/dunstrc repeat it, and
-- `nix flake check` fails if any of them stops agreeing.
return {
  base00 = "141817", -- canvas / deepest background
  base01 = "222725", -- panel / elevated surface / bar
  base02 = "293b35", -- hover / selection surface
  base03 = "6e7371", -- borders, accent, disabled
  base04 = "959998", -- muted foreground
  base05 = "cdd0cf", -- secondary foreground
  base06 = "e1e3e2", -- emphasis foreground
  base07 = "f2f4f3", -- default / brightest text

  base08 = "ff615d", -- red
  base09 = "e5801a", -- orange
  base0A = "bd9903", -- yellow
  base0B = "39ba5a", -- green
  base0C = "20b1bf", -- cyan
  base0D = "579ff9", -- blue
  base0E = "ce74dc", -- purple
  base0F = "ca8b7f", -- brown
}
