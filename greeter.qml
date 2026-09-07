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
//     qs -p greeter.qml
//
// ⚠️ THIS FILE LIVES AT THE REPO ROOT, BESIDE shell.qml, AND THAT IS THE FIX
//   FOR THE LOGIN SCREEN NOT DRAWING (bench, 2026-09-06/07). Quickshell treats
//   the folder of the file it is given as the config folder and throws away any
//   import that points outside it ("blackhole any import resolution outside of
//   the config folder", src/core/qsintercept.cpp). When the entry was
//   greeter/greeter.qml, the config folder was greeter/, so GreeterCard.qml's
//   `import "../components/bar"` (the Aquarius mark) and `import "../theme"`
//   resolved to nothing and the whole login screen failed with "LogoMark is
//   not a type" — a black screen nobody could log in through. With the entry
//   here, the config folder is the whole shell, and every import resolves. The
//   greeter's own pieces still live in greeter/ and are pulled in below.
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

import "greeter"

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
