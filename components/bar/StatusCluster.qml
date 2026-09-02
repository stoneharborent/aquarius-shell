// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// StatusCluster — the group of small status icons left of the clock
// =============================================================================
// THIS USED TO BE THREE EMPTY BOXES. TWO OF THEM ARE REAL NOW.
//
//   In the finished design this holds, left to right: Drop (send a file to
//   another device), Search, then Wi-Fi + battery, which together open Quick
//   Settings.
//
//   What is real, in this file, today:
//
//     * THE SYSTEM TRAY. Every application that puts an icon in the tray, via
//       StatusNotifierItem. See TrayItem.qml.
//     * THE STATUS BUTTON. Live Wi-Fi, sound and battery glyphs, off the same
//       services the Quick Settings panel uses, and a click that opens that
//       panel underneath it.
//
//   What is still a placeholder, and belongs to other Phase-P2 tracks:
//
//     * DROP — the send-to-any-device panel.
//     * SEARCH — the Flow Search palette.
//
//   Those two keep their empty outlined slots so the bar's spacing stays right
//   and the clock does not shift sideways when they land. Set `showPlannedSlots`
//   to false to hide them.
//
// ⚠️ THE GLYPHS ARE READ-ONLY MIRRORS OF THE PANEL, NOT A SECOND SOURCE OF TRUTH
//
//   The Wi-Fi, sound and battery glyphs here read the SAME Quickshell singletons
//   the Quick Settings tiles read — Networking, Pipewire, UPower. They hold no
//   state, cache nothing and write nothing. If the bar and the panel could ever
//   disagree about whether Wi-Fi is on, that would be a bug in one of them; the
//   arrangement here is that there is nothing to disagree about.
//
// ⚠️ WHY THE THREE GLYPHS ARE IN THREE SEPARATE LOADED FILES
//
//   Same reason the tiles are. A file that imports a missing module fails to
//   load ENTIRELY — and if that file were this one, the bar would lose its tray
//   and its clock along with its Wi-Fi glyph. `Quickshell.Networking` is the
//   module this was written for; it turns out to be present on the build
//   AquariusOS ships (corrected 2026-09-02 — see QsTileSlot.qml), but a bar that
//   survives a missing module is worth keeping whether or not one is missing
//   today.
//
//   So each glyph that touches a service is its own tiny file behind a Loader.
//   A missing module costs one glyph. Read the header of
//   components/quicksettings/QsTileSlot.qml for the full reasoning.
// =============================================================================
import QtQuick

import Quickshell.Services.SystemTray

import "../../theme"
import "../quicksettings"

Row {
    id: root

    // Emitted when the status button opens or closes the Quick Settings panel.
    // TopBar passes it up to shell.qml, so the shell has one observable place
    // where "the panel opened" happens.
    signal quickSettingsToggled(bool nowOpen)

    // Draw the empty Drop and Search slots, or leave the space blank.
    property bool showPlannedSlots: true

    // The two things in the design that other P2 tracks own. Named here so the
    // bar reads as a plan rather than as two mystery boxes.
    readonly property var plannedSlots: [
        { key: "drop", label: qsTr("Drop — send to any device") },
        { key: "search", label: qsTr("Search") }
    ]

    spacing: Theme.barItemSpacing

    // ---- still to come: Drop and Search --------------------------------------
    Repeater {
        model: root.showPlannedSlots ? root.plannedSlots : []

        delegate: BarItem {
            required property var modelData

            // Not interactive: these do nothing yet, so they must not light up
            // on hover and pretend otherwise.
            interactive: false

            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.label

            Rectangle {
                width: Theme.barGlyphSize
                height: Theme.barGlyphSize
                radius: 3
                color: "transparent"
                border.width: Theme.hairline
                border.color: Theme.line
            }
        }
    }

    // ---- the system tray ------------------------------------------------------
    // Referencing the SystemTray singleton is what makes Quickshell start
    // tracking the tray, so this Repeater is also the thing that turns it on.
    Repeater {
        model: SystemTray.items

        delegate: TrayItem {
            required property var modelData
            item: modelData
        }
    }

    // ---- Wi-Fi, sound, battery — and the way into Quick Settings --------------
    BarItem {
        id: statusButton

        interactive: true
        onClicked: {
            quickSettings.toggle();
            root.quickSettingsToggled(quickSettings.open);
        }

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Network, sound and battery")
        Accessible.description: qsTr("Opens Quick Settings")

        // Each of these is a Loader rather than the glyph itself. See the note
        // at the top about why. A glyph whose module is missing leaves a gap the
        // width of nothing, and the others carry on.
        Loader { source: "../quicksettings/StatusGlyphNetwork.qml" }
        Loader { source: "../quicksettings/StatusGlyphSound.qml" }
        Loader { source: "../quicksettings/StatusGlyphBattery.qml" }
    }

    // The panel itself. It is declared here, inside the bar, because it has to
    // anchor to THIS bar item on THIS monitor — `Variants` in TopBar.qml builds
    // one whole bar per screen, and each one gets its own panel with it. A
    // single panel declared up in shell.qml would have no way to know which
    // screen's bar it was hanging from.
    QuickSettingsPopup {
        id: quickSettings
        anchorItem: statusButton
    }
}
