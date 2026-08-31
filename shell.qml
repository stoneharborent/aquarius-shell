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
// The table of contents so far: the top bar (P1), then P2's dock, Quick
// Settings and the Flow Search palette. Notifications are the last P2 piece
// still to land. See docs/ROADMAP.md.
//
// KEEP THIS FILE SHORT. It is the table of contents for the whole shell, and a
// table of contents stops being useful the moment it has logic in it. Anything
// that needs thinking about belongs in a component under components/.
// =============================================================================
import Quickshell

import "components/bar"
import "components/dock"
import "components/search"

ShellRoot {
    TopBar {
        // Clicking the Aquarius mark opens the search palette. The clock is
        // still Phase P2 work and still goes nowhere, which is honest and
        // better than a menu that opens onto an empty box.
        onLauncherRequested: flowSearch.toggleSearch()
        onNotificationsRequested: console.log("aquarius-shell: notifications requested (P2)")

        // Quick Settings is REAL — it opens from the bar's status cluster, on
        // the screen whose bar was clicked. This is not a request going
        // anywhere; by the time it arrives the panel is already on screen. It is
        // here so the shell has one observable place where that happens. See
        // docs/quick-settings.md.
        onQuickSettingsToggled: nowOpen =>
            console.log("aquarius-shell: quick settings", nowOpen ? "opened" : "closed")
    }

    Dock {
        // The dashed "+" tile. The full-screen app grid it was drawn for does
        // not exist yet, so it opens the nearest real thing: the search
        // palette, which launches apps today and grows into the grid later.
        // `qs ipc call dock openAppGrid` fires the same signal from outside.
        // See docs/dock.md.
        onAppGridRequested: flowSearch.toggleSearch()
    }

    // The search palette. Invisible until something asks for it — the bar or
    // dock above, or the compositor's Super keybind through:
    //
    //     qs ipc -c aquarius-shell call search toggle
    //
    // See docs/flow-search.md for the whole contract.
    FlowSearch {
        id: flowSearch
    }
}
