// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// lock.qml — a way to LOOK at the lock screen while building it
// =============================================================================
// ⚠️ THIS IS NOT HOW THE LOCK SCREEN SHIPS, AND IT IS NOT A THIRD PROGRAM
// AQUARIUSOS RUNS.
//
// On a real machine the lock screen is part of the desktop shell: shell.qml
// holds a LockLayer, which is always there, watching the clock and waiting for
// Super+L. The long version of why is in the header of LockLayer.qml — the
// short version is that pressing Super+L must lock the screen instantly, and
// starting a program is not instant.
//
// This file exists for one reason: so that somebody working on the design can
// run the lock screen on its own, in the nested test harness, and see it.
//
//     ./harness/run-nested.sh                 (a compositor in a window)
//     qs -p lock/lock.qml                     (inside that window)
//
// It locks itself the moment it starts, so there is something to look at.
//
// -----------------------------------------------------------------------------
// ⚠️ DO NOT RUN THIS ON THE MACHINE YOU ARE SITTING AT
// -----------------------------------------------------------------------------
// It will lock your real session, for real, and the only way out is your real
// password — which is fine — or, if something in here is half-written and
// crashes, a text console (Ctrl+Alt+F3) and a command typed from memory. Run it
// in the harness. That is what the harness is for.
//
// It also needs /etc/pam.d/aquarius-lock to exist to be able to let you back
// in, which on a machine that is not AquariusOS it will not. The card will say
// so plainly rather than swallowing your Enter key.
// =============================================================================
import QtQuick   // for Component.onCompleted — see the note in LockLayer.qml
import Quickshell

import "."

ShellRoot {
    LockLayer {
        Component.onCompleted: LockState.lock()
    }
}
