// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// shell.qml — the front door
// =============================================================================
// This is the file Quickshell opens when you run the shell. Everything the
// desktop shows hangs off here.
//
//     qs -p /path/to/aquarius-shell
//
// Right now there is exactly one thing: the top bar. Phase P2 adds the dock,
// Quick Settings, notifications and the Flow Search palette, and each one will
// be another line in this file. See docs/ROADMAP.md.
//
// KEEP THIS FILE SHORT. It is the table of contents for the whole shell, and a
// table of contents stops being useful the moment it has logic in it. Anything
// that needs thinking about belongs in a component under components/.
// =============================================================================
import Quickshell

import "components/bar"
import "components/search"

ShellRoot {
    TopBar {
        // Clicking the Aquarius mark opens the search palette. The clock is
        // still Phase P2 work and still goes nowhere, which is honest and
        // better than a menu that opens onto an empty box.
        onLauncherRequested: flowSearch.toggleSearch()
        onNotificationsRequested: console.log("aquarius-shell: notifications requested (P2)")
    }

    // The search palette. Invisible until something asks for it — the bar
    // above, or the compositor's Super keybind through:
    //
    //     qs ipc -c aquarius-shell call search toggle
    //
    // See docs/flow-search.md for the whole contract.
    FlowSearch {
        id: flowSearch
    }
}
