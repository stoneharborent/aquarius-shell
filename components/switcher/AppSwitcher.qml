// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// AppSwitcher — hold Command (or Alt), tap Tab, let go
// =============================================================================
// WHAT IT LOOKS LIKE
//
//    the whole desktop, gently dimmed
//   ┌──────────────────────────────────────────────────────────────┐
//   │                                                              │
//   │       ┌──────────────────────────────────────────┐           │
//   │       │  ┌────┐  ┏━━━━┓  ┌────┐  ┌────┐          │           │
//   │       │  │ ▇▇ │  ┃ ▇▇ ┃  │ ▇▇ │  │ ▇▇ │          │           │
//   │       │  └────┘  ┗━━━━┛  └────┘  └────┘          │           │
//   │       └──────────────────────────────────────────┘           │
//   │                                                              │
//   └──────────────────────────────────────────────────────────────┘
//
// The panel is the DOCK'S SLAB, lifted to the middle of the screen: the same
// `dockSurface` fill, the same corner, the same hairline. Solid, not glass —
// that was decided, and there is no blur anywhere in this file.
//
// =============================================================================
// THE HARD PART, AND HOW IT IS SOLVED: SEEING THE MODIFIER LET GO
// =============================================================================
// A switcher has to commit when you let go of Command. That single sentence is
// the whole difficulty, because of how Wayland works:
//
//   * KEYBINDS BELONG TO THE COMPOSITOR. An application cannot register a
//     global hotkey; that is the design of the platform, not a gap in it. So
//     Command-Tab is a line in labwc's rc.xml, and all it can do is run a
//     command — `qs ipc call switcher next` — which knocks on the door of the
//     shell that is already running.
//
//   * A COMMAND IS NOT A KEY-UP. rc.xml can say "when Tab is pressed with
//     Command held, run this". It cannot say "when Command is let go, run
//     this", not in a way that helps here. (Why not is written out below.)
//
// THREE WAYS WERE RESEARCHED, IN THE ORDER THE BUILD SPEC ASKED FOR. The third
// is what this file does. All three are written up in plain language, with what
// was actually read to decide each one, in docs/app-switcher.md. The short
// version:
//
//   (a) labwc's `onRelease` keybind — REJECTED, and not because it is missing.
//       It exists (labwc-config(5), labwc 0.20.2) and it is documented as
//       firing "without interference from other multi-key combinations that
//       include the super key". That is precisely the opposite of what we need:
//       labwc remembers ONE most-recently-matched keybind, and pressing Tab
//       while Command is held replaces Command's entry with Tab's, so letting
//       go of Command afterwards fires nothing. It is built to serve "tap
//       Command alone to open a launcher", and it does that well.
//
//   (b) Aquarius Keys (xremap) emitting the release — REJECTED. In the Windows
//       profile the remapper DOES NOT RUN AT ALL (windows.yaml has no rules, and
//       /usr/libexec/aquarius-keys-run deliberately starts nothing when there
//       are none), so Alt-Tab could never be served this way. And in the Mac
//       profile, taking hold of the Super key to watch its release means taking
//       it away from being a modifier, which is the one thing it must stay.
//
//   (c) THE SHELL WATCHES THE KEY ITSELF — CHOSEN, and it works because of a
//       detail of how labwc handles key releases, which was read out of its
//       source at the exact commit AquariusOS builds (0.20.2, pinned in
//       aquarius-os.env):
//
//         * Command on its own is bound to NOTHING. Only Command-TAB is a
//           keybind. So when you press Command, labwc does not swallow it.
//         * labwc keeps a list of keys it swallowed. On a key release it asks
//           "did I swallow this key's press?" — and if it did not, it forwards
//           the release to whatever surface has the keyboard.
//           (src/input/keyboard.c, handle_key_release: "Release events for keys
//           that were not bound should always be forwarded to clients".)
//         * This panel asks for EXCLUSIVE keyboard interactivity as a
//           layer-shell surface, which labwc honours (src/layers.c,
//           layer_try_set_focus), and when it hands focus over it passes along
//           the keys that are currently held down (src/seat.c, seat_focus ->
//           wlr_seat_keyboard_enter with the pressed-but-not-swallowed keys).
//
//       So: you hold Command, tap Tab, the panel appears and takes the
//       keyboard, and when you let Command go, labwc posts that release
//       straight to us. `Keys.onReleased` below is the whole mechanism.
//
// ⚠️ THE ONE ROUGH EDGE, SAID PLAINLY
//   There is a gap of a few tens of milliseconds between Tab being pressed and
//   this panel having the keyboard: the keybind has to start a small program,
//   that program has to talk to the shell, and the compositor has to put the
//   surface up. Let go of Command inside that gap — a really fast tap — and the
//   release lands somewhere else and we never see it.
//
//   The panel does not become a trap when that happens. THREE ways out, and all
//   three are ordinary things a person would already try:
//
//     * press Escape;
//     * click the app you wanted, or click anywhere else to cancel;
//     * press Command-Tab again — the next release lands here, because by then
//       we certainly have the keyboard.
//
//   It is written down here rather than hidden because it is the one thing on
//   the bench list that could look like a bug and is actually a known limit.
//   If it turns out to be common in real use, the fix is upstream: a labwc
//   keybind that fires on the release of a modifier REGARDLESS of what was
//   pressed in between. That is a small, obviously-correct change to
//   handle_compositor_keybindings() and it would suit every other Wayland shell
//   that wants an alt-tab too.
//
// =============================================================================
// TWO PROFILES, ONE PANEL
// =============================================================================
//   Mac profile      Command-Tab moves between APPLICATIONS; Down opens the
//                    windows of the one you are on; Command-` cycles an app's
//                    windows with no panel at all.
//   Windows profile  Alt-Tab moves between WINDOWS, one row each.
//
// `aq keys mac` / `aq keys windows` switches between them, and this file reads
// that answer live from services/KeyProfile.qml. There is deliberately no
// separate setting for the switcher: one question, asked once, at first login.
//
// BOTH SETS OF KEYS ARE BOUND ALL THE TIME, in labwc's rc.xml, and that is on
// purpose. In the Mac profile the physical key beside the space bar sends Super
// and the Windows-logo key sends Alt (Aquarius Keys swaps them, so Command is
// where a thumb expects it); in the Windows profile nothing is swapped. Binding
// both W-Tab and A-Tab means the switcher answers the key a person actually
// pressed in either profile, and NOTHING has to be rebound when the profile
// changes — only what the panel LISTS changes, and this file changes that
// without being restarted.
//
// NOT PROVEN ON HARDWARE. No QML engine has run this. See docs/app-switcher.md.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../../services"
import "../../theme"

