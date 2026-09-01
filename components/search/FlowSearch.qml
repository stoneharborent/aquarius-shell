// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// FlowSearch — the search overlay. One box, no commands to learn.
// =============================================================================
// WHAT IT LOOKS LIKE  (V2 artboard: "AquariusOS Shell Search.html")
//
//    the whole desktop, dimmed
//   ┌──────────────────────────────────────────────────────────────┐
//   │                                                              │
//   │            ┌────────────────────────────────────┐            │
//   │            │ ⌕  kd|                             │            │
//   │            ├────────────────────────────────────┤            │
//   │            │ ▢  Kdenlive              ↵ open    │            │
//   │            │ =  1440                            │            │
//   │            │ ⏻  Lock screen                     │            │
//   │            ├────────────────────────────────────┤            │
//   │            │ apps · math · actions — one box    │            │
//   │            └────────────────────────────────────┘            │
//   └──────────────────────────────────────────────────────────────┘
//
// =============================================================================
// HOW IT IS SUMMONED, AND WHY IT IS NOT A KEYBIND IN THIS FILE
// =============================================================================
// On Wayland there is no such thing as an application registering a global
// hotkey with the display server. Keybinds belong to the COMPOSITOR — that is
// the design of the platform, not a gap in it. A layer-shell client only ever
// receives keys while it holds keyboard focus, and a palette that is not on
// screen holds nothing.
//
// So the shell cannot bind Super. What it can do is expose a door the
// compositor's own keybind can knock on, and Quickshell has one: IpcHandler.
//
//     $ qs ipc -c aquarius-shell call search toggle
//
// The compositor config (a sibling branch owns those files) binds Super — or
// Super+Space — to exactly that line. Full contract, including the two other
// endpoints and the exact niri/labwc/sway/Hyprland syntax, is written out in
// docs/flow-search.md.
//
// WHAT WAS CHECKED BEFORE CHOOSING THIS
//   Quickshell 0.3.1 does ship a GlobalShortcut type. It lives in the
//   `Quickshell.Hyprland` module — it is Hyprland's `hyprland-global-shortcuts-v1`
//   protocol, which is Hyprland's own and not a standard. Importing it would
//   break the repo's one architectural law and tests/test-shell.sh fails the
//   build if anyone tries.
//
//   There is no portable alternative in 0.3.1: the type index has no
//   GlobalShortcuts portal binding, and `Quickshell.Wayland` carries
//   ShortcutInhibitor (which stops the compositor eating keys while a window is
//   focused — the opposite problem). The freedesktop
//   org.freedesktop.portal.GlobalShortcuts portal exists as a specification, but
//   nothing in Quickshell speaks it and its backends are not universal. If that
//   changes, this file gains a second summoning path and loses nothing.
//   (Checked against https://quickshell.org/docs/v0.3.1/types/ on 2026-08-31.)
//
// =============================================================================
// KEYBOARD FOCUS ON A LAYER-SHELL SURFACE
// =============================================================================
// A layer-shell surface does not get keyboard input by default; it has to ask.
// PanelWindow.focusable is the portable way to ask, and Quickshell's docs say
// it maps to WlrLayershell.keyboardFocus, whose three settings are None,
// OnDemand and Exclusive.
//
// This palette asks for Exclusive, because it is modal: it dims the desktop,
// it is the only thing you can be typing at, and OnDemand's own documentation
// warns that focus is "as determined by the operating system" — which for a
// surface that appeared because of a keybind rather than a click is exactly the
// case where an operating system may decide not to.
//
// The escape hatch, if Exclusive misbehaves on the bench: set
// `exclusiveKeyboard: false` below and it falls back to OnDemand. And if the
// palette ever gets stuck open, it can be closed from any other machine or TTY:
//
//     $ qs ipc -c aquarius-shell call search close
//
// The surface only exists while the palette is open — closing it destroys the
// window and with it the keyboard grab, so a crash cannot leave a grab behind.
//
// NOT PROVEN. No QML engine has run this. See docs/flow-search.md.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../../theme"

