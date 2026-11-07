pragma Singleton

import Quickshell

// Single source of truth for the session / power actions, shared by the power
// menu (PowerMenu.qml) and the launcher (Launcher.qml).
//
// Icons are Nerd Font glyphs (Hack Nerd Font), stored as PUA codepoints and
// rendered with String.fromCodePoint so this source stays pure ASCII:
//   0xf023 lock,  0xf186 moon,  0xf08b sign-out,  0xf021 refresh,
//   0xf011 power-off. All five come from the Font Awesome set.
//
// Order is the menu's left-to-right order and its 1-5 hotkeys, so the two
// actions the session survives come first and it escalates rightwards.
//
// `keywords` is optional and matched by the launcher only, the same shape
// SettingsPages.qml uses; it exists so "suspend" finds Sleep.
//
// Commands:
//   Lock     -> loginctl lock-session (hypridle then runs hyprlock)
//   Sleep    -> systemctl suspend
//   Logout   -> hyprshutdown -t 'Logging out...'
//   Restart  -> hyprshutdown -t 'Restarting...' -p 'reboot'
//   Shutdown -> hyprshutdown -t 'Shutting down...' -p 'shutdown -P 0'
//
// Sleep is deliberately *not* routed through hyprshutdown: that fade-out is a
// session teardown animation, and this session is coming back. Locking before
// the machine goes down is not this list's job either — hypridle owns it, and
// holds logind's sleep inhibitor until hyprlock has actually taken the screen
// (hypr/hypridle.conf).
Singleton {
  readonly property var list: [
    { key: "lock",     label: "Lock",     codepoint: 0xf023, command: ["loginctl", "lock-session"] },
    { key: "sleep",    label: "Sleep",    codepoint: 0xf186, keywords: "suspend", command: ["systemctl", "suspend"] },
    { key: "logout",   label: "Logout",   codepoint: 0xf08b, command: ["hyprshutdown", "-t", "Logging out..."] },
    { key: "restart",  label: "Restart",  codepoint: 0xf021, command: ["hyprshutdown", "-t", "Restarting...", "-p", "reboot"] },
    { key: "shutdown", label: "Shutdown", codepoint: 0xf011, command: ["hyprshutdown", "-t", "Shutting down...", "-p", "shutdown -P 0"] }
  ]
}
