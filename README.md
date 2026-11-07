# Basalt

A Hyprland desktop: the compositor config, a quickshell shell (bar, launcher,
power menu, emoji picker, settings and updates windows), and the hypr* tools
and notifications styled to match. One base16 palette and one design system
across all of it: dark, monochrome chrome, near-square corners, colour only
where something means something.

Basalt is the shared part of a desktop that runs on more than one machine. A
machine (a *host*) keeps only what is actually its own: its monitors, its
commands, how it checks for updates, any bar items or binds of its own. It
uses Basalt from plain files, or from Nix.

## What's in it

```
hypr/            Hyprland's Lua config, as modules: require("basalt").setup{…}
  init.lua         the entry point
  config.lua       every option, with its default
  display.lua      monitors and workspaces, declared or derived
  binds.lua        every keybind, with an index of what is taken
  columns.lua      the column layouts (SUPER+T)
  …                programs, input, look-and-feel, rules, colors, permissions, misc
  palette.lua      the palette, for Lua
  palette.conf     the palette, as hyprlang variables
  hyprlock.conf    the lock screen's look
  hypridle.conf    the lock path and sleep hook
  hyprpaper.conf   one wallpaper on every monitor
  wallpaper.svg    the wallpaper, and wallpaper.png / lockscreen.png rendered from it
quickshell/      the shell, imported as qs.basalt
  Basalt.qml       the entry point: bar, overlays, windows, IPC
  HostConfig.qml   everything a host can set, with its default
  bar/ overlays/ settings/ shared/ theme/ updates/ data/
dunst/dunstrc    notifications
bin/             basalt-screenshot, basalt-dpms
theme.json       the palette and fonts: the canonical copy
nix/             the Nix builders and checks
examples/        a host's side of everything, minimal
```

## Using it

Every piece follows the same rule: Basalt's file holds what is shared, and the
host's own file says what is not, then includes Basalt's.

| Piece | Host's file | Includes Basalt by |
|---|---|---|
| Hyprland | `~/.config/hypr/hyprland.lua` | `require("basalt").setup{…}`, with Basalt at `~/.config/hypr/basalt` |
| quickshell | `~/.config/quickshell/shell.qml`, `Host.qml` | `import qs.basalt`, with Basalt at `~/.config/quickshell/basalt` |
| hyprlock | `~/.config/hypr/hyprlock.conf` | `source = ./basalt/palette.conf` and `./basalt/hyprlock.conf` |
| hypridle | `~/.config/hypr/hypridle.conf` | `source = ./basalt/hypridle.conf` |
| hyprpaper | `~/.config/hypr/hyprpaper.conf` | `$wallpaper = …`, then `source = ./basalt/hyprpaper.conf` |
| dunst | `~/.config/dunst/dunstrc.d/*.conf` | `~/.config/dunst/dunstrc` *is* Basalt's |
| scripts | — | `basalt-screenshot` and `basalt-dpms` on `PATH` |

`examples/` has each of the host's files.

The mount points are fixed: Basalt's Lua is required as `basalt`, and its QML
imports itself as `qs.basalt`, so each sits at `basalt/` in its config
directory.

### From plain files

Clone Basalt (a git submodule pins a revision) and link it in:

```sh
ln -s ~/src/basalt/hypr          ~/.config/hypr/basalt
ln -s ~/src/basalt/quickshell    ~/.config/quickshell/basalt
ln -s ~/src/basalt/dunst/dunstrc ~/.config/dunst/dunstrc
ln -s ~/src/basalt/bin/basalt-screenshot ~/src/basalt/bin/basalt-dpms ~/.local/bin/
```

then copy the host's files from `examples/` and make them yours. Edits to
Basalt's files are edits to the clone; the host's files are yours.

