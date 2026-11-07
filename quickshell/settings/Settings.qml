import QtQml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.basalt.settings.pages
import qs.basalt.shared
import qs.basalt.theme

// Standalone Settings window: a real toplevel (FloatingWindow, not a layer-shell
// overlay) so it can be moved, resized and left open beside other windows. A left
// sidebar selects between the pages listed in SettingsPages; the pages themselves
// live in Settings*Page.qml and stay instantiated across tab switches, each gated
// by an `active` flag (that's what starts/stops scanning and polling).
//
// Keyboard model — the reason this window exists in the first place:
//   sidebar   Up/Down change tab, Right/Return/Tab enter the page, Esc closes
//   page      Up/Down/Return navigate rows, Esc goes back to the sidebar
//   anywhere  Ctrl+Tab / Ctrl+Shift+Tab cycle tabs, Ctrl+1..4 jump to one
// The global chords are Shortcut elements rather than Keys handlers so they fire
// even while a TextInput inside a page holds focus.
Scope {
  id: root

  property bool shown: false
  property string page: SettingsPages.list[0].key

  // The window is built on first open and then kept alive, hidden — closing it
  // only unmaps it. Destroying it would tear the pages down mid-flight, and a
  // torn-down page can't run its own cleanup (Bluetooth discovery in particular
  // kept scanning after close when the pages were destroyed).
  property bool built: false

  // open("") / open(unknown) lands on the first tab. Focus is always asked for
  // explicitly, slightly after the window maps: when we're opened from the
  // launcher, Hyprland hands keyboard focus back to whatever the layer surface
  // covered rather than to the freshly mapped toplevel, and when the window was
  // already open there is nothing to map at all.
  //
  // The dispatch string is Lua, not the classic `focuswindow …` syntax: this
  // Hyprland runs a Lua config, so dispatches go through `hl.dispatch(<expr>)`.
  function open(p) {
    if (p && p.length > 0) page = SettingsPages.keyAt(SettingsPages.indexOf(p));
    built = true;
    shown = true;
    focusTimer.restart();
  }
  function close()  { shown = false; }
  function toggle() { if (shown) close(); else open(page); }

  Timer {
    id: focusTimer
    interval: 200
    onTriggered: Hyprland.dispatch('hl.dsp.focus({ window = "title:^(Settings)$" })')
  }

  LazyLoader {
    active: root.built

    FloatingWindow {
      id: win
      title: "Settings"
      color: Theme.bgCanvas
      implicitWidth: 980
      implicitHeight: 660
      minimumSize: Qt.size(720, 480)
      visible: root.shown

      // Keeps `shown` honest when the compositor closes the window (SUPER+Q).
      onClosed: root.close()

      FocusScope {
        id: shellScope
        anchors.fill: parent
        focus: true

        // Every open starts on the sidebar, whether or not the window is new.
        Component.onCompleted: nav.forceActiveFocus()
        Connections {
          target: root
          function onShownChanged() { if (root.shown) nav.forceActiveFocus(); }
        }

        function currentPage() { return stack.children[stack.currentIndex]; }
        function enterPage() {
          const p = currentPage();
          if (p && p.focusFirst) p.focusFirst();
        }
        function cycle(d) {
          const n = SettingsPages.list.length;
          nav.currentIndex = (nav.currentIndex + d + n) % n;
        }

        Shortcut { sequences: ["Ctrl+Tab"];                    onActivated: shellScope.cycle(1) }
        Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+Shift+Backtab"]; onActivated: shellScope.cycle(-1) }

        // Ctrl+1..N, one per tab — Instantiator rather than Repeater because
        // Shortcut isn't an Item. Adding a tab to SettingsPages adds its chord.
        Instantiator {
          model: SettingsPages.list.length
          delegate: Shortcut {
            required property int index
            sequence: "Ctrl+" + (index + 1)
            onActivated: nav.currentIndex = index
          }
        }

        RowLayout {
          anchors.fill: parent
          spacing: 0

          // ---- sidebar ----
          Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: Theme.bgSurface

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Theme.space5
              spacing: Theme.space5

              Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space2
                Layout.leftMargin: Theme.space3
                text: "Settings"
                color: Theme.fgEmphasis
                font.family: Theme.fontUi
                font.pixelSize: Theme.textTitle
                font.weight: Theme.weightBold
              }

              ListView {
                id: nav
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                model: SettingsPages.list
                spacing: Theme.space1
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: true

                // Two-way sync with root.page, done imperatively: ListView writes
                // currentIndex itself on Up/Down, which would break a binding.
                //
                // `seeded` is why the view only starts talking back once it has
                // been told where to start. A ListView sets currentIndex to 0
                // itself while completing, and Qt emits that before any declared
                // Component.onCompleted — so unguarded, the first build of the
                // window overwrote root.page with the first tab and then seeded
                // itself from that. open("bluetooth") landed on Audio, and only
                // ever on the first open, since the window is built once and
                // kept alive from then on.
                property bool seeded: false
                Component.onCompleted: {
                  currentIndex = SettingsPages.indexOf(root.page);
                  seeded = true;
                }
                onCurrentIndexChanged: if (nav.seeded) root.page = SettingsPages.keyAt(currentIndex)
                Connections {
                  target: root
                  function onPageChanged() { nav.currentIndex = SettingsPages.indexOf(root.page); }
                }

                Keys.onEscapePressed: root.close()
                Keys.onRightPressed:  (e) => { shellScope.enterPage(); e.accepted = true; }
                Keys.onReturnPressed: (e) => { shellScope.enterPage(); e.accepted = true; }
                Keys.onEnterPressed:  (e) => { shellScope.enterPage(); e.accepted = true; }
                Keys.onTabPressed:    (e) => { shellScope.enterPage(); e.accepted = true; }

                delegate: Rectangle {
                  id: navRow
                  required property int index
                  required property var modelData
                  readonly property bool current: nav.currentIndex === index

                  width: nav.width
                  height: 40
                  radius: Theme.radiusMd
                  color: current ? (nav.activeFocus ? Theme.accentTintHover : Theme.accentTintSoft)
                       : nhover.hovered ? Theme.bgSurfaceHover : "transparent"

                  // focus/selection bar — solid only while the sidebar owns keys
                  Rectangle {
                    width: 3
                    height: parent.height - Theme.space5
                    radius: Theme.radiusPill
                    anchors.verticalCenter: parent.verticalCenter
                    visible: navRow.current
                    color: nav.activeFocus ? Theme.accentPrimary : Theme.borderStrong
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space5
                    anchors.rightMargin: Theme.space4
                    spacing: Theme.space4

                    Text {
                      text: String.fromCodePoint(navRow.modelData.codepoint)
                      font.family: Theme.fontGlyph
                      font.pixelSize: Theme.textBody
                      color: navRow.current ? Theme.accentPrimary : Theme.fgMuted
                    }
                    Text {
                      Layout.fillWidth: true
                      text: navRow.modelData.label
                      elide: Text.ElideRight
                      color: navRow.current ? Theme.fgEmphasis : Theme.fgSecondary
                      font.family: Theme.fontUi
                      font.pixelSize: Theme.textLabel
                      font.weight: navRow.current ? Theme.weightMedium : Theme.weightRegular
                    }
                  }

                  HoverHandler { id: nhover }
                  TapHandler {
                    onTapped: {
                      nav.currentIndex = navRow.index;
                      nav.forceActiveFocus();
                    }
                  }
                }
              }
            }
          }

          Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.borderSubtle
          }

          // ---- page area ----
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Own strip rather than an overlay: every page header already has
            // right-aligned content that a floating button would sit on.
            RowLayout {
              Layout.fillWidth: true
              Layout.topMargin: Theme.space4
              Layout.rightMargin: Theme.space4
              Item { Layout.fillWidth: true }
              CloseButton { onClicked: root.close() }
            }

            StackLayout {
              id: stack
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.margins: Theme.space6
              Layout.topMargin: 0
              currentIndex: SettingsPages.indexOf(root.page)

              // Hidden pages keep their focused item, so switching tabs while a
              // page (not the sidebar) had the keyboard would leave typing going
              // to the tab you just left. Carry focus into the new page instead.
              onCurrentIndexChanged: Qt.callLater(function () {
                if (!nav.activeFocus) shellScope.enterPage();
              })

              // `active` gates each page's background work (scans, polling), so
              // it must follow window visibility as well as the current tab.
              SettingsAudioPage {
                active: root.shown && stack.currentIndex === 0
                onBackToNav: nav.forceActiveFocus()
              }
              SettingsNetworkPage {
                active: root.shown && stack.currentIndex === 1
                onBackToNav: nav.forceActiveFocus()
              }
              SettingsBluetoothPage {
                active: root.shown && stack.currentIndex === 2
                onBackToNav: nav.forceActiveFocus()
              }
              SettingsPowerPage {
                active: root.shown && stack.currentIndex === 3
                onBackToNav: nav.forceActiveFocus()
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 1
              color: Theme.borderSubtle
            }
            Text {
              Layout.fillWidth: true
              Layout.margins: Theme.space4
              horizontalAlignment: Text.AlignHCenter
              text: "↑↓ select  ·  Ctrl+Tab switch tab  ·  Enter apply  ·  Esc back"
              color: Theme.fgMuted
              font.family: Theme.fontUi
              font.pixelSize: Theme.textMicro
            }
          }
        }
      }
    }
  }
}
