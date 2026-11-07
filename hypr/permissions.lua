-- Screencopy permissions. Under `enforce_permissions` every binary that captures
-- the screen needs naming. These are the nix-built ones, matched as patterns on
-- their store paths (the hashes change on every rebuild or upgrade). A host with
-- a capturing program from elsewhere adds an hl.permission for it, by its
-- binary path, after basalt.setup().
--
-- The patterns are RE2, matched with FullMatch against the requesting process'
-- binary path. RE2 gives `%` no special meaning, so a literal dot has to be
-- written `[.]` — a rule that matches nothing silently falls through to a
-- permission dialog rather than failing.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Permission changes need a Hyprland restart; they are not applied on reload.

hl.config({
  ecosystem = {
    enforce_permissions = true,
  },
})

-- Screen sharing (Slack huddles, browser calls) goes through the portal.
hl.permission({ binary = "/nix/store/[a-z0-9]{32}-xdg-desktop-portal-hyprland-[0-9.]*/libexec/[.]xdg-desktop-portal-hyprland-wrapped", type = "screencopy", mode = "allow" })
hl.permission({ binary = "/nix/store/[a-z0-9]{32}-grim-[0-9.]*/bin/grim", type = "screencopy", mode = "allow" })
-- hyprlock's blurred background captures the screen via screencopy.
hl.permission({ binary = "/nix/store/[a-z0-9]{32}-hyprlock-[0-9.]*/bin/hyprlock", type = "screencopy", mode = "allow" })
