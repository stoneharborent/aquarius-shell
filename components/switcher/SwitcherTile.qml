// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SwitcherTile — one application in the Mac profile's row
// =============================================================================
//   ┌──────────────┐
//   │         ┌──┐ │   <- the window-count pill, only when there is more than
//   │         │3 │ │      one window open
//   │   ▇▇▇▇   └──┘ │
//   │   ▇▇▇▇       │   <- the app's icon, out of the icon theme
//   │              │
//   └──────────────┘
//
// 124 x 124, corner 20, icon 96. Selected means an `accentWash` fill and a
// `lineStrong` edge; unselected is transparent, so the dock slab shows through
// and the row reads as a row rather than as a strip of boxes.
//
// ⚠️ THERE IS NO NAME UNDER THE TILE, AND THAT IS THE DESIGN.
//   macOS draws the app's name above its switcher; this one does not draw it at
//   all. Royce's call, 2026-09-06: at 96px the icon IS the name, and a caption
//   under every tile turns a clean row into a paragraph. If a tile ever cannot
//   be recognised from its artwork, that is a missing icon to fix in the icon
//   theme, not a label to add here.
//
// NOT PROVEN ON HARDWARE. Checked statically (tests/test-shell.sh section 38).
// =============================================================================
import QtQuick

import Quickshell.Widgets

import "../../theme"

Item {
    id: root

    // One object out of SwitcherModel.entries. See that file for its shape.
    required property var modelData

    // Drawn as the one Enter/release would go to.
    property bool selected: false

    signal clicked()

    implicitWidth: Theme.switcherTileSize
    implicitHeight: Theme.switcherTileSize
    width: implicitWidth
    height: implicitHeight

    readonly property var windows: root.modelData ? (root.modelData.windows || []) : []
    readonly property string iconSource: root.modelData ? (root.modelData.icon || "") : ""
    readonly property string appName: root.modelData ? (root.modelData.name || "") : ""

    // The two-letter stand-in, drawn the same way the dock draws it, for an app
    // whose artwork the icon theme does not have.
    readonly property string initials: root.appName.slice(0, 2)

    // ---- the tile itself ------------------------------------------------------
    Rectangle {
        id: plate

        anchors.fill: parent
        radius: Theme.switcherTileRadius

        // Unselected tiles paint nothing: the panel's slab is the background.
        color: root.selected ? Theme.accentWash : "transparent"
        border.width: root.selected ? Theme.hairline : 0
        border.color: Theme.lineStrong

        IconImage {
            id: icon

            anchors.centerIn: parent
            implicitSize: Theme.switcherIconSize
            source: root.iconSource
            asynchronous: true
            visible: root.iconSource !== ""
        }

        Text {
            anchors.centerIn: parent
            visible: !icon.visible
            text: root.initials
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.switcherGlyphSize
            font.weight: Font.DemiBold      // the design's 600
            color: Theme.ink
            textFormat: Text.PlainText
        }
    }

    // ---- how many windows this app has ----------------------------------------
    // Only drawn past one. A "1" on every tile would be noise on every tile, and
    // the number is only ever interesting as "there is more here than you can
    // see" — which is also the hint that the Down arrow does something.
    Rectangle {
        id: pill

        visible: root.windows.length > 1

        anchors.right: plate.right
        anchors.top: plate.top
        anchors.rightMargin: Theme.switcherGap
        anchors.topMargin: Theme.switcherGap

        height: Theme.switcherPillHeight
        width: Math.max(height, count.implicitWidth + Theme.switcherPillPaddingH * 2)
        radius: Theme.switcherPillRadius

        color: Theme.surfaceAlt
        border.width: Theme.hairline
        border.color: Theme.line

        Text {
            id: count

            anchors.centerIn: parent
            text: String(root.windows.length)
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsMicro
            font.weight: Font.DemiBold      // the design's 600
            color: Theme.inkSoft
            textFormat: Text.PlainText
        }
    }

    // ---- the mouse ------------------------------------------------------------
    // The panel is a keyboard thing and always will be, but a surface that
    // ignores the pointer entirely reads as broken — and, more usefully, a click
    // is the way out if the modifier's release was ever missed. See the long
    // note about that in AppSwitcher.qml.
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
