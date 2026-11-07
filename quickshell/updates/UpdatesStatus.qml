pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// What the host's update commands say, for the bar's pill (Updates.qml) and
// the details window (UpdatesWindow.qml). A singleton because Bar.qml is a
// Variants over the screens: held in the pill, this would poll once per monitor.
//
// Basalt knows no package manager. The host names three commands
// (HostConfig.qml), each printing one JSON document in the formats described
// under "The updates protocol" in Basalt's README:
//
//   updatesStatus   polled for the pill: available, busy, checkedAt, error, and
//                   optionally startedAt and progress
//   updatesDetails  fetched when the popup or window opens, and polled while
//                   the window is shown: a title, notices, and the parts, each
//                   with its updates
//   updatesCheck    run by the window's "Check now"; optional
//
// A document with no `available` (or, for details, no `parts`) is a failure:
// the command could not answer, which is not the same as "nothing to update".
// Its `error` says why.
Singleton {
  id: root

  readonly property bool enabled: Host.updatesStatus.length > 0
  readonly property bool hasDetails: Host.updatesDetails.length > 0
  readonly property bool canCheck: Host.updatesCheck.length > 0

  // ---- status, polled ----
  property bool reachable: true            // false: the command gave no answer
  property bool available: false
  property bool busy: false
  property double checkedAt: 0             // ms since epoch, 0 = never checked
  property double startedAt: 0
  property string progress: ""
  property string error: ""                // checking is failing, or why there is no answer

  readonly property bool known: checkedAt > 0
  readonly property bool failed: !reachable || error.length > 0

  // ---- details, on demand ----
  property var details: null               // the last good document
  property string detailsError: ""         // the details command could not answer

  // While a details view is open it asks for details to stay fresh. A count,
  // not a flag, so the popup and the window can both hold it.
  property int watchers: 0

  // ---- check now ----
  property bool checking: false
  property string checkError: ""

  // Seconds since the running check started, ticking locally so a 10 s poll
  // still shows a counter that moves.
  property int elapsed: 0
  readonly property double runningSince: startedAt > 0 ? startedAt
    : (details && details.startedAt ? Date.parse(details.startedAt) : 0)

  function errorText(e) {
    if (!e) return "";
    if (typeof e === "string") return e;
    return e.message || "";
  }

  function stamp(ms) {
    if (ms <= 0) return "never";
    const d = new Date(ms);
    const today = d.toDateString() === new Date().toDateString();
    return Qt.formatDateTime(d, today ? "HH:mm" : "yyyy-MM-dd HH:mm");
  }

  function duration(s) {
    if (s < 60) return s + "s";
    const m = Math.floor(s / 60);
    if (m < 60) return m + "m " + (s % 60) + "s";
    return Math.floor(m / 60) + "h " + String(m % 60).padStart(2, "0") + "m";
  }

  // One line for wherever the state has to fit on a line: the popup, the
  // window's progress panel.
  readonly property string summary:
    !reachable ? "Updates unavailable"
    : (busy || checking) ? (progress || "Checking for updates") + "…"
             + (runningSince > 0 ? "  " + duration(elapsed) : "")
    : error.length > 0 ? "Checks are failing"
    : !known ? "Not checked yet"
    : available ? "Updates available"
    : "Up to date"

  function poll() {
    if (enabled && !statusProc.running) statusProc.running = true;
  }

  function loadDetails() {
    if (hasDetails && !detailsProc.running) detailsProc.running = true;
  }

  function check() {
    if (!canCheck || checkProc.running) return;
    checkError = "";
    checking = true;
    checkProc.running = true;
    // Whatever the check does to the status shows up on the next polls.
    poll();
  }

  Process {
    id: statusProc
    command: Host.updatesStatus
    stdout: StdioCollector {
      id: statusOut
      onStreamFinished: {
        try {
          const d = JSON.parse(statusOut.text || "{}");
          if (d.available === undefined) {
            // Not "no updates": nothing answered, and the last answer is not
            // worth trusting either, since nothing is keeping it current.
            root.reachable = false;
            root.error = root.errorText(d.error) || "no answer from " + Host.updatesStatus[0];
            return;
          }
          root.reachable = true;
          root.available = d.available === true;
          root.busy      = d.busy === true;
          root.checkedAt = d.checkedAt ? Date.parse(d.checkedAt) : 0;
          root.startedAt = d.startedAt ? Date.parse(d.startedAt) : 0;
          root.progress  = d.progress || "";
          root.error     = root.errorText(d.error);
        } catch (e) {
          // A partial read; the next tick fixes it. Not worth blanking the bar over.
        }
      }
    }
  }

  Process {
    id: detailsProc
    command: Host.updatesDetails
    stdout: StdioCollector {
      id: detailsOut
      onStreamFinished: {
        try {
          const d = JSON.parse(detailsOut.text || "{}");
          if (d.parts === undefined) {
            // Keep the last good list on screen; this says why it is not current.
            root.detailsError = root.errorText(d.error) || "no answer from " + Host.updatesDetails[0];
            return;
          }
          root.details = d;
          root.detailsError = "";
        } catch (e) {}
      }
    }
  }

  property string lastCheckLine: ""
  Process {
    id: checkProc
    command: Host.updatesCheck
    stderr: SplitParser { onRead: line => { if (line.trim()) root.lastCheckLine = line.trim(); } }
    onExited: code => {
      // A part that fails says so in the details. This is for the command
      // itself failing.
      if (code !== 0)
        root.checkError = root.lastCheckLine || (Host.updatesCheck[0] + " failed (exit " + code + ")");
      root.lastCheckLine = "";
      root.checking = false;
      root.poll();
      root.loadDetails();
    }
  }

  Timer {
    interval: root.checking ? 2000 : Host.updatesInterval
    running: root.enabled
    repeat: true
    onTriggered: root.poll()
  }

  // Details while something is showing them: every interval, faster while a
  // check runs so its progress keeps up.
  Timer {
    interval: (root.busy || root.checking) ? 2000 : Host.updatesInterval
    running: root.watchers > 0 && root.hasDetails
    repeat: true
    onTriggered: root.loadDetails()
  }

  Timer {
    interval: 1000
    running: (root.busy || root.checking) && root.runningSince > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: root.elapsed = Math.max(0, Math.floor((Date.now() - root.runningSince) / 1000))
  }

  // A real answer on screen the instant the shell starts, rather than a spinner.
  Component.onCompleted: poll()
}
