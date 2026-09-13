// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// CaptureMenu — the three-row menu under the Screenshot and Record buttons
// =============================================================================
// WHAT IT IS
//
//   Click the camera in the bar and this opens under it:
//
//     ┌────────────────────────────┐
//     │  Whole screen              │
//     │  An app                    │
//     │  Select an area            │
//     └────────────────────────────┘
//
//   Click the record circle and the same three rows open under that instead.
//   The rows are the same MenuRow the Aquarius menu is built from, in the same
//   card, so the three menus in this bar are visibly one family.
//
// HOW IT IS PUT TOGETHER, AND WHY IT IS NOT THE LOGO MENU'S KIND OF WINDOW
//
//   The Aquarius menu is a full-screen layer-shell surface, because it hangs off
//   the far-left corner of the bar and wants the keyboard for its up/down keys.
//   This one hangs off a bar item that can be at a different x on every monitor,
//   which is exactly the problem `PopupWindow` with an `anchor.item` solves —
//   the same thing Quick Settings does one item to the right of here. So this is
//   built the way QuickSettingsPopup is built, not the way LogoMenu is.
//
//   It is still keyboard-navigable: `grabFocus` gives the popup the keyboard,
//   Up/Down walk the rows, Enter runs one and Escape closes.
//
// WHO DECIDES WHAT A ROW DOES
//
//   Not this file. It emits `chosen("screen" | "window" | "area")` and closes.
//   StatusCluster.qml turns that into CaptureService.shot() or .record(). This
//   file knows nothing about screenshots, and that is why there is one of it
//   rather than two.
// =============================================================================
import QtQuick

import Quickshell

import "../../services"
import "../../theme"

Scope {
    id: root

    // The bar item this hangs under.
    property Item anchorItem: null

    readonly property bool open: popup.visible

    // Clicking the bar item again while the menu is up should close it, not
    // close-and-reopen. The pointer press dismisses the popup before the click
    // reaches the item, so without this guard the menu would flicker and stay.
    // Same 250 ms and the same reasoning as QuickSettingsPopup.
    property double lastDismissedAt: 0
    readonly property int reopenGuardMs: 250

    // "screen", "window" or "area".
    signal chosen(string mode)

    // The three rows, in the order the design asks for: the easy one first, the
    // deliberate one last. The wording is Royce's from feature 017 — "An app",
    // not "A window", because a person picks the app they can see.
    readonly property var items: [
        { mode: "screen", title: qsTr("Whole screen") },
        { mode: "window", title: qsTr("An app") },
        { mode: "area",   title: qsTr("Select an area") }
    ]

    Component.onCompleted: Overlays.register(root, () => root.hide())
    Component.onDestruction: Overlays.unregister(root)

    function show(): void {
        if (Date.now() - root.lastDismissedAt < root.reopenGuardMs)
            return;
        Overlays.claim(root);      // before the surface goes up
        popup.visible = true;
    }

    function hide(): void {
        popup.visible = false;
    }

    function toggle(): void {
        if (popup.visible)
            root.hide();
        else
            root.show();
    }

    PopupWindow {
        id: popup

        anchor {
            item: root.anchorItem
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: Theme.logoMenuGapUnderBar
        }

        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        color: "transparent"
        visible: false
        grabFocus: true

        property int selectedIndex: 0

        function moveSelection(delta: int): void {
            const count = root.items.length;
            if (count === 0)
                return;
            popup.selectedIndex = ((popup.selectedIndex + delta) % count + count) % count;
        }

        function activateIndex(i: int): void {
            const item = root.items[i];
            if (item === undefined || item === null)
                return;
            root.hide();
            root.chosen(item.mode);
        }

        onVisibleChanged: {
            if (popup.visible) {
                popup.selectedIndex = 0;
                Qt.callLater(() => card.forceActiveFocus());
            } else {
                root.lastDismissedAt = Date.now();
            }
        }

        Rectangle {
            id: card

            // A fixed width, for the same reason the Aquarius menu's card has
            // one: deriving it from the widest row is a binding loop waiting to
            // happen, and the rows elide.
            implicitWidth: Theme.logoMenuMinWidth
            implicitHeight: col.implicitHeight + Theme.logoMenuPaddingV * 2

            radius: Theme.logoMenuRadius
            color: Theme.surface
            border.width: Theme.hairline
            border.color: Theme.lineStrong

            focus: true

            Keys.onUpPressed: popup.moveSelection(-1)
            Keys.onDownPressed: popup.moveSelection(1)
            Keys.onReturnPressed: popup.activateIndex(popup.selectedIndex)
            Keys.onEnterPressed: popup.activateIndex(popup.selectedIndex)
            Keys.onEscapePressed: root.hide()

            Column {
                id: col

                x: 0
                y: Theme.logoMenuPaddingV
                width: card.width
                spacing: 0

                Repeater {
                    model: root.items

                    delegate: MenuRow {
                        required property int index
                        required property var modelData

                        width: col.width

                        label: modelData.title
                        selected: index === popup.selectedIndex

                        onHovered: popup.selectedIndex = index
                        onActivated: popup.activateIndex(index)
                    }
                }
            }
        }
    }
}
