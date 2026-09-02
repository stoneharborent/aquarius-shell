// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// NotificationLayer — the whole notification pipeline, as one line in shell.qml
// =============================================================================
// This is the only thing the front door has to know about. Everything else in
// components/notifications/ hangs off here:
//
//     NotificationLayer
//       ├── NotificationStore ....... the freedesktop notification daemon
//       ├── ToastLayer (per screen) . the popups that appear on their own
//       └── NotificationPanelWindow . the panel that drops out of the clock
//                (per screen)
//
// shell.qml keeps one of these and calls togglePanel() when the bar clock is
// clicked. That is the entire integration surface, on purpose: this branch has
// to merge cleanly beside four others that are also editing shell.qml.
//
// ONE COPY OF EVERYTHING PER SCREEN, ONE STORE FOR ALL OF THEM
//   `Variants` builds a window for each connected monitor, the same way the bar
//   does. The store is NOT inside Variants — there is one notification daemon
//   for the machine, and every screen's windows read the same list from it. Two
//   daemons would mean two shells fighting over one D-Bus name.
//
// TOASTS HIDE WHILE THE PANEL IS OPEN
//   The panel and the toasts occupy exactly the same corner. Leaving both on
//   would stack one on top of the other; and if the panel is open, the person is
//   already looking at the place a toast would have told them to look.
// =============================================================================
pragma ComponentBehavior: Bound

// ⚠️ QtQuick IS IMPORTED FOR `Component.onCompleted`, NOT FOR ANYTHING VISUAL
//   This file draws nothing, so QtQuick looks like a stray import. It is not.
//   `Component.onCompleted` / `Component.onDestruction` are an ATTACHED type,
//   and the type comes with QtQuick (QtQml). Without the import, Quickshell
//   0.2.1 refuses the whole file with "Non-existent attached object" — verified
//   by running it, 2026-09-01. Deleting this line breaks the notifications
//   pipeline entirely, and the message does not mention imports.
import QtQuick
import Quickshell

import "../../services"

Scope {
    id: root

    // True while the notifications panel is on screen. shell.qml binds the bar
    // clock's lit state to this, so the clock looks pressed while its panel is
    // open.
    property bool panelOpen: false

    // ---- one overlay at a time ----------------------------------------------
    // The shell's rule: opening any exclusive overlay closes the others. See
    // services/Overlays.qml, and defect 1 in docs/first-run-on-hardware.md.
    //
    // This panel is NOT the thing that caused that defect — it is a layer-shell
    // surface with `focusable: true`, which is a request for keyboard focus and
    // not a compositor input grab the way Quick Settings' `grabFocus` is. It
    // joins the rule anyway, because it lands in the same corner of the screen
    // as Quick Settings and because it covers the whole screen with a
    // click-to-dismiss catcher, which would otherwise swallow the click meant
    // to dismiss something else.
    //
    // Registered ONCE, here, rather than per screen: `panelOpen` below is a
    // single boolean that every screen's window is bound to, so one closer puts
    // all of them away.
    Component.onCompleted: Overlays.register(root, () => root.closePanel())
    Component.onDestruction: Overlays.unregister(root)

    function togglePanel(): void {
        if (root.panelOpen) {
            root.closePanel();
            return;
        }

        // Opening: everything else goes first.
        Overlays.claim(root);
        root.panelOpen = true;
    }

    function closePanel(): void {
        root.panelOpen = false;
    }

    NotificationStore {
        id: store
    }

    // ---- the toasts ---------------------------------------------------------
    Variants {
        model: Quickshell.screens

        ToastLayer {
            required property var modelData
            screen: modelData

            store: store
            visible: !root.panelOpen && store.toasts.length > 0
        }
    }

    // ---- the panel ----------------------------------------------------------
    Variants {
        model: Quickshell.screens

        NotificationPanelWindow {
            required property var modelData
            screen: modelData

            store: store
            visible: root.panelOpen

            onCloseRequested: root.closePanel()
        }
    }
}
