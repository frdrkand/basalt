# Basalt

A Hyprland desktop: the compositor config, a quickshell shell (bar, launcher,
power menu, emoji picker, settings and updates windows), the hypr* tools and
notifications, the terminal around them (kitty, zsh, starship, yazi, btop,
fastfetch, qalc) and disktree, with GTK, Qt, the fonts and the cursor themed to
match. One base16 palette and one design system across all of it: dark,
monochrome chrome, near-square corners, colour only where something means
something.

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
kitty/           the terminal
zsh/             init.zsh and finish.zsh, sourced around a host's own rc
starship/        the prompt
yazi/            the file manager, and its `g m` plugin
btop/ fastfetch/ qalculate/   the monitor, the banner, the calculator (and the launcher's maths)
disktree/        the disk usage treemap's colours (an Omarchy colors.toml)
gtk/ qt/         the palette for GTK (adw-gtk3) and Qt (qt6ct); gtk/README.md says why
fontconfig/      the default faces
applications/    folders from other programs open in nautilus (hyprland-mimeapps.list); yazi-open.desktop for "Open with"
bin/             basalt-link, basalt-gsettings, basalt-screenshot, basalt-dpms
theme.json       the palette, fonts, icons, cursor and GTK theme: the canonical copy
nix/             the NixOS module, the builders and the checks
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
| kitty | `~/.config/kitty/kitty.d/*.conf` | `~/.config/kitty/kitty.conf` *is* Basalt's |
| zsh | `~/.zshrc` | `source …/zsh/init.zsh`, the host's lines, `source …/zsh/finish.zsh` |
| starship, yazi, btop, fastfetch, qalc | — | `~/.config/starship.toml`, `~/.config/yazi/`, `~/.config/btop/btop.conf`, `~/.config/fastfetch/config.jsonc`, `~/.config/qalculate/qalc.cfg` *are* Basalt's |
| disktree | — | `~/.config/omarchy/current/theme/colors.toml` *is* Basalt's |
| GTK | — | `gtk-{3,4}.0/{gtk,colors}.css` linked into `~/.config`, and `basalt-gsettings` run once |
| Qt | — | `qt/qt6ct.conf` rendered into `~/.config/qt6ct/` with `@COLORS@` → `qt/base16.conf`, and `QT_QPA_PLATFORMTHEME=qt6ct` |
| fonts | — | `fontconfig/50-basalt.conf` in `~/.config/fontconfig/conf.d/` |
| scripts | — | `basalt-screenshot`, `basalt-dpms` (and `basalt-gsettings`) on `PATH` |

`examples/` has each of the host's files.

The mount points are fixed: Basalt's Lua is required as `basalt`, and its QML
imports itself as `qs.basalt`, so each sits at `basalt/` in its config
directory.

### From plain files

Clone Basalt (a git submodule pins a revision) and put it in place:

```sh
~/src/basalt/bin/basalt-link
```

It links every shared file and directory above into `~/.config` (and the
scripts into `~/.local/bin`), so updating Basalt is updating the clone. It
never touches the host's own files; something already at one of its paths is
replaced if it is a symlink and otherwise moved aside to `<path>.pre-basalt`.
`basalt-link --remove` takes it all out again. Then copy the host's files from
`examples/`, make them yours, and run `basalt-gsettings` once from a desktop
session.

What has to be installed: Hyprland 0.55 or later (the Lua config), quickshell
0.2 or later (`qs.` imports), hypridle, hyprlock, hyprpaper and dunst, kitty,
zsh with oh-my-zsh, zsh-autosuggestions and zsh-syntax-highlighting, starship,
yazi, btop, fastfetch, qalc, nautilus, disktree, and what the shell and scripts call:
grim, slurp, satty, jq, wl-clipboard, wtype, playerctl, brightnessctl,
hyprshutdown, hyprpwcenter, nmcli and bluetoothctl. Themes: adw-gtk3, Papirus,
Bibata, qt6ct. Fonts: Onest, Hack Nerd Font, Noto.

### From NixOS: the module

One module is the whole of it:

```nix
{
  imports = [ inputs.basalt.nixosModules.default ];

  basalt = {
    enable = true;
    display.outputs = [
      { name = "DP-1"; mode = "2560x1440@60"; position = "1920x0"; }
      { name = "HDMI-A-1"; mode = "1920x1080@60"; position = "0x100"; }
    ];
    updates = {
      status = [ "snout" "has-updates" "--json" ];
      details = [ "snout" "report" "--json" ];
    };
    shell.settings.launchCommand = [ "uwsm" "app" "--" "{id}.desktop" ];
    idle.action = "blank-when-locked";
  };
}
```

Every program is wrapped so its config comes from the store, recoloured into
`basalt.theme`, and nothing under `~/.config` is read, except GTK's and Qt's
few files, which nothing else can deliver: those are linked into `$HOME` by
systemd user tmpfiles on every switch. Hyprland starts through UWSM by default.

| Option | Default | What it does |
|---|---|---|
| `basalt.enable` | `false` | Everything below. |
| `.theme.{palette,fonts,cursor}` | Basalt's `theme.json` | The look, everywhere. |
| `.display.outputs` | `null` | Declared monitors, in layout order; null derives them from what is connected. |
| `.autostart` | hyprpaper, hypridle, dunst, hyprpolkitagent | What starts with the session, before the shell. |
| `.hyprland.{settings,extraConfig,withUWSM}` | | More `setup()` options; Lua of the host's own after it. |
| `.shell.{settings,host,extraFiles}` | | `Host.qml` properties, or a `Host.qml` of the host's own. |
| `.updates.{status,details,check}` | `[ ]` | The updates commands (see the protocol below). |
| `.idle.{action,timeout}` | `lock`, `300` | Lock after idling, blank only once locked (`blank-when-locked`), or `none`. |
| `.lock.extraConfig` | the wallpaper, frosted | hyprlock's background and auth block. |
| `.wallpaper.{width,height}` | the largest declared mode | The size the wallpaper is rendered at. |
| `.notifications.extraConfig`, `.kitty.extraConfig`, `.zsh.extraConfig` | | The host's own additions to each. |
| `.<piece>.enable` | `true` | Turn one piece off: `shellUi`, `lock`, `idle`, `wallpaper`, `notifications`, `kitty`, `starship`, `zsh`, `yazi`, `nautilus`, `gtk`, `qt`, `fonts`, `cursor`, `btop`, `fastfetch`, `qalculate`, `disktree`. |
| `.build` | read-only | The Hyprland and quickshell config directories and the wallpaper, for a host's own checks and its login screen. |

The login screen, the user's login shell and default applications (which
browser, mail) stay the host's. Folders that other programs open go to
nautilus in a Hyprland session (`applications/hyprland-mimeapps.list`);
SUPER+E is yazi.

### From Nix, piece by piece

The flake's `lib` is what the module is built from: each builder makes one
piece in the store from a host's settings, and wraps and installs nothing.

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

`theme.json` is the canonical palette, fonts, icons, cursor and GTK theme. It
is repeated in each config's own syntax (`palette.lua`, `palette.conf`,
`HostConfig.qml`, and written out literally in dunst's, kitty's, starship's,
yazi's, GTK's, Qt's and disktree's files, fontconfig and `basalt-gsettings`),
and `nix flake check` fails if any of them stops agreeing. With the NixOS module,
`basalt.theme` recolours all of it. A plain-files host with a palette of its
own passes it to `setup()` and `Host.qml` and sources its own `palette.conf`;
the literal files it would have to copy.

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

The checks build a whole NixOS system with the module (every piece on), and
the example host through the same builders: `Hyprland --verify-config` on a
derived and a declared layout and on the module's, qmllint over the shell (the
example's `Host.qml`, a generated one, the module's), the palette copies
against `theme.json`, the scripts (shellcheck), the wallpaper, and every
generated `.conf`.

To try a change on a running session, point quickshell at a directory holding
a host's `shell.qml` and `Host.qml` and a `basalt` link to your checkout:
`quickshell -p <dir>`.

## License

MIT
