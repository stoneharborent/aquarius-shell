// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LogoMenu — the dropdown that opens off the Aquarius mark
// =============================================================================
// WHAT IT IS
//
//   Click the Aquarius mark at the top-left of the bar and a small Ice dropdown
//   opens under it — the desktop's equivalent of the Apple menu:
//
//     ┌────────────────────────────┐
//     │  About This PC             │   -> gnome-control-center system
//     │  System Settings          │   -> gnome-control-center
//     │  Check for Update         │   -> /usr/libexec/aquarius-updater
//     ├────────────────────────────┤
//     │  Log Out                  │   -> loginctl terminate-session
//     │  Sleep                    │   -> systemctl suspend
//     │  Restart                  │   -> systemctl reboot        (asks twice)
//     │  Power Off                │   -> systemctl poweroff      (asks twice)
//     └────────────────────────────┘
//
//   It is drawn BY THE SHELL — a layer-shell overlay, keyboard-navigable, Esc to
//   close — not a menu handed to us by the compositor, so it looks like the rest
//   of the shell and answers the keyboard on any compositor. Same standardised-
//   protocols law as everything else here: a PanelWindow (wlr-layer-shell) that
//   asks for the keyboard the portable way, exactly as the Flow Search palette
//   does. See components/search/FlowSearch.qml for the long version of that.
//
// HOW IT IS SUMMONED
//   The bar's LogoMark BarItem emits `launcherRequested`, and shell.qml turns
//   that into `logoMenu.toggle()`. There is also an IPC door, so a compositor
//   keybind or a script can open the Aquarius menu:
//
//       qs ipc -c aquarius-shell call logomenu toggle
//
// ONE OVERLAY AT A TIME
//   Like Flow Search and Quick Settings, this takes the keyboard, so opening it
//   closes the others and vice versa. services/Overlays.qml holds that rule; read
//   its header. This menu registers a closer, unregisters when destroyed, and
//   claims on the way open.
//
// WHY IT RUNS COMMANDS THE WAY IT DOES
//   Every item here either launches a GUI program (Settings, the updater) or
//   asks systemd to change the session's power state (suspend/reboot/poweroff/
//   logout). Launches go through `Quickshell.execDetached`, so the launched
//   program outlives a shell reload and nothing here has to manage its lifetime
//   — the same primitive DesktopEntry.execute() uses. The power actions are the
//   very same `systemctl`/`loginctl` front doors the Flow Search palette already
//   runs for its session actions (see components/search/SearchEngine.qml for the
//   honest note on why that is the interim until Quickshell has a logind
//   binding); this menu does not invent a second way to end a session, it uses
//   the one that is already here.
//
//   Log Out mirrors the palette exactly: `loginctl terminate-session <id>`, the
//   same thing Super+Shift+E does by another road, using $XDG_SESSION_ID. logind
//   lets the active-session user suspend, reboot and power off without a password
//   by default, so no polkit prompt is expected; Restart and Power Off (and Log
//   Out) still ask twice inside the menu, because a session ended by a stray
//   click is the one mistake worth guarding against.
//
// NOT PROVEN. No QML engine has run this. It is checked statically by
// tests/test-shell.sh and will be exercised on the bench.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../../services"
import "../../theme"

