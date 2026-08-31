// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// StatusCluster — the group of small status icons left of the clock
// =============================================================================
// THIS IS A PLACEHOLDER, AND IT IS DELIBERATELY A PLACEHOLDER.
//
// In the finished design this holds, left to right: Drop (send a file to
// another device), Search, then Wi-Fi + battery, which together open Quick
// Settings. None of those exist yet — they are Phase P2 (see docs/ROADMAP.md).
//
// What it does today is reserve the space and prove the layout: a row of empty
// slots, each exactly the size a real icon will be, so the bar's spacing and the
// clock's position are already correct and will not shift when the real things
// land. The slots draw a faint outline so you can see them on the bench and know
// the bar is doing what it should.
//
// Set `showSlots` to false to hide them entirely.
//
// WHEN YOU FILL THESE IN
//   Each slot becomes a BarItem with `interactive: true`, an icon inside, and a
//   click that opens a PopupWindow. The tray one is not hand-built: Quickshell
//   ships a SystemTray service that speaks StatusNotifierItem, which is the
//   standardised tray protocol — the same rule as everything else in this repo,
//   published protocols only.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.SystemTray/)
// =============================================================================
import QtQuick

import "../../theme"

Row {
    id: root

    // Draw the empty slots, or leave the space blank.
    property bool showSlots: true

    // What each future icon will occupy. Matches the design's bar icons, which
    // are drawn at 13-15px inside a 22px-tall item.
    property int slotSize: 15

    // The names are here so the bar reads as a plan rather than as three boxes.
    readonly property var plannedSlots: [
        { key: "drop", label: qsTr("Drop — send to any device") },
        { key: "search", label: qsTr("Search") },
        { key: "tray", label: qsTr("Network, sound and battery") }
    ]

    spacing: Theme.barItemSpacing

    Repeater {
        model: root.showSlots ? root.plannedSlots : []

        delegate: BarItem {
            required property var modelData

            // Not interactive: these do nothing yet, so they must not light up
            // on hover and pretend otherwise.
            interactive: false

            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.label

            Rectangle {
                width: root.slotSize
                height: root.slotSize
                radius: 3
                color: "transparent"
                border.width: Theme.hairline
                border.color: Theme.line
            }
        }
    }
}
