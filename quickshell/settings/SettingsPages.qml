pragma Singleton

import Quickshell

// Single source of truth for the Settings window's tabs. Drives the sidebar
// order in Settings.qml, the per-tab launcher entries in Launcher.qml, and the
// page validation done by `qs ipc call settings open <key>`.
//
// Icons are Nerd Font glyphs (Hack Nerd Font) as PUA codepoints, rendered with
// String.fromCodePoint so this source stays pure ASCII:
//   0xf028 volume-up,  0xf1eb wifi,  0xf293 bluetooth,  0xf0e7 bolt.
//
// `keywords` only feeds launcher matching — the sidebar shows `label` alone.
Singleton {
  readonly property var list: [
    { key: "audio",     label: "Audio",     codepoint: 0xf028, keywords: "sound volume output input microphone speaker sink source" },
    { key: "network",   label: "Network",   codepoint: 0xf1eb, keywords: "wifi wireless internet ssid connection" },
    { key: "bluetooth", label: "Bluetooth", codepoint: 0xf293, keywords: "bt pair devices headset headphones" },
    { key: "power",     label: "Power",     codepoint: 0xf0e7, keywords: "battery performance profile powersave balanced energy" }
  ]

  // Unknown / empty keys fall back to the first tab, so open("") is "just open".
  function indexOf(key) {
    for (let i = 0; i < list.length; i++)
      if (list[i].key === key) return i;
    return 0;
  }

  function keyAt(index) {
    return (index >= 0 && index < list.length) ? list[index].key : list[0].key;
  }
}
