// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// FocusState — the one switch that decides whether the machine may interrupt you
// =============================================================================
// Focus (other desktops call it Do Not Disturb) is a single shared boolean. Quick
// Settings flips it. The notification pipeline reads it before deciding whether a
// toast is allowed on screen. Nothing else in the shell is permitted to keep its
// own copy — a desktop with two disagreeing ideas of "am I allowed to interrupt"
// is a desktop that interrupts you during a render.
//
// WHAT THIS FILE ADDS BEYOND A BOOLEAN, AND WHY
//
//   1. A DEADLINE, NOT JUST A SWITCH.
//      `until` is an epoch-millisecond timestamp. Zero means "on until somebody
//      turns it off by hand". Anything else means "on until this moment". This is
//      the same shape KDE's own setting takes (`notificationsInhibitedUntil` is a
//      QDateTime, not a bool), and it is the shape the design needs: the panel's
//      control is not "Focus" — it is "Focus until morning".
//
//   2. IT TURNS ITSELF OFF.
//      A deadline nobody watches is a deadline that never arrives. The timer
//      below checks every 20 seconds, which is cheap and — unlike a single long
//      timer armed for eight hours — survives the machine being suspended and
//      woken, and survives the system clock being corrected.
//
//   3. IT SURVIVES A RESTART.
//      Turn Focus on at 23:00, restart the shell at 23:05, and Focus is still on
//      until 06:00. It is written to a small JSON file in Quickshell's own
//      per-shell state directory (`~/.local/state/quickshell/by-shell/<id>/`).
//      Without this, every crash or `qs` restart would silently start letting
//      notifications through again, which is the exact moment you would least
//      want it.
//
// WHY 06:00
//   "Until morning" has to mean some particular hour and 6 is the one KDE picked
//   for its own "until tomorrow morning" entry, so a person moving between the
//   shipping GNOME/KDE desktop and this one gets the same answer from both.
//
//   One deliberate difference from KDE: KDE always skips to TOMORROW's 06:00, so
//   turning it on at 01:00 buys 29 hours of silence. We take whichever 06:00
//   comes next, which at 01:00 is this morning. "Until morning" should mean the
//   morning that is about to happen.
//
// OWNERSHIP
//   The notifications track owns this file. Other components read `enabled`,
//   read `until`/`endsAt` to describe it, and call the functions. They do not
//   write the properties directly.
// =============================================================================
pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // =========================================================================
    // The state
    // =========================================================================

    // True while Focus is on: no toasts, notifications go straight to the panel.
    property bool enabled: false

    // Epoch milliseconds when Focus should switch itself back off.
    // 0 means "no schedule" — Focus stays on until turned off by hand.
    property double until: 0

    // The hour "until morning" means. Also read by anything that wants to say
    // the hour out loud rather than hard-code a 6 of its own.
    readonly property int morningHour: 6

    // When Focus ends, as a Date, or null if there is no deadline. This exists
    // so the panel can write "Focus is on until 6:00" without every caller
    // repeating the `until > 0` test and the Date construction.
    readonly property var endsAt: root.until > 0 ? new Date(root.until) : null

    // =========================================================================
    // Turning it on and off
    // =========================================================================

    // Plain toggle, with no deadline — the switch Quick Settings flips.
    function toggle(): void {
        if (root.enabled)
            root.turnOff();
        else
            root.turnOn(0);
    }

    // deadline: epoch ms to auto-disable at, or 0 for indefinite.
    function turnOn(deadline: real): void {
        root.until = deadline;
        root.enabled = true;
    }

    function turnOff(): void {
        root.enabled = false;
        root.until = 0;
    }

    // The next 06:00, as epoch milliseconds. Today's if it has not happened
    // yet, otherwise tomorrow's.
    function nextMorning(): real {
        const target = new Date();
        target.setHours(root.morningHour, 0, 0, 0);
        if (target.getTime() <= Date.now())
            target.setDate(target.getDate() + 1);
        return target.getTime();
    }

    function turnOnUntilMorning(): void {
        root.turnOn(root.nextMorning());
    }

    // What the notifications panel's one control does: off -> on until morning,
    // on -> off. Note that it turns OFF a Focus that was switched on from Quick
    // Settings with no deadline too, which is what a person pressing a lit
    // button expects.
    function toggleUntilMorning(): void {
        if (root.enabled)
            root.turnOff();
        else
            root.turnOnUntilMorning();
    }

    // =========================================================================
    // The thing that watches the deadline
    // =========================================================================
    // Polling rather than one long single-shot timer, deliberately. A timer armed
    // for seven hours does not fire correctly across a suspend, and it does not
    // notice if the system clock is corrected underneath it. Comparing the wall
    // clock every 20 seconds costs nothing and is right in both cases.
    //
    // `triggeredOnStart` matters more than it looks: it is what catches a
    // deadline that passed while the shell was not running, in the same tick as
    // the state being restored from disk.
    Timer {
        interval: 20000
        repeat: true
        triggeredOnStart: true
        running: root.enabled && root.until > 0
        onTriggered: {
            if (Date.now() >= root.until)
                root.turnOff();
        }
    }

    // =========================================================================
    // Surviving a restart
    // =========================================================================
    // `Quickshell.statePath()` resolves inside this shell's own state directory,
    // which Quickshell owns and creates — we are not inventing a path in the
    // user's home folder.
    //
    // `watchChanges` is deliberately left OFF (its default). This shell is the
    // only thing that ever writes this file, so watching it would only create a
    // write-reload-write loop for no benefit.

    // Set while the file is being read back, so that assigning the restored
    // values does not immediately write them out again.
    property bool restoring: false

    onEnabledChanged: root.persist()
    onUntilChanged: root.persist()

    function persist(): void {
        if (root.restoring)
            return;
        stored.enabled = root.enabled;
        stored.until = root.until;
    }

    // Called once the file has been read. A Focus whose deadline has already
    // passed while the shell was down comes back OFF, which is the whole point
    // of storing the deadline rather than just the switch.
    function restore(): void {
        root.restoring = true;

        const deadline = stored.until;
        const stillValid = stored.enabled && (deadline <= 0 || Date.now() < deadline);

        root.until = stillValid ? deadline : 0;
        root.enabled = stillValid;

        root.restoring = false;

        // Write the corrected state back, so a lapsed Focus does not sit in the
        // file looking live. If nothing changed, JsonAdapter emits nothing and
        // no write happens.
        root.persist();
    }

    FileView {
        id: stateFile

        path: Quickshell.statePath("focus.json")

        // Save whenever a property on the adapter below changes.
        onAdapterUpdated: stateFile.writeAdapter()

        // The file loaded: put what it said into the live properties.
        onLoaded: root.restore()

        // The file did not load, which on a fresh install simply means it has
        // never been written. The defaults below are already correct, so there
        // is nothing to do and nothing worth alarming anybody about.
        onLoadFailed: root.restoring = false

        JsonAdapter {
            id: stored
            property bool enabled: false
            property real until: 0
        }
    }
}