Scope {
    id: root

    // ---- the state, and there is not much of it ------------------------------
    property bool isOpen: false

    // Purely for the opening animation — see the note beside the panel's
    // `opacity` below. `isOpen` says whether the switcher is up; `shown` says
    // whether it has been up for at least one frame.
    property bool shown: false

    // Which entry the release would go to.
    property int selectedIndex: 0

    // The Mac profile's Down-arrow list: is it showing, and which line of it.
    property bool expanded: false
    property int expandedIndex: 0

    // See the long note in components/search/FlowSearch.qml about Exclusive
    // versus OnDemand. Turn this off if Exclusive misbehaves on the bench — but
    // note that it is doing MORE work here than it does for the palette: it is
    // also how the modifier's release reaches us.
    property bool exclusiveKeyboard: true

    // Mac profile = group windows into applications. Read live: run
    // `aq keys windows` and the next Tab lists windows instead of apps.
    readonly property bool grouped: KeyProfile.mac

    readonly property var entries: root.switcherModel.entries

    signal opened()
    signal closed()

    // ---- what it lists --------------------------------------------------------
    // ⚠️ NOT called `model`, and not called `windows` either.
    //   `model` is the name a Repeater's delegate gets its own row data under,
    //   and a name an object already has wins over a name declared further up
    //   the file — section 26 of tests/test-shell.sh exists because of exactly
    //   that class of bug. `windows` was the other candidate and is worse for a
    //   different reason: SwitcherModel has a `windows` property OF ITS OWN, so
    //   half the file would read `root.windows.windows`.
    property SwitcherModel switcherModel: SwitcherModel {
        grouped: root.grouped
    }

    // ---- one exclusive overlay at a time --------------------------------------
    // Quick Settings takes a compositor input grab, and while it holds one this
    // panel could go up, dim the desktop and never see a key. Same rule, same
    // registry, same reason as the search palette: read the header of
    // services/Overlays.qml.
    Component.onCompleted: Overlays.register(root, () => root.cancel())
    Component.onDestruction: Overlays.unregister(root)

    // =========================================================================
    // The public API — what the keybinds and the panel itself call
    // =========================================================================

    // Move the selection along by `delta`, opening the panel if it is shut.
    //
    // WHERE IT OPENS, AND WHY IT IS NOT ON THE TILE YOU ARE ALREADY ON. The list
    // is in most-recently-used order, so the app you are in is the first tile.
    // Opening with that one selected would mean one tap of Command-Tab took you
    // nowhere. So the first tap lands on the tile AFTER it — the app you were in
    // before — which is why tap-and-release flips between two apps, exactly as
    // it does on a Mac. Going backwards (Shift) opens on the one BEFORE it,
    // which with a list this shape is the last tile: the same idea from the
    // other end.
    //
    // It steps from `currentIndex` rather than assuming that is 0, because it is
    // only ALMOST always 0 — a window with no app id at all is not listed, and
    // then the app you are in is not on the row for the first tap to move off.
    function step(delta: int): void {
        const list = root.entries;
        if (list.length === 0)
            return;

        if (!root.isOpen) {
            Overlays.claim(root);

            root.expanded = false;
            root.expandedIndex = 0;

            const at = root.switcherModel.currentIndex;
            const from = at >= 0 ? at : 0;
            const count = list.length;
            root.selectedIndex =
                ((from + (delta >= 0 ? 1 : -1)) % count + count) % count;

            root.isOpen = true;
            root.opened();
            return;
        }

        // Wrapping, because a row this short is faster to go round than to stop
        // at the end of — and because Command-Tab has always wrapped.
        const count = list.length;
        root.selectedIndex = ((root.selectedIndex + delta) % count + count) % count;

        // Moving to a different app closes its neighbour's window list. Leaving
        // it open would mean the list underneath belonged to a tile you are no
        // longer on.
        root.expanded = false;
        root.expandedIndex = 0;
    }

    // Down. In the Mac profile this opens the selected app's windows, and then
    // walks down them. In the Windows profile the panel IS a column of windows,
    // so down means the next one — the same thing Tab does, which is what
    // anybody pressing it would expect.
    function stepDown(): void {
        if (!root.isOpen)
            return;

        if (!root.grouped) {
            root.step(1);
            return;
        }

        const openWindows = root.selectedWindows;
        if (openWindows.length < 2)
            return;

        if (!root.expanded) {
            root.expanded = true;
            root.expandedIndex = 0;    // the spec: first row selected on open
            return;
        }

        root.expandedIndex = (root.expandedIndex + 1) % openWindows.length;
    }

    // Up. The mirror of the above: walk back up the window list, and step off
    // the top of it back onto the row of tiles.
    function stepUp(): void {
        if (!root.isOpen)
            return;

        if (!root.grouped) {
            root.step(-1);
            return;
        }

        if (!root.expanded)
            return;

        if (root.expandedIndex <= 0) {
            root.expanded = false;
            root.expandedIndex = 0;
            return;
        }

        root.expandedIndex -= 1;
    }

    // Let go of the modifier: go to what is selected and put the panel away.
    function commit(): void {
        if (!root.isOpen)
            return;

        const target = root.targetWindow;

        // Close FIRST. Activating a window makes the compositor move keyboard
        // focus, and a panel still holding an exclusive keyboard grab at that
        // moment is a panel arguing with the thing it just asked for.
        root.close();

        if (target)
            root.switcherModel.goTo(target);
    }

    // Escape, or a click on the dimmed desktop. Changes nothing.
    function cancel(): void {
        root.close();
    }

    function close(): void {
        if (!root.isOpen)
            return;
        root.isOpen = false;
        root.expanded = false;
        root.expandedIndex = 0;
        root.closed();
    }

    // Command-` — walk this application's own windows, with no panel.
    //
    // It works on the app you are IN, not on the app the panel has selected,
    // because on a Mac that is what it does and because it is meant to be used
    // without opening anything. Doing nothing when the app has one window is
    // deliberate: a panel that flashed up to say "there is only one" would be
    // worse than silence.
    function cycleWindows(): void {
        const next = root.switcherModel.nextSibling(root.switcherModel.activeWindow);
        if (next)
            root.switcherModel.goTo(next);
    }

    // ---- what the selection points at ------------------------------------------
    readonly property var selectedEntry: {
        const list = root.entries;
        if (root.selectedIndex < 0 || root.selectedIndex >= list.length)
            return null;
        return list[root.selectedIndex];
    }

    readonly property var selectedWindows: root.selectedEntry
        ? (root.selectedEntry.windows || [])
        : []

    // The window `commit()` would activate. With the list open it is the line
    // you are on; otherwise it is the app's most recently used window, which is
    // the one you last had in front of you.
    readonly property var targetWindow: {
        const openWindows = root.selectedWindows;
        if (openWindows.length === 0)
            return null;
        if (root.expanded && root.expandedIndex < openWindows.length)
            return openWindows[root.expandedIndex];
        return openWindows[0];
    }

    // =========================================================================
    // The door labwc's keybinds knock on
    // =========================================================================
    // `target: "switcher"` is the name in `qs ipc call <target> <function>`.
    // The full lines rc.xml binds are:
    //
    //     qs ipc call switcher next        Command-Tab   / Alt-Tab
    //     qs ipc call switcher prev        Command-⇧-Tab / Alt-⇧-Tab
    //     qs ipc call switcher cycle       Command-`
    //
    // `qs ipc show` lists them all at runtime, which is the first thing to run
    // if a keybind appears to do nothing.
    //
    // Every argument and return type is spelled out because Quickshell will not
    // register a handler function whose types are left implicit.
    IpcHandler {
        target: "switcher"

        // The next application (or window). Opens the panel if it is shut.
        function next(): void {
            root.step(1);
        }

        // The previous one. Same key with Shift held.
        function prev(): void {
            root.step(-1);
        }

        // Into the selected app's windows, then down them.
        function down(): void {
            root.stepDown();
        }

        // Back up, and out of the window list onto the tiles.
        function up(): void {
            root.stepUp();
        }

        // Go to what is selected. This is what the modifier's release means; it
        // is exposed here as well so that it can be driven from a script, and so
        // that a future compositor which CAN report a modifier release has a
        // line to bind. Read the long note at the top of this file.
        function go(): void {
            root.commit();
        }

        // Put it away, changing nothing. Also the way out if it ever sticks.
        function cancel(): void {
            root.cancel();
        }

        // Command-` — the next window of the app you are in, no panel.
        function cycle(): void {
            root.cycleWindows();
        }

        // For scripts, and for checking the shell is alive at all.
        function isOpen(): bool {
            return root.isOpen;
        }
    }

    // =========================================================================
    // The window
    // =========================================================================
    // Covers the whole screen, so the dim is real and a click anywhere outside
    // the panel cancels. `visible` is bound to isOpen, so while the switcher is
    // shut there is no layer surface at all — nothing holding a keyboard, and
    // nothing for the compositor to keep.
    //
    // WHICH MONITOR. The spec asks for one panel, on the monitor the pointer is
    // on. This window deliberately does NOT set `screen` and is deliberately not
    // wrapped in Variants: with `screen` unset, labwc places the surface on
    // `output_nearest_to_cursor()` (src/layers.c), which is exactly the rule
    // asked for, decided by the only thing that knows where the pointer is.
    // Asking ourselves would need a compositor-specific "active monitor" call,
    // which is the thing this repository does not do.
    PanelWindow {
        id: overlay

        visible: root.isOpen

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // A modal overlay must not reserve screen space and must not be pushed
        // around by the bar's exclusion zone — it covers the bar too.
        exclusionMode: ExclusionMode.Ignore

        // The window itself paints nothing; the scrim below does. Transparent is
        // the absence of a colour, not a choice of one.
        color: "transparent"

        focusable: true

        // A name for the surface, so `wayland-info`, labwc's own debugging
        // output and any window rule can tell which layer surface this is. Set
        // declaratively because the docs say it cannot be changed after the
        // window connects.
        WlrLayershell.namespace: "aquarius-shell-switcher"

        // Whenever the panel goes up, take the keyboard. The surface has to
        // exist before anything in it can hold focus, so the grab is taken one
        // turn of the event loop later rather than while the window is still
        // being put on screen — the same pattern, and the same reason, as the
        // search palette's text field.
        onVisibleChanged: {
            if (overlay.visible) {
                Qt.callLater(() => keys.forceActiveFocus());
                Qt.callLater(() => root.shown = true);
            } else {
                root.shown = false;
            }
        }

        Component.onCompleted: {
            // Upgrade OnDemand to Exclusive. THIS IS NOT DECORATION HERE — read
            // the note at the top of this file. Exclusive keyboard
            // interactivity is what makes labwc hand this surface the keyboard,
            // and being handed the keyboard is what makes the release of
            // Command arrive as an event we can act on.
            //
            // Done here rather than as a declarative binding for the same two
            // reasons as the search palette: it runs AFTER `focusable` has had
            // its say, and it is the guarded form the Quickshell docs
            // recommend, since WlrLayershell is only attached when the window
            // is genuinely backed by layer-shell.
            if (this.WlrLayershell !== null) {
                this.WlrLayershell.keyboardFocus = root.exclusiveKeyboard
                    ? WlrKeyboardFocus.Exclusive
                    : WlrKeyboardFocus.OnDemand;
            }
        }

        // ---- the dimmed desktop behind it ------------------------------------
        // `switcherScrim`, NOT `scrim`. The search palette pushes the desktop
        // right back because it wants you to stop looking at it; this panel is
        // asking you to choose between things you can SEE. 12% on Ice, 30% on
        // Midnight. Nothing is blurred — solid was decided.
        Rectangle {
            anchors.fill: parent
            color: Theme.switcherScrim
        }

        // Clicking anywhere that is not the panel cancels. Declared after the
        // scrim so it sits above it, and before the panel so the panel's own
        // catcher wins.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.cancel()
        }

        // ---- the keyboard ------------------------------------------------------
        // The one item in this window that holds focus. Everything the panel
        // hears, it hears here.
        // ⚠️ AN Item, NOT A FocusScope.
        //   A FocusScope hands focus DOWN to whichever child asked for it, and
        //   there is no such child here — nothing in this panel is typed into.
        //   A plain Item that takes the focus itself is what makes the attached
        //   Keys handlers below fire, and those handlers are the feature.
        Item {
            id: keys

            anchors.fill: parent
            focus: true

            // ⚠️ TAB DOES NOT ARRIVE HERE, AND THAT IS CORRECT.
            //   Command-Tab is a compositor keybind, so labwc consumes the
            //   press and never forwards it. Tab reaches this panel as an IPC
            //   call instead — `switcher next` — which is the whole design.
            //   The keys handled below are the ones labwc does NOT bind.
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    root.cancel();
                    event.accepted = true;
                    break;
                case Qt.Key_Down:
                    root.stepDown();
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                    root.stepUp();
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.commit();
                    event.accepted = true;
                    break;
                default:
                    break;
                }
            }

            // THE COMMIT. Read the long note at the top of this file for why a
            // key RELEASE is the hard part and why this line is where it lands.
            //
            // FOUR KEYS, NOT ONE, and every one of them is needed:
            //   Key_Meta                 what Qt calls the Super/Command key.
            //   Key_Super_L, Key_Super_R the same key under the names X11 and
            //                            xkb use — which of the two Qt reports
            //                            depends on the keymap, so both are
            //                            listed rather than guessed at.
            //   Key_Alt                  the Windows profile's modifier.
            //
            // Both profiles are covered without this file having to know which
            // one is switched on: whichever modifier you were holding is the one
            // whose release arrives.
            Keys.onReleased: event => {
                switch (event.key) {
                case Qt.Key_Meta:
                case Qt.Key_Super_L:
                case Qt.Key_Super_R:
                case Qt.Key_Alt:
                    root.commit();
                    event.accepted = true;
                    break;
                default:
                    break;
                }
            }

            // ---- the panel -----------------------------------------------------
            Rectangle {
                id: panel

                anchors.centerIn: parent

                width: content.width + Theme.switcherPadding * 2
                height: content.implicitHeight + Theme.switcherPadding * 2

                radius: Theme.switcherRadius

                // The dock's slab, lifted off the bottom of the screen. Same
                // fill, same hairline, no blur.
                color: Theme.dockSurface
                border.width: Theme.hairline
                border.color: Theme.lineStrong

                // Swallow clicks so they do not reach the cancel-on-click area
                // behind.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                }

                // The design: fade and scale up from 96% over 120 ms. The
                // selection itself moves with no animation at all — a highlight
                // that slides is a highlight that is in the wrong place while
                // you are reading it, and this panel is only ever on screen for
                // as long as a key is held.
                // ⚠️ `root.shown`, NOT `root.isOpen`. The window itself only
                //   exists while the switcher is open — `visible` is bound to
                //   isOpen — so by the time this Rectangle is built, isOpen is
                //   ALREADY true and an animation driven from it would have
                //   nothing to travel from. `shown` is set one frame later, so
                //   the panel is genuinely built small and faded and then grows.
                //
                //   There is no matching fade OUT, and that is deliberate: the
                //   surface is torn down the instant the switcher closes, which
                //   is what guarantees a crash cannot leave a keyboard grab
                //   behind. A 120 ms goodbye is not worth that.
                opacity: root.shown ? 1.0 : 0.0
                scale: root.shown ? 1.0 : Theme.switcherOpenScale

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durFast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeOut
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durFast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeOut
                    }
                }

                Column {
                    id: content

                    x: Theme.switcherPadding
                    y: Theme.switcherPadding
                    spacing: 0

                    // ⚠️ THE WIDTH IS SET, NOT MEASURED, AND IT HAS TO BE.
                    //   A Column works out its own width from its children. Two
                    //   of the children below want to be as wide as the column
                    //   (the separator rule and the window list), and a child
                    //   that measures its parent while its parent is measuring
                    //   it is a binding loop: QML gives up, prints a warning
                    //   nobody reads, and the panel draws at some arbitrary
                    //   size. So the width is decided here, from the one child
                    //   that has a size of its own, and everything else follows
                    //   it.
                    width: root.grouped
                        ? tiles.implicitWidth
                        : Theme.switcherWindowWidth

                    // ---- the row of applications (Mac profile) ----------------
                    // A Grid rather than a Row, with the number of columns
                    // worked out from the space there is. Twelve applications
                    // open on a laptop would otherwise draw a row wider than the
                    // screen, with the tiles at both ends off the edge of it —
                    // and the tile off the edge is the one you were reaching
                    // for. macOS wraps for the same reason.
                    Grid {
                        id: tiles

                        visible: root.grouped
                        spacing: Theme.switcherGap

                        readonly property int room: Math.max(1, Math.floor(
                            (overlay.width - Theme.switcherPadding * 4
                                + Theme.switcherGap)
                            / (Theme.switcherTileSize + Theme.switcherGap)))

                        columns: Math.max(1, Math.min(tiles.room, root.entries.length))

                        Repeater {
                            model: root.grouped ? root.entries : []

                            // SwitcherTile declares `required property var
                            // modelData` itself, so the Repeater fills that in —
                            // the same arrangement the dock uses for DockItem.
                            // `index` is asked for here because only this
                            // delegate needs it.
                            delegate: SwitcherTile {
                                required property int index

                                selected: index === root.selectedIndex

                                onClicked: {
                                    root.selectedIndex = index;
                                    root.expanded = false;
                                    root.commit();
                                }
                            }
                        }
                    }

                    // ---- the gap, the rule, the gap ---------------------------
                    // The spec's separator between the row of tiles and the
                    // window list under it. Only there when the list is.
                    Item {
                        width: content.width
                        height: Theme.switcherExpandGap
                        visible: expandedList.visible
                    }

                    Rectangle {
                        width: content.width
                        height: Theme.hairline
                        color: Theme.line
                        visible: expandedList.visible
                    }

                    Item {
                        width: content.width
                        height: Theme.switcherExpandGap
                        visible: expandedList.visible
                    }

                    // ---- the selected app's windows (Mac profile, Down) -------
                    Column {
                        id: expandedList

                        visible: root.grouped && root.expanded
                            && root.selectedWindows.length > 1
                        width: content.width
                        spacing: 0

                        Repeater {
                            model: expandedList.visible ? root.selectedWindows : []

                            delegate: SwitcherRow {
                                required property int index
                                required property var modelData

                                width: expandedList.width
                                compact: true
                                toplevel: modelData
                                iconSource: root.selectedEntry
                                    ? root.selectedEntry.icon : ""
                                appName: root.selectedEntry
                                    ? root.selectedEntry.name : ""
                                selected: index === root.expandedIndex

                                onClicked: {
                                    root.expandedIndex = index;
                                    root.commit();
                                }
                            }
                        }
                    }

                    // ---- the column of windows (Windows profile) --------------
                    Column {
                        id: windowList

                        visible: !root.grouped
                        width: Theme.switcherWindowWidth
                        spacing: 0

                        Repeater {
                            model: root.grouped ? [] : root.entries

                            delegate: SwitcherRow {
                                required property int index
                                required property var modelData

                                width: windowList.width
                                compact: false
                                toplevel: modelData.windows[0]
                                iconSource: modelData.icon
                                appName: modelData.name
                                selected: index === root.selectedIndex

                                onClicked: {
                                    root.selectedIndex = index;
                                    root.commit();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
