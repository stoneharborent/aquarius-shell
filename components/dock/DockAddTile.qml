// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// DockAddTile — the dashed "+" at the end of the dock
// =============================================================================
//
//        ┌ ─ ─ ─ ┐
//        ╷   +   ╷      a tile-shaped dashed outline, one tile wide,
//        └ ─ ─ ─ ┘      after the last app
//
// From the design (the last `.dock-ico`, marked `border-style: dashed`, titled
// "Add an app"): the same 44px tile with the same 11px corners, drawn as a
// dashed hairline instead of a filled surface, with an 18px "+" in the middle,
// both in the quiet tertiary ink.
//
// IT IS WIRED TO NOTHING, ON PURPOSE
//   Clicking it emits `activated()`, and that is the entire behaviour. This
//   tile is meant to open Flow Search / the app grid, which is being built on a
//   different branch at the same time as this one. Importing that branch's
//   types from here would tie the two together and make both harder to land.
//
//   So: a signal, and a documented seam. Whoever wires the search palette in
//   connects to `Dock.appGridRequested` — or calls `qs ipc call dock
//   openAppGrid`, which fires the same signal from outside the process. Nothing
//   in this file has to change when that happens.
//
//   Today shell.qml connects it to a line of log output, exactly as the top
//   bar's own launcher signal is connected. A button that prints a line is
//   honest about being unfinished; a button that opens an empty box is not.
//
// WHY THE OUTLINE IS A Shape AND NOT A Rectangle
//   A QML Rectangle's border is always solid — there is no dashed option. The
//   KDE version painted this with a Canvas. QtQuick.Shapes is the better tool:
//   `strokeStyle: ShapePath.DashLine` with a `dashPattern` gives dashes
//   directly, it is the same drawing machinery the Aquarius mark in the top bar
//   already uses (components/bar/LogoMark.qml), and it repaints itself on a
//   property change without a Canvas's manual requestPaint() bookkeeping.
//   (https://doc.qt.io/qt-6/qml-qtquick-shapes-shapepath.html)
//
//   `dashPattern` is measured in multiples of the stroke width, so with a
//   hairline stroke [3, 3] is a 3px dash and a 3px gap.
//
//   The renderer is left at Qt's default (GeometryRenderer) rather than being
//   switched to CurveRenderer the way LogoMark does. CurveRenderer earns its
//   place on curves that get scaled; this is a rounded rectangle at a fixed
//   size, and Qt's documentation makes no promise about dash patterns under
//   that renderer. Do not "optimise" this line without checking on a machine.
// =============================================================================
import QtQuick
import QtQuick.Shapes

import "../../theme"

Item {
    id: root

    // Emitted on click. The Dock re-emits this as `appGridRequested`.
    signal activated()

    implicitWidth: Theme.dockTileSize
    implicitHeight: Theme.dockTileSize

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Add an app")
    Accessible.description: qsTr("Show all installed applications")

    // Keyboard reachability, ready for the day the dock takes keyboard focus.
    // It cannot today: PanelWindow.focusable defaults to false, so the
    // compositor never gives this window the keyboard and none of the handlers
    // below can fire. They are here because the alternative is remembering to
    // add them later, which nobody does.
    activeFocusOnTab: true

    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()
    Keys.onSpacePressed: root.activated()

    // The lift, identical to an app tile's. In the design this is an ordinary
    // dock tile and behaves like one.
    Item {
        id: tile

        anchors.fill: parent

        readonly property bool lifted: pointer.containsMouse

        scale: tile.lifted ? Theme.dockHoverScale : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeOut
            }
        }

        transform: Translate {
            y: tile.lifted ? -Theme.dockLift : 0

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durFast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }

        Shape {
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                strokeColor: Theme.inkMute
                fillColor: "transparent"
                strokeWidth: Theme.hairline
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 3]
                joinStyle: ShapePath.RoundJoin

                // A rounded rectangle written out as an SVG path, so it needs
                // nothing newer than Qt 6.0. (PathRectangle would say this in
                // one line but only arrived in Qt 6.8, and the shell should not
                // acquire a version floor for a dashed outline.)
                //
                // The stroke sits on the half-pixel so a hairline stays one
                // pixel instead of blurring across two, and it is inset by the
                // same amount an app icon is, so the dashes land on the same
                // line as a real tile's border rather than a pixel off it.
                PathSvg {
                    path: {
                        const inset = Theme.dockTileInset;
                        const half = Theme.hairline / 2;
                        const x = inset + half;
                        const y = inset + half;
                        const w = Theme.dockTileSize - inset * 2 - Theme.hairline;
                        const h = Theme.dockTileSize - inset * 2 - Theme.hairline;
                        // Never let the corner radius exceed half the box, or
                        // the arcs cross over and the outline turns inside out.
                        const r = Math.min(Theme.dockTileRadius, w / 2, h / 2);

                        return "M " + (x + r) + " " + y
                             + " H " + (x + w - r)
                             + " A " + r + " " + r + " 0 0 1 " + (x + w) + " " + (y + r)
                             + " V " + (y + h - r)
                             + " A " + r + " " + r + " 0 0 1 " + (x + w - r) + " " + (y + h)
                             + " H " + (x + r)
                             + " A " + r + " " + r + " 0 0 1 " + x + " " + (y + h - r)
                             + " V " + (y + r)
                             + " A " + r + " " + r + " 0 0 1 " + (x + r) + " " + y
                             + " Z";
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "+"
            font.family: Theme.fontBody
            font.pixelSize: Theme.dockAddGlyphSize
            font.weight: Font.Normal        // the design drops to 400 here
            color: Theme.inkMute
            textFormat: Text.PlainText
        }
    }

    MouseArea {
        id: pointer

        // Fills the item, not the lifting tile — see the note in DockItem.qml.
        anchors.fill: parent

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor

        onClicked: root.activated()
    }
}
