pragma Singleton

import QtQuick
import Quickshell
import qs

// Shared design-system theme. This is the single source of truth for
// colors/radii/type across the quickshell bar AND every widget (launcher, power
// menu, emoji picker, workspace chord, settings) — no component hardcodes a hex.
//
// NOT STANDALONE: the raw colours and font names are the host's, from
// Host.palette and Host.fonts (HostConfig.qml has the defaults), so this file
// has no literal palette values of its own. Everything *derived* — the
// semantic roles, the scales, the bar metrics — lives here, and is edited here.
//
// The chrome is deliberately monochrome: the accent is base03, a neutral grey,
// not one of the hues. Only genuinely semantic states (danger/success/warning/
// info) reach for a hue.
//
// Follows the same pragma-Singleton pattern as PowerActions.qml, so it is usable
// by type name (`Theme.accentPrimary`) anywhere in the config.
Singleton {
  function hex(name: string): color { return "#" + Host.palette[name]; }

  // ---- base16 ramp: greys, dark -> light ----
  readonly property color base00: hex("base00")  // canvas / deepest background
  readonly property color base01: hex("base01")  // panel / elevated surface / bar
  readonly property color base02: hex("base02")  // hover / selection surface
  readonly property color base03: hex("base03")  // borders, accent, disabled
  readonly property color base04: hex("base04")  // muted foreground
  readonly property color base05: hex("base05")  // secondary foreground
  readonly property color base06: hex("base06")  // emphasis foreground
  readonly property color base07: hex("base07")  // default / brightest text

  // ---- base16 ramp: hues ----
  readonly property color base08: hex("base08")  // red
  readonly property color base09: hex("base09")  // orange
  readonly property color base0A: hex("base0A")  // yellow
  readonly property color base0B: hex("base0B")  // green
  readonly property color base0C: hex("base0C")  // cyan
  readonly property color base0D: hex("base0D")  // blue
  readonly property color base0E: hex("base0E")  // purple
  readonly property color base0F: hex("base0F")  // brown

  // ---- hue aliases (kept so existing call sites keep working) ----
  readonly property color red:     base08
  readonly property color orange:  base09
  readonly property color yellow:  base0A
  readonly property color green:   base0B
  readonly property color cyan:    base0C
  readonly property color blue:    base0D
  readonly property color purple:  base0E
  readonly property color magenta: base0F

  // ---- semantic surfaces ----
  readonly property color bgCanvas:       base00
  readonly property color bgSurface:      base01
  readonly property color bgSurfaceHover: base02
  // glass panels: near-opaque per current DS — base01 @ 95%, base00 @ 97%.
  // The rice reads as solid high-contrast chrome.
  readonly property color bgGlass:        Qt.alpha(base01, 0xf2 / 255)
  readonly property color bgGlassStrong:  Qt.alpha(base00, 0xf7 / 255)
  // Pure black scrim — not a palette tone, so it stays a literal here.
  readonly property color bgScrim:        "#8c000000"

  // Opaque surface for the bar and ALL popups/overlays — the shell chrome is
  // fully non-transparent by preference (no glass/blur). Matches barBackground;
  // elevation is carried by borderSubtle rather than a tone step.
  readonly property color popupBackground: base01

  // ---- borders ----
  readonly property color borderSubtle: Qt.alpha(base02, 0xb3 / 255)  // base02 @ 70%
  readonly property color borderStrong: base03
  readonly property color borderFocus:  base03

  // ---- text ----
  readonly property color fgMuted:     base04
  readonly property color fgSecondary: base05
  // Default body text is base07 (base06 and base07 are near-identical in this
  // scheme, so fgPrimary/fgEmphasis intentionally collapse onto the same tone).
  readonly property color fgPrimary:   base07
  readonly property color fgEmphasis:  base07
  // Light-on-accent: base03 is a mid grey, so dark text on it only reaches ~3.9:1
  // while base07 reaches ~4.9:1.
  readonly property color fgOnAccent:  base07
  readonly property color fgDisabled:  base03

  // ---- accents / semantic ----
  // The accent is a neutral grey (base03), not a hue — the chrome is monochrome
  // and only the semantic states below carry colour.
  readonly property color accentPrimary:       base03
  readonly property color accentPrimaryHover:  Qt.lighter(base03, 1.18)
  readonly property color accentPrimaryActive: Qt.darker(base03, 1.18)
  readonly property color accentSuccess: green
  readonly property color accentWarning: yellow
  readonly property color accentDanger:  red
  readonly property color accentInfo:    cyan
  // translucent focus ring (base03 @ 55%)
  readonly property color accentFocusRing: Qt.alpha(base03, 0x8c / 255)
  // subtle accent tint for hover/visible states (base03 @ ~16% / 25%)
  readonly property color accentTintSoft: Qt.alpha(base03, 0x29 / 255)
  readonly property color accentTintHover: Qt.alpha(base03, 0x40 / 255)

  // ---- workspace / tag pip colors (in order) ----
  readonly property var pips: [blue, purple, green, orange, cyan]

  // Severity tone for a 0-100 utilisation readout — the same shape as the
  // threshold ramp in Battery.qml, but shared because CPU, memory and their
  // per-core meters must all agree on where "busy" turns into "pegged".
  // Lives here rather than in the modules because the thresholds are a design
  // decision, not a fact about /proc.
  function loadTone(pct: int): color {
    return pct >= 90 ? accentDanger
         : pct >= 75 ? accentWarning
         : fgSecondary;
  }

  // ---- radii — pop-brutalist: tight, near-square corners (current DS) ----
  readonly property int radiusSm:   2
  readonly property int radiusMd:   3
  readonly property int radiusLg:   4
  readonly property int radiusXl:   6
  readonly property int radiusPill: 999

  // ---- spacing (4px scale) ----
  readonly property int space1: 2
  readonly property int space2: 4
  readonly property int space3: 6
  readonly property int space4: 8
  readonly property int space5: 12
  readonly property int space6: 16
  readonly property int space7: 20
  readonly property int space8: 24

  // ---- type scale (desktop-shell sizes) ----
  readonly property int textMicro:   11
  readonly property int textCaption: 12
  readonly property int textLabel:   13
  readonly property int textBody:    14
  readonly property int textTitle:   17
  readonly property int textTitleLg: 22
  readonly property int textDisplay: 56

  // ---- weights — shifted heavier per current DS (regular=medium, emphasis=demibold) ----
  readonly property int weightRegular: Font.Medium
  readonly property int weightMedium:  Font.DemiBold
  readonly property int weightBold:    Font.Bold

  // ---- fonts ----
  // Two faces split by role (current DS): the UI face is used for all
  // labels/prose/readouts AND the clock; the mono face is scoped only to
  // genuinely mono content (terminal-style output); the glyph face is kept
  // for the Nerd Font icons the widgets render (power codepoints, etc.).
  readonly property string fontUi:    Host.fonts.ui
  readonly property string fontMono:  Host.fonts.mono
  readonly property string fontGlyph: Host.fonts.glyph
  // Back-compat alias — existing references default to the UI face; migrate the
  // glyph call sites to fontGlyph explicitly.
  readonly property string fontFamily: fontUi

  // ---- bar ----
  readonly property int barHeight: 34
  // Opaque base01 — the panel tone, sitting one step above the base00 canvas
  // showing through as wallpaper.
  readonly property color barBackground: base01
}
