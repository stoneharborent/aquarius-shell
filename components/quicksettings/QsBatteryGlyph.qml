// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// QsBatteryGlyph — the battery pictogram, with a fill that means something
// =============================================================================
// This one is not in QsGlyph.qml with the others because it is not a fixed
// drawing: the bar inside it is as long as the charge is, and its colour changes
// as the battery empties. That makes it three rectangles and a rule, not a path.
//
// THE DRAWING IS THE DESIGN'S — os-image/branding/design-system/
// "AquariusOS Desktop Shell.html", the battery in the Quick Settings footer. It
// is an 18x9 drawing on a 22x11 grid, made of three pieces (the geometry below
// is copied number for number; the colours are named rather than quoted,
// because tests/test-shell.sh rightly refuses to let a hex value into a
// component even inside a comment):
//
//   the shell   rect  x .75  y .75  w 18  h 9.5  rx 2.5, stroked at 1.2
//               in the text colour
//   the charge  rect  x 2.4  y 2.4  w 12  h 6.2  rx 1.4, filled in the
//               design's `success` green
//   the nub     path  M20.6 3.6v3.8a2 2 0 0 0 0-3.8z, filled in the text colour
//
// The design draws the charge in its `success` token. Asking
// the theme for `success` rather than writing that number is what lets the same
// glyph also go amber and then red as the battery empties — a state the design's
// single happy-path mock could not show, and one a person very much wants to see.
//
// The thresholds (25% amber, 10% red) are the ones the KDE Wave-2 widget used,
// carried over so the two shells agree while both exist.
// =============================================================================
import QtQuick

import "../../theme"

Item {
    id: root

    // 0.0 to 1.0.
    property real level: 0

    // Drawn with the charging nub over it when true.
    property bool charging: false

    implicitWidth: Theme.qsBatteryGlyphWidth
    implicitHeight: Theme.qsBatteryGlyphHeight

    // Everything below is expressed as a fraction of the design's 22x11 grid, so
    // the glyph is correct at whatever size the caller gives it.
    readonly property real unit: root.width / 22

    readonly property color chargeColor: root.level <= 0.10 ? Theme.danger
                                       : root.level <= 0.25 ? Theme.warn
                                                            : Theme.success

    // The shell.
    Rectangle {
        x: 0.75 * root.unit
        y: 0.75 * root.unit
        width: 18 * root.unit
        height: 9.5 * root.unit
        radius: 2.5 * root.unit
        color: "transparent"
        border.width: Math.max(1, 1.2 * root.unit)
        border.color: Theme.ink
    }

    // The charge. `clip` is not needed because the width is already computed
    // against the inner box, but the max() keeps a nearly-empty battery from
    // drawing a sliver so thin its rounded corners collapse into a dot.
    Rectangle {
        x: 2.4 * root.unit
        y: 2.4 * root.unit
        width: Math.max(0, Math.min(1, root.level)) * 14.2 * root.unit
        height: 6.2 * root.unit
        radius: 1.4 * root.unit
        color: root.chargeColor
        visible: width > 0

        Behavior on width {
            NumberAnimation { duration: Theme.durMed }
        }
    }

    // The nub on the positive end.
    Rectangle {
        x: 20.1 * root.unit
        y: 3.6 * root.unit
        width: 1.4 * root.unit
        height: 3.8 * root.unit
        radius: width / 2
        color: Theme.ink
    }

    // The charging mark: a small bolt over the charge bar. The design has no
    // charging state — it drew one battery, plugged in or not — so this is ours,
    // and it is deliberately the plainest possible mark rather than an invented
    // second drawing.
    Rectangle {
        visible: root.charging
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -root.unit
        width: 2 * root.unit
        height: 7 * root.unit
        radius: root.unit / 2
        rotation: 20
        color: Theme.ink
    }
}
