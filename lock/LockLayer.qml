// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LockLayer — the lock screen, as the desktop sees it
// =============================================================================
// This is the one piece of the lock screen that shell.qml knows about. It holds
// three things:
//
//   the session lock   the thing that actually covers every screen
//   the idle watcher   dim at 5 minutes, lock at 10, screen off at 15
//   the IPC door       how the Super+L key binding reaches the running shell
//
// Everything else — the state machine, the card, the veil — hangs off
// LockState, which anything in the shell can reach by name.
//
// -----------------------------------------------------------------------------
// WHAT A SESSION LOCK IS, IN PLAIN ENGLISH
// -----------------------------------------------------------------------------
// It is not a window that covers the desktop. A window can be moved, raised
// above, crashed out of, or screenshotted around. A SESSION LOCK is a promise
// from the compositor itself, made over the standard `ext-session-lock-v1`
// protocol: from the moment it takes effect, the compositor stops showing
// anything except the surfaces this lock provides, stops delivering keyboard
// and mouse events to anything else, and will not stop doing either until this
// program says so.
//
// Your desktop is untouched underneath. Nothing was hidden, nothing was moved,
// no window was told to do anything. When the password is right, the compositor
// simply lifts the sheet and everything is exactly where it was — which is why
// unlocking is instant and why a two-hour render carries on regardless.
//
// -----------------------------------------------------------------------------
// ⚠️ THE DANGEROUS PART, AND IT IS WORTH UNDERSTANDING BEFORE EDITING THIS FILE
// -----------------------------------------------------------------------------
// That promise is one-way. If this program dies while the lock is on, the
// compositor keeps its side of the bargain: the screens stay covered — with a
// flat colour, because the thing that was drawing them is gone — and there is
// nothing left running that can unlock them. That is not a bug. It is what
// makes the lock a lock: the way to defeat a screen lock is to kill the locker,
// and this protocol makes killing the locker useless.
//
// The way out of that state on a real machine is switching to a text console
// (Ctrl+Alt+F3), logging in, and killing or restarting the session. Royce
// should know that sentence exists; it is in docs/lock-screen.md.
//
// So: nothing in lock/ may be clever. It reads a wallpaper from disk, draws
// text, and talks to PAM. No network, no new imports beyond the ones already
// here, and the one import that could fail — the blur — is quarantined behind a
// Loader. See LockBlur.qml.
//
// -----------------------------------------------------------------------------
// WHY THIS LIVES IN THE DESKTOP SHELL RATHER THAN BEING ITS OWN PROGRAM
// -----------------------------------------------------------------------------
// The login screen is a second entry point — greeter/greeter.qml — because it
// genuinely is a second program: it runs before anybody has logged in, started
// by greetd, in a session that does not exist yet.
//
// The lock screen is not that. It runs INSIDE your session, and putting it in
// its own process would buy nothing and cost three things:
//
//   1. SPEED, WHICH HERE IS SECURITY. Super+L has to lock the machine NOW. A
//      separate program means starting Qt, loading QML and connecting to the
//      compositor first — the better part of a second in which the screen is
//      not locked and you have already stood up and walked away.
//   2. The idle watcher has to run all the time anyway, so something in the
//      session is always going to be watching. That something may as well be
//      the shell.
//   3. The count of waiting notifications is in the shell, because the shell IS
//      this session's notification service. Across a process boundary it would
//      need a protocol of its own for one number.
//
// The obvious objection is the paragraph above: if the shell crashes while
// locked, the screen is stuck. True — and it is equally true of a separate
// locker process, which would be no less able to crash while holding the same
// promise. The difference is only in how likely each is to crash, and this way
// there is one program to keep alive instead of two.
//
// `lock/lock.qml` next to this file is a THIRD entry point, for looking at the
// lock screen in the nested harness without locking your real machine. It is a
// development tool, not how it ships.
// =============================================================================
// ⚠️ QtQuick IS IMPORTED FOR `Component.onCompleted`, NOT FOR ANYTHING VISUAL
//   This file draws nothing, so QtQuick looks like a stray import. It is not.
//   `Component.onCompleted` is an ATTACHED type that comes with QtQuick
//   (QtQml). Without the import, Quickshell 0.2.1 refuses the whole file with
//   "Non-existent attached object" — and shell.qml then reports "Type
//   LockLayer unavailable", so the entire desktop fails to load. That is what
//   happened on the bench on 6 September 2026. Same wire as
//   components/notifications/NotificationLayer.qml; test 40 now trips on it.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "."

Scope {
    id: root

    // How many notifications are waiting. Written by shell.qml from the
    // notification service, because this layer has no business reaching into
    // the notification store itself. A COUNT, never any content — see the note
    // beside the pill in LockSurface.qml.
    //
    // It is copied into LockState rather than read from here, so that the four
    // files that draw the lock screen all read one place for everything.
    property int notificationCount: 0

    onNotificationCountChanged: LockState.notificationCount = root.notificationCount
    Component.onCompleted: LockState.notificationCount = root.notificationCount

    // ==========================================================================
    // THE LOCK
    // ==========================================================================
    // `locked` follows LockState and nothing else sets it, so there is exactly
    // one answer to "is this machine locked" and one place that changes it.
    //
    // `secure` is the compositor confirming that every screen really is covered.
    // It is worth watching in a log: the gap between asking and being told yes
    // is where a bug would live.
    WlSessionLock {
        id: sessionLock

        locked: LockState.locked

        // One of these per screen. See LockSurface.qml.
        LockSurface {}
    }

    // ⚠️ MIRRORED INTO A PROPERTY OF OUR OWN RATHER THAN HANDLED DIRECTLY.
    //
    // `secure` is a C++ property whose change signal is spelled
    // `secureStateChanged`, not `secureChanged`. QML's rule for which of those
    // two names an `on…Changed` handler follows is a detail of the engine, and
    // a handler written against the wrong one is not an error — it simply never
    // runs, silently, which is the worst possible way to be wrong about a lock.
    //
    // A property declared HERE has a change signal QML generates itself, so
    // `onCoveredChanged` cannot be misspelled. Costs one line, removes a guess.
    readonly property bool covered: sessionLock.secure

    onCoveredChanged: {
        if (root.covered)
            console.info("aquarius-lock: the compositor confirms every screen is covered");
    }

    // ==========================================================================
    // WALKING AWAY FROM THE MACHINE
    // ==========================================================================
    LockIdle {
        id: idle
    }

    // ==========================================================================
    // The door a compositor key binding or a script knocks on
    // ==========================================================================
    // The Super+L binding in session/labwc/rc.xml runs exactly this:
    //
    //     qs ipc call lock lock
    //
    // It does not launch anything. It sends a message to the shell that is
    // ALREADY running, which is why locking is instant. `qs ipc` finds the
    // right instance from QS_CONFIG_PATH, which labwc inherited from the
    // session launcher — the same mechanism Super+Space uses for the search
    // palette, and the same trap: `qs ipc` takes no configuration name, and
    // passing one would be read as the TARGET name instead.
    //
    // If it ever does nothing, ask the running shell what it offers:
    //     qs ipc show
    IpcHandler {
        target: "lock"

        function lock(): void { LockState.lock(); }
        function isLocked(): bool { return LockState.locked; }

        // Deliberately NOT an `unlock()`. Anything that could ask this shell to
        // unlock without a password would be a way past the password, and `qs
        // ipc` is reachable by every program running as you. The only road out
        // of the lock screen is PAM saying yes.
    }
}
