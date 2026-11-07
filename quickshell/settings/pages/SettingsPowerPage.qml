import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.basalt.theme

// Power page of the Settings window: the first thing in this config to actually
// use power-profiles-daemon, when the host runs it.
// Profiles are read from and written straight to the PowerProfiles singleton — no
// powerprofilesctl subprocess needed. The battery card binds to UPower's display
// device and hides itself entirely on a desktop with no battery.
//
// Session actions (lock / sleep / logout / restart / shutdown) deliberately live
// only in PowerMenu.qml and the launcher, both fed from PowerActions.qml — a
// settings window is the wrong place to put a shutdown button.
FocusScope {
  id: root

  property bool active: false
  signal backToNav()

  function focusFirst() { list.forceActiveFocus(); }

  readonly property var profiles: {
    var out = [
      { value: PowerProfile.PowerSaver, label: "Power Saver",
        desc: "Lowest power draw and fan noise", codepoint: 0xf06c },   // leaf
      { value: PowerProfile.Balanced,   label: "Balanced",
        desc: "Clocks scale with demand (default)", codepoint: 0xf24e }  // balance-scale
    ];
    if (PowerProfiles.hasPerformanceProfile)
      out.push({ value: PowerProfile.Performance, label: "Performance",
                 desc: "Maximum clocks, highest power draw", codepoint: 0xf0e7 });  // bolt
    return out;
  }

  function indexOfCurrent() {
    for (let i = 0; i < profiles.length; i++)
      if (profiles[i].value === PowerProfiles.profile) return i;
    return 0;
  }
  function apply(entry) { if (entry) PowerProfiles.profile = entry.value; }

  onActiveChanged: if (active) list.currentIndex = indexOfCurrent()

  // ---- battery (laptops only) ----
  readonly property var dev: UPower.displayDevice
  readonly property bool hasBattery: dev ? dev.isLaptopBattery : false
  readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging
                                        || dev.state === UPowerDeviceState.FullyCharged)
  readonly property string stateText: {
    if (!dev) return "—";
    switch (dev.state) {
      case UPowerDeviceState.Charging:     return "Charging";
      case UPowerDeviceState.Discharging:  return "Discharging";
      case UPowerDeviceState.FullyCharged: return "Full";
      default:                             return "—";
    }
  }
  readonly property string timeText: {
    if (!dev) return "";
    var s = charging ? dev.timeToFull : dev.timeToEmpty;
    if (!s || s <= 0) return "";
    var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    return (charging ? "Full in " : "Empty in ") + h + "h " + m + "m";
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Theme.space4

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: "\uf0e7  Power"   // bolt
        color: Theme.fgEmphasis
        font.family: Theme.fontGlyph
        font.pixelSize: Theme.textTitle
        font.weight: Theme.weightBold
      }
      Item { Layout.fillWidth: true }
      Text {
        text: UPower.onBattery ? "on battery" : "on AC"
        color: Theme.fgMuted
        font.family: Theme.fontUi
        font.pixelSize: Theme.textMicro
      }
    }

    Text {
      Layout.fillWidth: true
      text: "Performance profile"
      color: Theme.fgMuted
      font.family: Theme.fontUi
      font.pixelSize: Theme.textMicro
      font.weight: Theme.weightMedium
    }

    ListView {
      id: list
      Layout.fillWidth: true
      Layout.preferredHeight: contentHeight
      interactive: false
      model: root.profiles
      spacing: Theme.space2
      currentIndex: 0
      focus: true
      keyNavigationEnabled: false

      function move(d) {
        if (count === 0) return;
        currentIndex = Math.max(0, Math.min(count - 1, currentIndex + d));
      }

      Keys.onEscapePressed: root.backToNav()
      Keys.onDownPressed:   (e) => { list.move(1); e.accepted = true; }
      Keys.onUpPressed:     (e) => { list.move(-1); e.accepted = true; }
      Keys.onLeftPressed:   (e) => { root.backToNav(); e.accepted = true; }
      Keys.onReturnPressed: (e) => { root.apply(root.profiles[list.currentIndex]); e.accepted = true; }
      Keys.onEnterPressed:  (e) => { root.apply(root.profiles[list.currentIndex]); e.accepted = true; }
      Keys.onSpacePressed:  (e) => { root.apply(root.profiles[list.currentIndex]); e.accepted = true; }

      delegate: Rectangle {
        id: prow
        required property int index
        required property var modelData
        readonly property bool current: list.currentIndex === index && root.activeFocus
        readonly property bool selected: PowerProfiles.profile === modelData.value

        width: list.width
        height: 54
        radius: Theme.radiusMd
        color: current || phover.hovered ? Theme.bgSurfaceHover
             : selected ? Theme.accentTintSoft : "transparent"
        border.width: 1
        border.color: current ? Theme.borderFocus : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.space5
          anchors.rightMargin: Theme.space5
          spacing: Theme.space5

          Text {
            text: String.fromCodePoint(prow.modelData.codepoint)
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textTitle
            color: prow.selected ? Theme.accentPrimary : Theme.fgMuted
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              text: prow.modelData.label
              color: Theme.fgPrimary
              font.family: Theme.fontUi
              font.pixelSize: Theme.textLabel
              font.weight: prow.selected ? Theme.weightMedium : Theme.weightRegular
            }
            Text {
              Layout.fillWidth: true
              text: prow.modelData.desc
              elide: Text.ElideRight
              color: Theme.fgMuted
              font.family: Theme.fontUi
              font.pixelSize: Theme.textMicro
            }
          }
          Text {
            visible: prow.selected
            text: "\uf00c"   // check
            color: Theme.accentSuccess
            font.family: Theme.fontGlyph
            font.pixelSize: Theme.textCaption
          }
        }

        HoverHandler { id: phover }
        TapHandler {
          onTapped: {
            list.currentIndex = prow.index;
            list.forceActiveFocus();
            root.apply(prow.modelData);
          }
        }
      }
    }

    // ---- daemon caveats ----
    Text {
      Layout.fillWidth: true
      visible: text.length > 0
      text: PowerProfiles.degradationReason ? "Performance degraded: " + PowerProfiles.degradationReason : ""
      wrapMode: Text.WordWrap
      color: Theme.accentWarning
      font.family: Theme.fontUi
      font.pixelSize: Theme.textMicro
    }
    Repeater {
      model: PowerProfiles.holds || []
      delegate: Text {
        required property var modelData
        Layout.fillWidth: true
        text: "Held on " + PowerProfile.toString(modelData.profile)
              + " by " + (modelData.applicationId || "an application")
              + (modelData.reason ? ": " + modelData.reason : "")
        wrapMode: Text.WordWrap
        color: Theme.fgMuted
        font.family: Theme.fontUi
        font.pixelSize: Theme.textMicro
      }
    }

    // ---- battery (hidden on desktops) ----
    Rectangle {
      Layout.fillWidth: true
      Layout.topMargin: Theme.space4
      visible: root.hasBattery
      implicitHeight: batteryCol.implicitHeight + Theme.space5 * 2
      radius: Theme.radiusLg
      color: Theme.bgSurface

      ColumnLayout {
        id: batteryCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.space5
        anchors.rightMargin: Theme.space5
        spacing: Theme.space2

        Text {
          text: "Battery"
          color: Theme.fgEmphasis
          font.family: Theme.fontUi
          font.pixelSize: Theme.textLabel
          font.weight: Theme.weightBold
        }
        Text {
          text: (root.dev ? Math.round(root.dev.percentage * 100) : 0) + "%  ·  " + root.stateText
          color: Theme.fgSecondary
          font.family: Theme.fontUi
          font.pixelSize: Theme.textCaption
        }
        Text {
          visible: root.timeText.length > 0
          text: root.timeText
          color: Theme.fgMuted
          font.family: Theme.fontUi
          font.pixelSize: Theme.textCaption
        }
        Text {
          visible: root.dev && root.dev.healthSupported
          text: "Health " + (root.dev ? Math.round(root.dev.healthPercentage) : 0) + "%"
          color: Theme.fgMuted
          font.family: Theme.fontUi
          font.pixelSize: Theme.textCaption
        }
      }
    }

    Item { Layout.fillHeight: true }
  }
}
