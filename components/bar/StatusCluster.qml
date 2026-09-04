// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// StatusCluster — the group of small status icons left of the clock
// =============================================================================
// EVERYTHING IN THIS CLUSTER IS REAL. THERE ARE NO PLACEHOLDERS LEFT.
//
//   Left to right, what the bar actually draws between the app name and the
//   clock:
//
//     * THE SYSTEM TRAY. Every application that puts an icon in the tray, via
//       StatusNotifierItem. See TrayItem.qml. Empty on a machine with no tray
//       applications running, which is most machines most of the time.
//     * THE STATUS BUTTON. Live Wi-Fi, sound and battery glyphs, off the same
//       services the Quick Settings panel uses, and a click that opens that
//       panel underneath it.
//
//   THE TWO EMPTY SQUARES ARE GONE — 2026-09-04.
//     Until today this file drew two outlined boxes to the left of the tray,
//     holding space for the design's *Drop* and *Search* buttons. They were
//     honest placeholders and they were written down as such
//     (docs/first-run-on-hardware.md, "Open questions", item 1), but on the
//     bench they are simply two empty squares in the corner of the screen, and
//     an empty square is a thing that looks broken no matter what the source
//     says it means. Royce called it: "remove the placeholder squares in the
//     top right bar."
//
//     Nothing was lost with them:
//       SEARCH already has two ways in — click the Aquarius mark at the far
//         left of this same bar, or the "+" at the end of the dock, or bind
//         `qs ipc -c aquarius-shell call search toggle`. It has been real since
//         Flow Search landed; this slot was outliving its own placeholder.
//       DROP does not exist yet. When it does it gets a BarItem here with a
//         glyph in it, exactly the way the status button below is built, and
//         the clock shifts left by one item on the day it lands. Holding empty
//         space for months to avoid a one-off shift on that day was the wrong
//         trade.
//
//     If you are adding Drop: put its BarItem above the tray Repeater, give it
//     a glyph in components/quicksettings/QsGlyph.qml (see the note below about
//     why nothing here is a font), and DO NOT reintroduce an outlined box for
//     anything that is not yet clickable.
//
// WHERE THE GLYPHS COME FROM — AND WHY A BOX HERE IS NEVER A MISSING FONT
//
//   Nothing in this cluster is a character. Wi-Fi, sound and the battery are
//   vector paths drawn by QtQuick.Shapes: the first two out of the table in
//   components/quicksettings/QsGlyph.qml, the battery out of QsBatteryGlyph.qml,
//   both stroked in Theme colours at run time. No symbol font, no glyph table
//   from a package, no icon-theme lookup — QsGlyph.qml's header sets out the
//   three reasons at length, the short one being that this shell cannot assume
//   any font or icon theme is installed on the machine it wakes up on.
//
//   THE PRACTICAL CONSEQUENCE, and the reason this note exists: an empty box in
//   this corner CANNOT be Qt's missing-character tofu, and installing a font
//   will never fix anything here. Before 2026-09-04 a box in this cluster meant
//   exactly one thing — the Drop/Search placeholder rectangles this file used to
//   draw — and those are now gone. If a box appears here again, it came from a
//   TRAY application's own artwork (TrayItem.qml deliberately draws each app's
//   icon unrecoloured, and an app that publishes a bad icon name gets a
//   missing-image box), so look at which application is in the tray.
//
//   The two-letter fallback in the DOCK is the one place the shell does draw
//   text where an icon should be, and it uses Theme.fontDisplay — a real font,
//   with real letters in it. Different component, different problem.
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

    spacing: Theme.barItemSpacing

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
