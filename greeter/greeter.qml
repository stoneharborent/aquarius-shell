// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// greeter.qml — the front door of the login screen
// =============================================================================
// This is a SECOND entry point for this repository. `shell.qml` one folder up
// is the desktop: the bar, the dock, the search palette. This one is the login
// screen, and the only thing the two have in common is that they are the same
// design — they share theme/, the Aquarius mark, and nothing else.
//
//     qs -p greeter/greeter.qml
//
// On AquariusOS it is started by greetd, through a tiny compositor, and the
// whole chain is written out in the os-image repository at
// docs/restart/login.md. In one line: greetd starts labwc, labwc starts this,
// this asks greetd to start your desktop, and then it exits.
//
// KEEP THIS FILE SHORT — the same rule as shell.qml. It is a table of contents,
// and a table of contents stops being useful the moment it has logic in it.
// Everything that thinks lives in GreeterState.qml.
// =============================================================================
import Quickshell

import "."

ShellRoot {
    // One full screen of login screen per monitor. Every one shows the
    // wallpaper — a second screen must never be a black rectangle while
    // somebody types — and only the first carries the card and the keyboard,
    // because there is one password box and it can only be in one place.
    Variants {
        model: Quickshell.screens

        GreeterWindow {
            required property var modelData

            screen: modelData
            primary: Quickshell.screens.length > 0
                && modelData === Quickshell.screens[0]
        }
    }
}