What has to be installed: Hyprland 0.55 or later (the Lua config), quickshell
0.2 or later (`qs.` imports), hypridle, hyprlock, hyprpaper and dunst, and what
the shell and scripts call: grim, slurp, satty, jq, wl-clipboard, wtype,
playerctl, brightnessctl, qalc, hyprshutdown, hyprpwcenter, nmcli and
bluetoothctl. The fonts are Onest and Hack Nerd Font.

### From Nix

The flake's `lib` builds each piece in the store from a host's settings, so
nothing under `~/.config` is involved. It wraps and installs nothing: hand the
results to whatever the host already uses to start Hyprland and the rest.

```nix
{ inputs, pkgs, ... }:
let
  basalt = inputs.basalt.lib;
  hyprland = basalt.hyprlandConfig {
    inherit pkgs;
    settings = {
      display.outputs = [
        { name = "DP-1"; mode = "2560x1440@60"; position = "0x0"; }
      ];
      autostart = [ "hyprpaper" "hypridle" "dunst" ];
    };
  };
  shell = basalt.quickshellConfig {
    inherit pkgs;
    settings.updatesStatus = [ "snout" "has-updates" "--json" ];
  };
in
{
  # Hyprland --config ${hyprland}/hyprland.lua
  # quickshell --path ${shell}
}
```

| Builder | Makes |
|---|---|
| `hyprlandConfig { pkgs, settings, extraConfig }` | a directory with `hyprland.lua` and `basalt/`; `settings` are `setup()`'s options, `extraConfig` is Lua run after it |
| `quickshellConfig { pkgs, settings, host, shell, extraFiles }` | a directory for `quickshell --path`; `settings` become `Host.qml`, or pass a `host` file of your own |
| `hyprlockConf`, `hypridleConf`, `hyprpaperConf` | the complete file, sourcing Basalt's from the store, then `extraConfig` |
| `dunstrc { pkgs, palette, fonts, extraConfig }` | the complete file for `dunst -config`, recoloured |
| `wallpaper { pkgs, palette, width, height }` | the wallpaper PNG, in any palette and size |
| `scripts { pkgs }` | `basalt-screenshot` and `basalt-dpms`, with their dependencies |
| `verifyHyprland`, `lintQuickshell { pkgs, config }` | checks for a host's own `nix flake check` |
| `theme` | the default palette and fonts (`theme.json`) |

Every builder takes the host's `pkgs`, so Basalt pins no nixpkgs of its own.

## Configuring

### Hyprland

`basalt.setup()` takes the options in [`hypr/config.lua`](hypr/config.lua),
each with its default and what it does:

- **`display`** — the monitors. *Declared* (`outputs`, in layout order, each
  with a mode, a position, a scale and a workspace count), or *derived* from
  what is connected: the built-in panel first, then the rest by connector
  name, reloading the config whenever one comes or goes. Either way the order
  is the monitor number in the SUPER+⟨n⟩ chords, and the order workspace ids
  are handed out in.
- **`programs`** — the terminal, the file manager, the screenshot command, and
  how quickshell is started (`shell`) and messaged (`shellIpc`).
- **`autostart`** — what starts with the session, before the shell: command
  lines, or Lua functions (to set the environment the commands after them
  inherit).
- **`palette`**, **`keyboard`**, **`touchpad`**.

Anything else is the host's Lua after `setup()`. A setting set again wins,
binds and rules add up, and `hl.unbind` frees a key Basalt took.

Each part is a module of its own, so a terminal can reach one:

```sh
hyprctl eval 'require("basalt.columns").set("40 35 25")'
```

### The shell

`Host.qml` derives from [`HostConfig.qml`](quickshell/HostConfig.qml), which
lists everything a host can set: the palette and fonts, the launcher's ignored
apps and how it starts an application (`launchCommand`, or override
`launch(entry)`), the three updates commands, and `barItems`, components of
the host's own placed in the bar before the tray. `shell.qml` places
`Basalt {}` beside anything else of the host's.

The bar reads the monitor layout Hyprland settled on, from a state file
`display.lua` writes at every config load
(`$XDG_RUNTIME_DIR/basalt-display.state`), so the shell never repeats the
ordering rule.

