// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// TileGameMode — the seam between this shell and the OS's session switching
// =============================================================================
// ⚠️ THIS TILE IS A DOOR, NOT A SWITCH, AND THAT IS THE WHOLE POINT.
//
//   Game Mode is not a setting the shell can turn on. It is Bazzite's Steam
//   big-picture SESSION: pressing this ends the desktop session and starts a
//   different one. A shell has no business implementing that, and it must not
//   pretend to. So:
//
//     * `active` is always false. The tile never lights up, because from inside
//       a desktop session Game Mode is never on — if it were, you would not be
//       looking at this panel.
//     * There is no "off" state to report and no toggle to be out of sync with.
//     * The subtitle says what pressing it DOES, not what state something is in.
//
//   Faking a toggle here would be a lie about an irreversible action, which is
//   the worst kind of interface lie.
//
// ⚠️ THIS PROPERTY IS THE ENTIRE SEAM. NOTHING ELSE IN THE SHELL KNOWS ABOUT
//   GAME MODE.
//
//     osCommand: ["/usr/bin/return-to-gamemode"]
//
//   `/usr/bin/return-to-gamemode` is Bazzite's own script — the same one its
//   `bazzite-user-setup` puts behind the "Return to Gaming Mode" desktop
//   launcher. If AquariusOS ever renames it, or swaps it for a D-Bus call or a
//   systemd unit, this one property changes and no other file in this repo
//   moves. tests/test-shell.sh checks that no other component under
//   components/ builds a command line, so that stays true.
//
//   This tile is only ever LOADED on a handheld image — QsPlatform.qml decides
//   that, and carries the reasoning. On a desktop the square holds
//   TilePowerProfile.qml instead.
//
// WHY THE COMMAND IS RUN DETACHED
//   `startDetached()` launches the process free of Quickshell. That matters
//   here and nowhere else in this repo: the command's job is to tear down the
//   session this shell is running in. A tracked child process would be killed
//   as Quickshell goes down, possibly mid-switch. Detached, it outlives us,
//   which is exactly what a session change needs.
//
//   The price is that a detached process reports nothing back — no exit code, no
//   stderr. If the command is missing, the tile does nothing visible and says
//   nothing. That is accepted: it can only happen on a handheld image where
//   Bazzite did not ship its own script, which would be a broken image.
// =============================================================================
import QtQuick

import Quickshell.Io

QsTile {
    id: root

    title: qsTr("Game Mode")
    glyph: "gamepad"

    // See the note above. Never true.
    active: false
    available: true

    subtitle: qsTr("Switch to Steam")

    // ---- THE SEAM ------------------------------------------------------------
    property var osCommand: ["/usr/bin/return-to-gamemode"]

    onActivated: {
        console.log("aquarius-shell: handing off to the OS's Game Mode:",
                    root.osCommand.join(" "));
        handoff.command = root.osCommand;
        handoff.startDetached();
    }

    Process {
        id: handoff
        // `command` is set at the moment of the handoff rather than bound, so
        // that a change to `osCommand` cannot restart anything by itself. This
        // process is only ever started by a deliberate press.
    }
}