Scope {
    id: root

    // ---- the one piece of state --------------------------------------------
    property bool isOpen: false

    // See the long note above. Turn off if Exclusive misbehaves on the bench.
    property bool exclusiveKeyboard: true

    signal opened()
    signal closed()

    // ---- the public API, used by the bar, the IPC handler and anything else --
    function openSearch() {
        if (root.isOpen)
            return;
        root.isOpen = true;
        root.opened();
    }

    function closeSearch() {
        if (!root.isOpen)
            return;
        root.isOpen = false;
        root.closed();
    }

    function toggleSearch() {
        if (root.isOpen)
            root.closeSearch();
        else
            root.openSearch();
    }

    // =========================================================================
    // The door the compositor's keybind knocks on
    // =========================================================================
    // `target: "search"` is the name in `qs ipc call <target> <function>`. The
    // shell instance itself is picked with -c, and its name is the directory
    // this shell lives in: aquarius-shell. So the full line a compositor binds
    // is:
    //
    //     qs ipc -c aquarius-shell call search toggle
    //
    // `qs ipc show -c aquarius-shell` lists all four of these at runtime, which
    // is the first thing to run if a keybind does nothing.
    //
    // Every argument and return type is written out because Quickshell will not
    // register a handler function whose types are left implicit.
    IpcHandler {
        target: "search"

        // Open it if closed, close it if open. This is the one a keybind wants.
        function toggle(): void {
            root.toggleSearch();
        }

        // Always open, and reset. Bind this if you would rather the key never
        // closed the overlay.
        function open(): void {
            root.openSearch();
        }

        // Always close. Also the way out if it ever gets stuck.
        function close(): void {
            root.closeSearch();
        }

        // For scripts and for checking the shell is alive at all.
        function isOpen(): bool {
            return root.isOpen;
        }
    }

    // =========================================================================
    // What it knows how to find
    // =========================================================================
    property SearchEngine engine: SearchEngine {
        query: overlay.query
    }

    // =========================================================================
    // The window
    // =========================================================================
    // Covers the whole screen so the dimmed backdrop is real and clicking
    // anywhere outside the panel closes it. `visible` is bound to isOpen, so
    // while the palette is closed there is no layer surface at all — no
    // keyboard grab, no exclusion zone, nothing for the compositor to hold.
    //
    // NOTE ON WHICH SCREEN: this window deliberately does NOT set `screen`, and
    // deliberately is not wrapped in Variants the way the bar is. The bar wants
    // to exist once per monitor; a search box wants to exist once, where you are
    // looking. With `screen` unset the compositor places it, and the compositor
    // is the only thing that knows which output has your attention. Asking it
    // ourselves would need a compositor-specific "active monitor" call, which is
    // the thing this repo does not do.
    // ⚠️ THE ID IS `overlay`, NOT `palette`, AND IT MUST NOT GO BACK
    //   Every QML `Item` has a built-in `palette` property of its own — Qt 6's
    //   colour-group API. A child object's OWN property is found before this
    //   file's ids, so inside the result delegate below, `palette.selectedIndex`
    //   did not mean this window at all. It meant `Item.palette.selectedIndex`,
    //   which is simply undefined.
    //
    //   Nothing failed loudly. `index === undefined` is false, so every row
    //   quietly decided it was not the selected one, and TWO features were dead
    //   for as long as this file has existed:
    //
    //     * the selected row was never drawn, so nothing on screen said what
    //       Enter would do or answered the arrow keys — the list looked inert
    //       even though the keys were working perfectly;
    //     * `awaitingConfirm` never armed, so the "anything that cannot be
    //       undone gets asked twice" guard on destructive actions was gone.
    //
    //   Found on the bench 2026-09-01, by painting the selected row bright red
    //   and seeing nothing change.
    PanelWindow {
        id: overlay

        readonly property string query: field.text

        visible: root.isOpen

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // A modal overlay must not reserve screen space, and must not be pushed
        // around by the bar's exclusion zone — it covers the bar too.
        exclusionMode: ExclusionMode.Ignore

        // The window itself paints nothing; the scrim below does. Transparent is
        // the absence of a colour, not a choice of one, so it is not a theme
        // value and does not belong in theme/.
        color: "transparent"

        // Ask for the keyboard, in the portable spelling. Quickshell maps this
        // to WlrLayershell.keyboardFocus = OnDemand.
        focusable: true

        // A name for the surface, so `wayland-info`, the compositor's own
        // debugging output and any window rule can tell which layer surface
        // this is. Set declaratively because the docs say it cannot be changed
        // after the window connects.
        WlrLayershell.namespace: "aquarius-shell-search"

        Component.onCompleted: {
            // Upgrade OnDemand to Exclusive. Done here rather than as a
            // declarative binding for two reasons: it runs AFTER `focusable`
            // has had its say, so there is no argument about which wrote
            // keyboardFocus last; and it is the guarded form the Quickshell
            // docs recommend, since WlrLayershell is only attached when the
            // window is genuinely backed by layer-shell.
            if (this.WlrLayershell !== null) {
                this.WlrLayershell.keyboardFocus = root.exclusiveKeyboard
                    ? WlrKeyboardFocus.Exclusive
                    : WlrKeyboardFocus.OnDemand;
            }
        }

        // ---- opening and closing resets everything --------------------------
        // "Open resets state" is a rule, not a nicety: a search box that
        // remembers last time's query makes you delete something before you can
        // start, every single time.
        onVisibleChanged: {
            overlay.selectedIndex = 0;
            overlay.confirmIndex = -1;
            field.text = "";

            // The surface has to exist before anything in it can hold focus, so
            // the focus grab is deferred by one turn of the event loop rather
            // than attempted while the window is still being shown.
            if (overlay.visible)
                Qt.callLater(field.takeFocus);
        }

        // ---- selection -------------------------------------------------------
        property int selectedIndex: 0

        // Which row has been armed by a first Enter and is waiting for a second.
        // -1 means nothing is armed. Any change to the query or the selection
        // disarms, so the second Enter always means the row you are looking at.
        property int confirmIndex: -1

        readonly property var results: root.engine.results

        onResultsChanged: {
            overlay.selectedIndex = 0;
            overlay.confirmIndex = -1;
        }

        function moveSelection(delta: int): void {
            const count = overlay.results.length;
            if (count === 0)
                return;
            // Wraps, because a list this short is faster to go round than to
            // stop at the end of.
            overlay.selectedIndex = ((overlay.selectedIndex + delta) % count + count) % count;
            overlay.confirmIndex = -1;
        }

        function activateSelection(): void {
            const count = overlay.results.length;
            if (count === 0) {
                root.closeSearch();
                return;
            }

            const index = overlay.selectedIndex;
            const result = overlay.results[index];
            if (!result)
                return;

            // Anything that cannot be undone gets asked twice. The row says so
            // while it is armed; nothing moves on screen, so the second Enter
            // lands where you are already looking.
            if (result.confirm && overlay.confirmIndex !== index) {
                overlay.confirmIndex = index;
                return;
            }

            if (root.engine.activate(result))
                root.closeSearch();
        }

        // ---- the dimmed desktop behind it -------------------------------------
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
        }

        // Clicking anywhere that is not the panel closes. Declared after the
        // scrim so it sits above it, and before the panel so the panel's own
        // catcher wins.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.closeSearch()
        }

        // ---- the panel ---------------------------------------------------------
        Rectangle {
            id: panel

            x: Math.round((parent.width - width) / 2)
            y: Theme.searchTop
            width: Theme.searchWidth
            height: content.implicitHeight + Theme.searchPanelPadding * 2

            radius: Theme.radiusLg
            color: Theme.surface
            border.width: Theme.hairline

            // The design floats the panel on a drop shadow. Qt's shadow lives in
            // QtQuick.Effects (MultiEffect), which is a second render pass and a
            // second import for one visual flourish. Until the bench says the
            // panel does not read as floating, it is separated by a stronger
            // hairline instead. Written down as a deviation in docs/flow-search.md.
            border.color: Theme.lineStrong

            // Swallow clicks so they do not reach the close-on-click area behind.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Column {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.searchPanelPadding
                spacing: 0

                // ---- the box ----------------------------------------------------
                SearchField {
                    id: field

                    width: parent.width

                    onMoveSelection: delta => overlay.moveSelection(delta)
                    onAccept: overlay.activateSelection()
                    onDismiss: root.closeSearch()
                }

                Rectangle {
                    width: parent.width
                    height: Theme.hairline
                    color: Theme.line
                }

                // ---- the results ---------------------------------------------------
                Item {
                    width: parent.width
                    height: list.implicitHeight + Theme.searchListPaddingV * 2
                    visible: overlay.results.length > 0

                    Column {
                        id: list

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: Theme.searchListPaddingH
                        anchors.rightMargin: Theme.searchListPaddingH
                        anchors.topMargin: Theme.searchListPaddingV
                        spacing: 0

                        Repeater {
                            model: overlay.results

                            delegate: ResultRow {
                                required property int index
                                required property var modelData

                                width: list.width
                                result: modelData
                                selected: index === overlay.selectedIndex
                                awaitingConfirm: index === overlay.confirmIndex

                                onActivated: {
                                    overlay.selectedIndex = index;
                                    overlay.activateSelection();
                                }
                            }
                        }
                    }
                }

                // ---- nothing found ---------------------------------------------------
                Item {
                    width: parent.width
                    height: emptyLabel.implicitHeight + Theme.searchRowPaddingV * 2
                    visible: overlay.results.length === 0 && field.text.length > 0

                    Text {
                        id: emptyLabel
                        anchors.centerIn: parent
                        text: qsTr("Nothing matched “%1”").arg(field.text)
                        font.family: Theme.fontBody
                        font.pixelSize: Theme.fsSmall
                        color: Theme.inkMute
                        textFormat: Text.PlainText
                    }
                }

                // Only drawn when there is something between the two rules.
                // Without this an empty box shows two hairlines stacked into
                // one thick line, which reads as a rendering fault.
                Rectangle {
                    width: parent.width
                    height: Theme.hairline
                    color: Theme.line
                    visible: field.text.length > 0
                }

                // ---- the footnote -----------------------------------------------------
                // The design's line reads "apps · files · settings · math ·
                // actions — one box, no commands to learn". Ours names only the
                // three that exist. The promise the footnote makes is the
                // promise the palette keeps; when files and settings land, this
                // string grows and not before.
                Item {
                    id: footer

                    width: parent.width
                    height: footerLabel.implicitHeight + Theme.searchFooterPaddingV * 2

                    Text {
                        id: footerLabel

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.searchFooterPaddingH
                        anchors.verticalCenter: parent.verticalCenter

                        text: qsTr("apps · math · actions — one box, no commands to learn")
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsMonoSm
                        color: Theme.inkMute
                        textFormat: Text.PlainText
                    }
                }
            }
        }
    }
}
