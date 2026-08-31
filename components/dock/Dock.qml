// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// Dock — the bottom-centred dock. The second real piece of the Aquarius Shell.
// =============================================================================
// WHAT IT LOOKS LIKE
//
//              ╭───────────────────────────────────────────╮
//              │  ▣   ▣   ▣   ▣   ▣   ▣   │   ┌ ─ ┐        │
//              │  ●   ●                       ╷ + ╷        │
//              ╰───────────────────────────────────────────╯
//                 ^                       ^     ^
//                 |                       |     the "add an app" tile
//                 |                       a hairline rule
//                 pinned and running apps, with a dot under each running one
//
//   A floating slab, centred along the bottom of the screen with a 10px gap
//   under it. 44px tiles, 9px apart, 13px of space at the ends and 9px above
//   and below. Every one of those numbers is in Theme.qml, taken off the V2
//   artboard; none of them is typed in this file.
//
// HOW IT GETS TO BE A DOCK, AND WHY THAT MATTERS
//   Same law as the top bar: a panel has to ASK the compositor to be a panel,
//   and there are two ways to ask. One is wlr-layer-shell, a published protocol
//   many compositors implement. The other is a private seam into one particular
//   compositor's internals. This shell only ever uses the first, and
//   Quickshell's PanelWindow IS that request written portably — it becomes
//   zwlr_layer_shell_v1 underneath on Wayland.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/)
//
// HOW IT ENDS UP CENTRED
//   By anchoring to the BOTTOM EDGE ONLY. That is not a trick — it is what the
//   protocol says happens. From wlr-layer-shell-unstable-v1's own description
//   of set_anchor: "If two orthogonal edges are specified ... the anchor point
//   will be the intersection of the edges ...; otherwise the anchor point will
//   be centered on that edge". One anchor, so the compositor centres us, on
//   every compositor, with no arithmetic on our side and nothing to redo when a
//   monitor is plugged in or the resolution changes.
//
//   The window is exactly the size of the slab, so `margins.bottom` is the gap
//   between the slab and the screen edge, and the window's own colour is
//   transparent — otherwise the corners outside the slab's 16px radius would be
//   painted in and the dock would look like a rectangle with a picture of
//   rounded corners on it.
//
// ONE DOCK PER MONITOR
//   `Variants` builds one copy of everything inside it per screen the
//   compositor reports, the same way the top bar does. Every dock shows every
//   window, not only the ones on its own monitor — that is the setting the
//   shipping OS chose for the KDE dock ("showOnlyCurrentScreen: false", and
//   "matches how a Mac dock behaves"), kept here so the two agree.
//
// THE SEAM FOR THE APP GRID
//   `appGridRequested` fires when somebody clicks the dashed "+". It is
//   deliberately connected to nothing inside this component. Flow Search — the
//   full-screen app grid and search box the design draws — is being built
//   separately, and this dock does not import it, name it or depend on it.
//
//   Two ways in, both landing on that one signal:
//
//     1. QML:  Dock { onAppGridRequested: ...open the thing... }
//     2. IPC:  qs ipc call dock openAppGrid
//
//   The second exists so a keyboard shortcut, a script or another part of the
//   shell can open the same surface the tile opens, without either side having
//   to know about the other.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/IpcHandler/)
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Io

import "../../theme"

Scope {
    id: root

    // Emitted when the "+" tile is clicked, or when `qs ipc call dock
    // openAppGrid` is run. Wired to nothing here — see the header.
    signal appGridRequested()

    // Whether the compositor should keep the dock's strip of screen clear, so a
    // maximised window stops above the dock instead of sliding under it. True
    // matches how the shipping OS's dock behaves. Set false for a dock that
    // floats over windows in the macOS manner.
    property bool reserveSpace: true

    // ---- what is pinned, and what is running --------------------------------
    // One of each, shared by every monitor's dock. Two docks reading the same
    // config file separately would be two chances to disagree.
    DockConfig {
        id: dockConfig
    }

    DockModel {
        id: dockModel
        pinnedIds: dockConfig.pinned
    }

    // The IPC half of the app-grid seam. `target` must be unique across the
    // whole shell; "dock" is this component's.
    IpcHandler {
        target: "dock"

        function openAppGrid(): void {
            root.appGridRequested();
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dock

            required property var modelData
            screen: dock.modelData

            // ONE anchor. See "HOW IT ENDS UP CENTRED" above — this is what
            // makes the compositor centre the dock horizontally.
            anchors {
                bottom: true
            }

            margins {
                bottom: Theme.dockScreenMargin
            }

            // The window is the slab and nothing more.
            implicitWidth: slab.implicitWidth
            implicitHeight: slab.implicitHeight

            // The corners outside the slab's radius must show the desktop
            // through, not a colour. Set before the window is ever shown, which
            // the QsWindow docs require for a window that is to be transparent.
            color: "transparent"

            // Setting exclusiveZone puts the window in ExclusionMode.Normal, so
            // there is no need to set the mode as well. The zone is measured
            // from the screen edge, so it has to cover the gap underneath the
            // dock as well as the dock itself.
            exclusiveZone: root.reserveSpace
                ? dock.implicitHeight + Theme.dockScreenMargin
                : 0

            Rectangle {
                id: slab

                // No anchors on purpose: this Rectangle is what decides the
                // window's size, and an item that both fills its parent and
                // tells its parent how big to be is the one shape of binding
                // loop the Quickshell size guide warns about. It sits at 0,0
                // of a window that is exactly its own size, which is the same
                // place `anchors.fill` would have put it.
                implicitWidth: tiles.implicitWidth + Theme.dockPaddingH * 2
                implicitHeight: Theme.dockTileSize + Theme.dockPaddingV * 2

                width: slab.implicitWidth
                height: slab.implicitHeight

                radius: Theme.dockRadius
                color: Theme.panel
                border.width: Theme.hairline
                border.color: Theme.line

                // The design floats a blurred, translucent slab with a drop
                // shadow. This shell does neither: the top bar is solid for the
                // same reason (BarItem.qml's note, and the Plasma theme's
                // "Glass removed" decision), and Ice is a light theme where a
                // heavy shadow reads as grime. Solid panel, one hairline.

                Row {
                    id: tiles

                    anchors.centerIn: parent
                    spacing: Theme.dockGap

                    // Centring the row inside the padded slab is what leaves
                    // 9px above the tiles for the hover lift to move into, and
                    // 9px below for the running dots — which is exactly what
                    // the design's padding was for.

                    Repeater {
                        model: dockModel.items

                        // DockItem declares `required property var modelData`
                        // itself, so the Repeater fills it in. Nothing to pass
                        // by hand, and a required property means a missing
                        // model role fails loudly instead of drawing a blank.
                        delegate: DockItem {}
                    }

                    // The rule between the apps and the "+", straight from the
                    // design: 1px wide, 28px tall, in the stronger hairline.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.hairline
                        height: Theme.dockSeparatorHeight
                        color: Theme.lineStrong
                    }

                    DockAddTile {
                        onActivated: root.appGridRequested()
                    }
                }
            }
        }
    }
}
