import Quickshell
import Quickshell.Io
import qs.basalt.bar
import qs.basalt.overlays
import qs.basalt.settings
import qs.basalt.updates

// Basalt's shell: the bar, the overlays and windows, and the IPC targets
// Hyprland drives them through (`qs ipc call <target> <fn>`). A host's
// shell.qml places it, beside anything of its own:
//
//   import Quickshell
//   import qs.basalt
//
//   ShellRoot {
//     Basalt {}
//   }
//
// The on-demand widgets are hidden until toggled.
Scope {
  // Persistent top status bar (one per monitor). The toplevels below are passed
  // in so the bar's modules open them directly, with no IPC hop.
  Bar { powerMenu: powerMenuOverlay; settings: settingsWindow; updates: updatesWindow }

  PowerMenu { id: powerMenuOverlay }
  Launcher { id: launcher; settings: settingsWindow }
  EmojiPicker { id: emojiPicker }
  WorkspaceChord { id: wsChord }
  TilingChord { id: tilingChord }

  // Standalone Settings window (audio / network / bluetooth / power). Unlike the
  // widgets above it is a real toplevel, not an overlay — the bar's "Manage …"
  // buttons and the launcher's settings entries open it on a specific tab.
  Settings { id: settingsWindow }

  // Details for the bar's Updates module. Also a toplevel, and also instantiated
  // here rather than inside the module: Bar is a Variants over the screens, so a
  // window owned by the pill would be one window per monitor.
  UpdatesWindow { id: updatesWindow }

  IpcHandler {
    target: "powermenu"
    function toggle(): void { powerMenuOverlay.toggle() }
    function open(): void { powerMenuOverlay.open() }
    function close(): void { powerMenuOverlay.close() }
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { launcher.toggle() }
    function open(): void { launcher.open() }
    function close(): void { launcher.close() }
  }

  IpcHandler {
    target: "emoji"
    function toggle(): void { emojiPicker.toggle() }
    function open(): void { emojiPicker.open() }
    function close(): void { emojiPicker.close() }
  }

  // `qs ipc call settings open network` — an empty/unknown page opens the first tab.
  IpcHandler {
    target: "settings"
    function toggle(): void { settingsWindow.toggle() }
    function open(page: string): void { settingsWindow.open(page) }
    function close(): void { settingsWindow.close() }
  }

  // `qs ipc call updates open` — the details window, as the bar's pill opens it.
  IpcHandler {
    target: "updates"
    function toggle(): void { updatesWindow.toggle() }
    function open(): void { updatesWindow.open() }
    function close(): void { updatesWindow.close() }
  }

  // Workspace chord hint. Shown by the Hyprland switch/move submaps and hidden
  // when the chord resolves or is cancelled.
  IpcHandler {
    target: "wschord"
    function showSwitch(monitor: string): void { wsChord.showSwitch(monitor) }
    function showMove(monitor: string): void { wsChord.showMove(monitor) }
    function hide(): void { wsChord.hide() }
  }

  // Tiling chord popup, driven by the Hyprland "tiling" submap. `seq` orders
  // the calls (see TilingChord.qml); digits are one word ("121"), "" for none.
  IpcHandler {
    target: "tiling"
    function start(seq: int): void { tilingChord.start(seq) }
    function update(seq: int, digits: string): void { tilingChord.update(seq, digits) }
    function applied(seq: int, digits: string): void { tilingChord.applied(seq, digits) }
    function dwindle(seq: int): void { tilingChord.dwindle(seq) }
    function failed(seq: int, message: string): void { tilingChord.failed(seq, message) }
    function hide(seq: int): void { tilingChord.hide(seq) }
  }
}
