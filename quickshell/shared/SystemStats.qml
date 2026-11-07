pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Single source of truth for CPU and memory load, shared by the two bar modules
// (Cpu.qml and Memory.qml).
//
// A singleton because Bar.qml is a Variants over Quickshell.screens, so there is
// one pill per monitor and a timer living inside the widget would sample /proc
// once per output. The reason that matters is not the cost — it is that these
// numbers are *derived from the interval between samples*, so two widgets ticking
// at different moments would compute genuinely different percentages from the same
// machine. Updates.qml polls per monitor and is right to: it reads an answer
// someone else already computed, and every copy of it reads the same one.
//
// Quickshell 0.3.0 ships no system-resource service, so the numbers come straight
// from procfs. Three FileViews rather than shelling out to top/free: reading three
// small files every couple of seconds is close to free, where a process spawn on a
// 2 s timer is not.
//
// watchChanges is deliberately absent. procfs is synthesised on read and emits no
// inotify events, so there is nothing to watch — the timer IS the mechanism here,
// not a fallback for something that could have been event-driven.
Singleton {
  id: root

  // ---- cpu ----
  property int cpuPct: 0
  property var coreLoads: []              // per-core percentages, cpu0 first
  readonly property int coreCount: coreLoads.length

  property real load1: 0
  property real load5: 0
  property real load15: 0

  readonly property string loadText:
    load1.toFixed(2) + "  " + load5.toFixed(2) + "  " + load15.toFixed(2)

  // ---- memory (kB, as procfs reports it) ----
  property int memTotalKb: 0
  property int memAvailableKb: 0
  property int cachedKb: 0
  property int swapTotalKb: 0
  property int swapFreeKb: 0

  // "Used" is total minus available rather than total minus free: free counts
  // reclaimable page cache as in use, which on a long-running session reads as
  // 90%+ and means nothing. MemAvailable is the kernel's own estimate of what a
  // new allocation could actually get, and is what the gauge should track.
  readonly property int memUsedKb: Math.max(0, memTotalKb - memAvailableKb)
  readonly property int memPct: memTotalKb > 0 ? Math.round(100 * memUsedKb / memTotalKb) : 0

  readonly property int swapUsedKb: Math.max(0, swapTotalKb - swapFreeKb)
  readonly property int swapPct: swapTotalKb > 0 ? Math.round(100 * swapUsedKb / swapTotalKb) : 0
  // Swapless hosts report SwapTotal: 0; every swap readout is gated on this
  // rather than showing a permanent "0 / 0".
  readonly property bool hasSwap: swapTotalKb > 0

  function fmtGiB(kb: int): string {
    return (kb / 1048576).toFixed(1) + " GiB";
  }

  // ---- /proc/stat ----
  //
  // The counters are monotonic totals since boot, so a percentage only exists
  // between two samples: what fraction of the jiffies that elapsed since last
  // tick were not idle. The first sample therefore has nothing to divide by and
  // leaves the readouts at 0 — the real numbers appear one interval in.
  property var prevTotals: []
  property var prevIdles: []

  function applyStat(text: string) {
    const lines = text.split("\n");
    const totals = [];
    const idles = [];

    for (let i = 0; i < lines.length; i++) {
      // The cpu lines lead the file; the first non-cpu line ends them.
      if (lines[i].indexOf("cpu") !== 0)
        break;

      const f = lines[i].trim().split(/\s+/);
      // user nice system idle iowait irq softirq steal — guest and guest_nice
      // are left out because they are already counted inside user and nice.
      let total = 0;
      for (let j = 1; j <= 8 && j < f.length; j++)
        total += parseInt(f[j], 10);

      totals.push(total);
      idles.push(parseInt(f[4], 10) + (f.length > 5 ? parseInt(f[5], 10) : 0));
    }

    // A core coming online or going offline changes the line count; skip that one
    // tick rather than diffing against a differently-shaped sample.
    if (totals.length > 0 && root.prevTotals.length === totals.length) {
      const pcts = [];
      for (let k = 0; k < totals.length; k++) {
        const dTotal = totals[k] - root.prevTotals[k];
        const dIdle = idles[k] - root.prevIdles[k];
        const pct = dTotal > 0 ? Math.round(100 * (1 - dIdle / dTotal)) : 0;
        pcts.push(Math.max(0, Math.min(100, pct)));
      }
      // Index 0 is the aggregate `cpu` line, the rest are cpu0..cpuN.
      root.cpuPct = pcts[0];
      root.coreLoads = pcts.slice(1);
    }

    root.prevTotals = totals;
    root.prevIdles = idles;
  }

  // ---- /proc/meminfo ----
  function applyMem(text: string) {
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const c = lines[i].indexOf(":");
      if (c < 0)
        continue;

      const key = lines[i].substring(0, c);
      // parseInt stops at the trailing " kB", so the value needs no further cleanup.
      const val = parseInt(lines[i].substring(c + 1).trim(), 10);
      if (isNaN(val))
        continue;

      switch (key) {
      case "MemTotal":     root.memTotalKb = val; break;
      case "MemAvailable": root.memAvailableKb = val; break;
      case "Cached":       root.cachedKb = val; break;
      case "SwapTotal":    root.swapTotalKb = val; break;
      case "SwapFree":     root.swapFreeKb = val; break;
      default: break;
      }
    }
  }

  // ---- /proc/loadavg ----
  function applyLoad(text: string) {
    const f = text.trim().split(/\s+/);
    if (f.length < 3)
      return;
    root.load1 = parseFloat(f[0]);
    root.load5 = parseFloat(f[1]);
    root.load15 = parseFloat(f[2]);
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    printErrors: false
    onLoaded: root.applyStat(statFile.text())
  }

  FileView {
    id: memFile
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: root.applyMem(memFile.text())
  }

  FileView {
    id: loadFile
    path: "/proc/loadavg"
    printErrors: false
    onLoaded: root.applyLoad(loadFile.text())
  }

  function refresh() {
    statFile.reload();
    memFile.reload();
    loadFile.reload();
  }

  // One timer for all three, so the readouts always describe the same moment.
  // 2 s is slow enough to be unnoticeable work and fast enough that the bar
  // reacts while a build is ramping up.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()
}
