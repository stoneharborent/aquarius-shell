// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// TopBar — the Aquarius top bar. The first real piece of the Aquarius Shell.
// =============================================================================
// WHAT IT LOOKS LIKE
//
//   ┌──────────────────────────────────────────────────────────────────────┐
//   │ [A] Files                                    [ ][ ][ ]  Sat Aug 30 21:47 │
//   └──────────────────────────────────────────────────────────────────────┘
//     ^   ^                                        ^          ^
//     |   |                                        |          the clock
//     |   |                                        the status cluster (P2)
//     |   the app you are using right now
//     the Aquarius mark
//
//   30 pixels tall, the panel colour, one hairline along the bottom. Every one
//   of those numbers comes from Theme.qml, which got them from the V2 design.
//
// THE ARCHITECTURAL LAW THIS FILE OBEYS
//   A bar has to be told "you are a bar" — pinned to the top edge, above normal
//   windows, with the rest of the screen kept clear of it. There are two ways to
//   ask a compositor for that:
//
//     (a) through wlr-layer-shell, a PUBLISHED protocol that many compositors
//         implement, or
//     (b) through a private interface belonging to one particular compositor.
//
//   This shell only ever does (a). Quickshell's PanelWindow is that request,
//   spelled portably: on Wayland it becomes zwlr_layer_shell_v1 underneath.
//   Nothing in this repo may ever reach into KWin's or Mutter's internals. Every
//   project that took the shortcut ended up maintaining a fork of somebody
//   else's window manager, and every one of them regretted it — that history is
//   the reason the rule exists.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/)
//
// ONE BAR PER MONITOR
//   `Variants` builds one copy of everything inside it for each screen the
//   compositor reports. Plug in a second monitor and a second bar appears, with
//   no code involved.
//
// WHY THERE IS NO File / Edit / View
//   See the long note in ActiveAppName.qml. Short version: a global menu bar
//   only works for Qt applications, and creators mostly do not use Qt
//   applications. An empty menu bar is worse than no menu bar.
// =============================================================================
import QtQuick

import Quickshell

import "../../theme"

Scope {
    id: root

    // Emitted when somebody clicks the Aquarius mark. P2 hangs the app grid
    // (the full-screen launcher) off this. Today it goes nowhere.
    signal launcherRequested()

    // Emitted when somebody clicks the clock. P2 hangs notifications + calendar
    // off this.
    signal notificationsRequested()

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            required property var modelData
            screen: bar.modelData

            // Pinned along the top edge, corner to corner.
            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: Theme.barHeight

            // Tell the compositor to keep this strip of screen clear, so a
            // maximised window starts underneath the bar instead of behind it.
            exclusionMode: ExclusionMode.Auto

            // The bar is SOLID, not see-through. See BarItem.qml for why.
            color: Theme.panel

            // The hairline along the bottom edge. It is what separates the bar
            // from the desktop without drawing a heavy line across the screen.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.hairline
                color: Theme.line
            }

            // ---- left side: who you are looking at ---------------------------
            Row {
                id: leftGroup

                anchors.left: parent.left
                anchors.leftMargin: Theme.barPaddingH
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.barItemSpacing

                BarItem {
                    interactive: true
                    onClicked: root.launcherRequested()

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Aquarius menu")

                    LogoMark {}
                }

                BarItem {
                    ActiveAppName {}
                }
            }

            // ---- right side: how the machine is doing ------------------------
            Row {
                id: rightGroup

                anchors.right: parent.right
                anchors.rightMargin: Theme.barPaddingH
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.barItemSpacing

                StatusCluster {}

                BarClock {
                    onActivated: root.notificationsRequested()
                }
            }
        }
    }
}
