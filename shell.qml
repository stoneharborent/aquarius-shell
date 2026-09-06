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
// The table of contents: the top bar (P1), then P2's dock, Quick Settings,
// the Flow Search palette, and the notification pipeline — the daemon, its
// toasts and the panel that drops out of the clock. See docs/ROADMAP.md.
//
// KEEP THIS FILE SHORT. It is the table of contents for the whole shell, and a
// table of contents stops being useful the moment it has logic in it. Anything
// that needs thinking about belongs in a component under components/.
// =============================================================================
import Quickshell

import "components/bar"
import "components/dock"
import "components/notifications"
import "components/search"
import "components/switcher"

ShellRoot {
    TopBar {
        // Clicking the Aquarius mark opens the Aquarius menu — the desktop's
        // Apple-menu: About This PC, System Settings, Check for Update, and the
        // session actions. Search moved to Super+Space and the desktop's
        // right-click menu. See components/bar/LogoMenu.qml.
        onLauncherRequested: logoMenu.toggle()

        // Clicking the clock opens the notifications panel, and the clock stays
        // lit while it is open.
        onNotificationsRequested: notifications.togglePanel()
        notificationsOpen: notifications.panelOpen

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

    // The Aquarius menu, off the mark at the top-left of the bar. Invisible
    // until the mark is clicked or a keybind calls:
    //
    //     qs ipc -c aquarius-shell call logomenu toggle
    //
    // See docs/logo-menu.md.
    LogoMenu {
        id: logoMenu
    }

    // The notification daemon, the toasts and the panel. See
    // docs/notifications.md.
    NotificationLayer {
        id: notifications
    }

    // The app switcher — the panel Command-Tab (Mac keys) or Alt-Tab (Windows
    // keys) puts in the middle of the screen. Invisible until labwc's keybind
    // calls:
    //
    //     qs ipc call switcher next
    //
    // It commits when you let go of the modifier, which is the hard part and is
    // written out at the top of components/switcher/AppSwitcher.qml. See
    // docs/app-switcher.md.
    AppSwitcher {
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
