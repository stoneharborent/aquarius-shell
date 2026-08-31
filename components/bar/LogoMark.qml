// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LogoMark — the Aquarius "A over a wave" mark, drawn at bar size
// =============================================================================
// WHY THIS DRAWS THE MARK INSTEAD OF LOADING assets/logo-mono.svg
//   The single-colour logo file says `stroke="currentColor"`, which is a CSS
//   idea meaning "whatever colour the surrounding text is". Web browsers
//   understand it. Qt's SVG renderer does not — it would draw the mark in
//   black, on a light bar, forever, and nobody would know why.
//
//   So the two path shapes are re-drawn here as QML, which lets them take the
//   theme's ink colour and repaint instantly when the theme changes. The path
//   data below is COPIED CHARACTER FOR CHARACTER out of
//   ../../assets/logo-mono.svg, and tests/test-shell.sh checks that it still
//   matches. If you change the logo, change the SVG first and let the test tell
//   you to come back here.
//
//   The SVG files are still in assets/ and are still the source of truth — for
//   this file, for the About screen later, and for anything that ships a real
//   image file.
//
// THE ONE INTENTIONAL DIFFERENCE FROM THE FILE
//   logo-mono.svg strokes at width 5. The V2 shell artboard strokes the bar
//   copy of the mark at width 6, because at 14 pixels a 5-wide stroke goes
//   spindly. The bar gets 6. That is a deliberate optical correction, not drift.
// =============================================================================
import QtQuick
import QtQuick.Shapes

import "../../theme"

Item {
    id: root

    // The mark is square. 14x14 in the bar, per the design.
    property int size: Theme.barLogoSize
    property color color: Theme.ink

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        // The artwork is drawn on a 64x64 grid (the SVG's viewBox) and then
        // scaled down to whatever `size` is. Drawing big and shrinking keeps
        // the curves smooth at any size, including on a HiDPI screen.
        width: 64
        height: 64
        anchors.centerIn: parent
        scale: root.size / 64
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        // The "A" — up the left leg, over the peak, down the right leg.
        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: 6
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M14 54 30 12q1.4-3.6 4 0L50 54" }
        }

        // The wave through the middle of the "A".
        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: 6
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M20 40q6-6 12 0t12 0" }
        }
    }
}