### The palette

`theme.json` is the canonical palette and font set. It is repeated in each
config's own syntax (`palette.lua`, `palette.conf`, `HostConfig.qml`,
`dunstrc`), and `nix flake check` fails if any of them stops agreeing. A host
with a palette of its own passes it to `setup()` and `Host.qml`, sources its
own `palette.conf` in `hyprlock.conf`, and (from Nix) gets a recoloured
`dunstrc` and wallpaper.

## The updates protocol

The bar's updates pill and the details window know no package manager. The
host names commands in `Host.qml`, and each prints one JSON document on stdout:

| Property | When it runs | Prints |
|---|---|---|
| `updatesStatus` | every `updatesInterval` (10 s) | a **status** document |
| `updatesDetails` | when the popup or window opens, and while the window is shown | a **details** document |
| `updatesCheck` | the window's **Check now**; the button only exists when this is set | anything; its exit status is what counts |

[snout](https://github.com/frdrkand/snout) speaks it as
`snout has-updates --json` and `snout report --json`.

### Status

```json
{ "available": true, "busy": false, "checkedAt": "2026-08-17T06:14:11+02:00",
  "startedAt": null, "progress": null, "error": null }
```

- `available` — something has an update. **Required**: a document without it
  is a failure and is shown as one (the pill turns red, with `error` as the
  reason), never as "up to date".
- `checkedAt` — when that was last established; `null` for never, which the
  pill shows as not checked rather than up to date.
- `busy` — a check is running. `startedAt` and `progress` (a phrase: "Building
  the updated system") are optional, for the elapsed time and the popup.
- `error` — checking is failing; a string or `{ "message": … }`.

It is polled, so it must be cheap, and must not start expensive work itself.

### Details

The status fields, plus:

```json
{
  "title": "updates available",
  "count": 87,
  "notices": [ { "label": "Daemon", "text": "Idle · next check 08:14", "tone": "muted" } ],
  "parts": [
    {
      "id": "packages", "name": "Packages", "note": "81 changed, 3 added, 3 removed",
      "apply": "snout upgrade", "checkedAt": "…", "busy": false, "error": null,
      "message": "Nothing would change",
      "updates": [ { "name": "glibc", "from": "2.39", "to": "2.40", "kind": "changed", "sizeDelta": 2201600 } ]
    }
  ],
  "hint": "apply with `snout upgrade`",
  "about": "snout 0.1.0 · desktop · /etc/nixos"
}
```

- `parts` — **required**; one per thing that updates separately (apt, snaps,
  a nix profile, firmware; or a flake's inputs and its packages). Each has a
  name, a `note` beside it, the command that `apply`s it, its own `checkedAt`,
  `busy` and `error`, and the `message` shown in place of an empty list.
- `updates` — `kind` is `changed`, `added` or `removed`; `from` and `to` are
  empty for a side that does not exist. `sizeDelta` (signed bytes) is
  optional, and adds a size column when any update has one.
- `title` and `count` — the headline. Optional: without them, `count` is the
  number of updates and the title follows from the status.
- `notices` — labelled lines for the window's status panel. `tone` is
  `normal`, `muted`, `warning` or `danger`; warning and danger ones are also
  shown in the popup.
- `hint` and `about` — an optional footer and small print.

A document without `parts` is a failure: the window keeps the last good list
and shows the `error`.

## Development

```sh
nix flake check
nix fmt
```

The checks build the example host through the same builders a host uses:
`Hyprland --verify-config` on a derived and a declared layout, qmllint over
the shell (with the example's `Host.qml` and with a generated one), the
palette copies against `theme.json`, the scripts (shellcheck), the wallpaper,
and every generated `.conf`.

To try a change on a running session, point quickshell at a directory holding
a host's `shell.qml` and `Host.qml` and a `basalt` link to your checkout:
`quickshell -p <dir>`.

## License

MIT
