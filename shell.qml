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
// Right now there are two things: the top bar, and the notification pipeline
// (the daemon, its toasts and the panel that drops out of the clock). Phase P2
// adds the dock, Quick Settings and the Flow Search palette, and each one will
// be another line in this file. See docs/ROADMAP.md.
//
// KEEP THIS FILE SHORT. It is the table of contents for the whole shell, and a
// table of contents stops being useful the moment it has logic in it. Anything
// that needs thinking about belongs in a component under components/.
// =============================================================================
import Quickshell

import "components/bar"
import "components/notifications"

ShellRoot {
    TopBar {
        // Clicking the Aquarius mark still does nothing — the launcher is
        // somebody else's part of P2. Better an honest no-op than a menu that
        // opens onto an empty box.
        onLauncherRequested: console.log("aquarius-shell: launcher requested (P2)")

        // Clicking the clock opens the notifications panel, and the clock stays
        // lit while it is open.
        onNotificationsRequested: notifications.togglePanel()
        notificationsOpen: notifications.panelOpen
    }

    // The notification daemon, the toasts and the panel. See
    // docs/notifications.md.
    NotificationLayer {
        id: notifications
    }
}