Scope {
    id: root

    // ---- state ---------------------------------------------------------------
    property bool isOpen: false

    // Turn off if Exclusive keyboard focus misbehaves on the bench, the same
    // escape hatch Flow Search has.
    property bool exclusiveKeyboard: true

    signal opened()
    signal closed()

    // The updater the os-image build installs. The menu offers "Check for
    // Update" only when this file is actually executable on the running machine;
    // otherwise the item is present but disabled and reads "Updates unavailable",
    // so the menu never launches something that is not there.
    readonly property string updaterPath: "/usr/libexec/aquarius-updater"
    property bool updaterAvailable: false

    // The argument list for the presence probe, kept as a named property rather
    // than written inline at the Process below. That is deliberate: it reads the
    // same way SearchEngine's `command: result.command` does, and it keeps the
    // one place this file touches a Process honest and easy to find.
    readonly property var updaterProbeArgv: ["test", "-x", root.updaterPath]

    // Logging out needs the session's own id, exactly as SearchEngine's Log out
    // action does. systemd puts it in the environment. If it is missing we do
    // not guess a session to end.
    readonly property string sessionId: {
        const value = Quickshell.env("XDG_SESSION_ID");
        return (value === null || value === undefined) ? "" : String(value);
    }

    // ---- the items, top to bottom -------------------------------------------
    // A plain array; the window's Repeater draws it. `separator: true` is a rule,
    // not a row you can land on. `confirm: true` arms a two-step click. `disabled`
    // greys a row and makes it unclickable.
    readonly property var items: {
        const out = [];
        out.push({ id: "about",    title: qsTr("About This PC") });
        out.push({ id: "settings", title: qsTr("System Settings") });
        if (root.updaterAvailable)
            out.push({ id: "update", title: qsTr("Check for Update") });
        else
            out.push({ id: "update", title: qsTr("Updates unavailable"), disabled: true });
        out.push({ separator: true });
        out.push({ id: "logout",   title: qsTr("Log Out"),   confirm: true });
        out.push({ id: "sleep",    title: qsTr("Sleep") });
        out.push({ id: "restart",  title: qsTr("Restart"),   confirm: true });
        out.push({ id: "poweroff", title: qsTr("Power Off"), confirm: true });
        return out;
    }

    // ---- one overlay at a time ----------------------------------------------
    Component.onCompleted: {
        Overlays.register(root, () => root.closeMenu());
        // Probe the updater once at start-up. It is re-probed on every open too,
        // in case it is installed while the shell is already running.
        updaterProbe.running = true;
    }
    Component.onDestruction: Overlays.unregister(root)

    // ---- the public API ------------------------------------------------------
    function openMenu(): void {
        if (root.isOpen)
            return;
        Overlays.claim(root);      // before the surface goes up
        if (!updaterProbe.running)
            updaterProbe.running = true;
        root.isOpen = true;
        root.opened();
    }

    function closeMenu(): void {
        if (!root.isOpen)
            return;
        root.isOpen = false;
        root.closed();
    }

    function toggle(): void {
        if (root.isOpen)
            root.closeMenu();
        else
            root.openMenu();
    }

    // ---- doing the thing -----------------------------------------------------
    // Launches use execDetached; power actions use the systemd front doors. See
    // the header for why each is what it is.
    function run(id: string): void {
        if (id === "about") {
            Quickshell.execDetached(["gnome-control-center", "system"]);
        } else if (id === "settings") {
            Quickshell.execDetached(["gnome-control-center"]);
        } else if (id === "update") {
            if (root.updaterAvailable)
                Quickshell.execDetached([root.updaterPath]);
        } else if (id === "logout") {
            if (root.sessionId !== "")
                Quickshell.execDetached(["loginctl", "terminate-session", root.sessionId]);
            else
                console.warn("aquarius-shell: no XDG_SESSION_ID, cannot log out");
        } else if (id === "sleep") {
            Quickshell.execDetached(["systemctl", "suspend"]);
        } else if (id === "restart") {
            Quickshell.execDetached(["systemctl", "reboot"]);
        } else if (id === "poweroff") {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        }
    }

    // The presence probe. `test -x <path>` exits 0 when the updater is there and
    // executable, non-zero otherwise; the result drives `updaterAvailable`.
    Process {
        id: updaterProbe
        command: root.updaterProbeArgv
        onExited: (exitCode, exitStatus) => {
            root.updaterAvailable = (exitCode === 0);
        }
    }

    // =========================================================================
    // The door a compositor keybind or a script can knock on
    // =========================================================================
    IpcHandler {
        target: "logomenu"

        function toggle(): void { root.toggle(); }
        function open(): void { root.openMenu(); }
        function close(): void { root.closeMenu(); }
        function isOpen(): bool { return root.isOpen; }
    }

    // =========================================================================
    // The window
    // =========================================================================
    // A full-screen surface, like Flow Search, so that a click anywhere outside
    // the card closes the menu and the card can hold the keyboard. Unlike Flow
    // Search it paints NO scrim: a menu should not dim the desktop behind it.
    // With `screen` unset the compositor places it on the output that has focus,
    // which is where the click on the mark came from.
    PanelWindow {
        id: overlay

        visible: root.isOpen

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // A menu must not reserve screen space or be pushed by the bar's zone.
        exclusionMode: ExclusionMode.Ignore

        // Nothing is painted at the window level; the card draws itself.
        color: "transparent"

        focusable: true

        WlrLayershell.namespace: "aquarius-shell-logomenu"

        Component.onCompleted: {
            if (this.WlrLayershell !== null) {
                this.WlrLayershell.keyboardFocus = root.exclusiveKeyboard
                    ? WlrKeyboardFocus.Exclusive
                    : WlrKeyboardFocus.OnDemand;
            }
        }

        // ---- selection ------------------------------------------------------
        property int selectedIndex: -1
        property string confirmId: ""

        function isSelectable(i: int): bool {
            const item = root.items[i];
            return item !== undefined && item !== null
                && !item.separator && !item.disabled;
        }

        function firstSelectable(): int {
            for (let i = 0; i < root.items.length; i++)
                if (overlay.isSelectable(i))
                    return i;
            return -1;
        }

        function moveSelection(delta: int): void {
            const count = root.items.length;
            if (count === 0)
                return;
            let i = overlay.selectedIndex;
            // Step at most `count` times looking for the next selectable row,
            // wrapping. If none is found the selection simply stays put.
            for (let step = 0; step < count; step++) {
                i = ((i + delta) % count + count) % count;
                if (overlay.isSelectable(i)) {
                    overlay.selectedIndex = i;
                    overlay.confirmId = "";      // moving disarms any confirm
                    return;
                }
            }
        }

        function activateIndex(i: int): void {
            if (!overlay.isSelectable(i))
                return;
            overlay.selectedIndex = i;
            const item = root.items[i];

            // Anything that ends the session is asked twice. The row says
            // "Confirm?" while it is armed; the second activation runs it.
            if (item.confirm && overlay.confirmId !== item.id) {
                overlay.confirmId = item.id;
                return;
            }

            root.run(item.id);
            root.closeMenu();
        }

        // Reset every time it opens: no query, no stale selection or arming.
        onVisibleChanged: {
            overlay.confirmId = "";
            if (overlay.visible) {
                overlay.selectedIndex = overlay.firstSelectable();
                Qt.callLater(() => card.forceActiveFocus());
            } else {
                overlay.selectedIndex = -1;
            }
        }

        // Click anywhere that is not the card closes.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.closeMenu()
        }

        // ---- the card -------------------------------------------------------
        Rectangle {
            id: card

            x: Theme.barPaddingH
            y: Theme.barHeight + Theme.logoMenuGapUnderBar
            // A fixed width, the same choice Flow Search's panel makes: deriving
            // it from the widest row would mean the Column's implicitWidth
            // reading the rows' width while the rows read the card's — a binding
            // loop. The rows elide instead, so a long label cannot overflow.
            width: Theme.logoMenuMinWidth
            height: col.implicitHeight + Theme.logoMenuPaddingV * 2

            radius: Theme.logoMenuRadius
            color: Theme.surface
            border.width: Theme.hairline
            // A stronger hairline stands in for the design's drop shadow, the
            // same call Flow Search's panel makes.
            border.color: Theme.lineStrong

            focus: true

            // The keyboard. Up/Down walk the selectable rows, Enter/Return runs
            // the selected one, Escape closes.
            Keys.onUpPressed: overlay.moveSelection(-1)
            Keys.onDownPressed: overlay.moveSelection(1)
            Keys.onReturnPressed: overlay.activateIndex(overlay.selectedIndex)
            Keys.onEnterPressed: overlay.activateIndex(overlay.selectedIndex)
            Keys.onEscapePressed: root.closeMenu()

            // Swallow clicks on the card so they do not reach the close-catcher.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Column {
                id: col

                x: 0
                y: Theme.logoMenuPaddingV
                width: card.width
                spacing: 0

                Repeater {
                    model: root.items

                    delegate: MenuRow {
                        required property int index
                        required property var modelData

                        width: col.width

                        isSeparator: modelData.separator === true
                        disabled: modelData.disabled === true
                        label: modelData.title !== undefined ? modelData.title : ""
                        selected: index === overlay.selectedIndex
                        awaitingConfirm: modelData.id !== undefined
                                         && modelData.id === overlay.confirmId
                        note: (modelData.id !== undefined
                               && modelData.id === overlay.confirmId)
                              ? qsTr("Confirm?") : ""

                        onHovered: {
                            if (overlay.isSelectable(index)) {
                                overlay.selectedIndex = index;
                                overlay.confirmId = "";
                            }
                        }
                        onActivated: overlay.activateIndex(index)
                    }
                }
            }
        }
    }
}
