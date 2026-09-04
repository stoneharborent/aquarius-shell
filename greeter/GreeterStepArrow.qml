// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// GreeterStepArrow — the ‹ and › either side of the name
// =============================================================================
// Two jobs, and the second is the important one:
//
//   1. Clicking it moves to the next account.
//   2. Being there at all is how somebody finds out the arrow keys do the same
//      thing. A login screen that hides its only navigation behind a key nobody
//      pressed is a login screen where the second account does not exist.
//
// It is drawn rather than typed, for the same reason as the Aquarius mark and
// the search magnifier: a Shape takes a theme colour and repaints when the
// theme changes, and a text character depends on whichever typeface happens to
// be installed.
// =============================================================================
import QtQuick
import QtQuick.Shapes

import "../theme"

Item {
    id: root

    property bool pointsLeft: true

    signal triggered()

    implicitWidth: Theme.barGlyphSize
    implicitHeight: Theme.barGlyphSize

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.pressed ? Theme.pressWash
             : mouse.containsMouse ? Theme.hoverWash
             : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFast
            }
        }
    }

    Shape {
        // Drawn on a 24x24 grid and scaled, so the line stays smooth at any
        // size and on any screen.
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.implicitWidth / 24
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            strokeColor: mouse.containsMouse ? Theme.ink : Theme.inkSoft
            fillColor: "transparent"
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: root.pointsLeft ? "M15 5l-7 7 7 7" : "M9 5l7 7-7 7"
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
