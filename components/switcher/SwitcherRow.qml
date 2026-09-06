// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SwitcherRow — one WINDOW, drawn as a line rather than as a tile
// =============================================================================
// The switcher lists windows in two places, and they are the same row at two
// sizes, so this is one file with a `compact` switch rather than two files that
// would drift apart:
//
//   compact: false   THE WINDOWS PROFILE'S WHOLE PANEL. 52 high, a 32px icon,
//                    the window's title over the application's name.
//
//                      ┌────────────────────────────────────────────┐
//                      │  ▇▇   Untitled document — 3                │
//                      │  ▇▇   LibreOffice Writer                   │
//                      └────────────────────────────────────────────┘
//
//   compact: true    THE MAC PROFILE'S DOWN-ARROW LIST, which drops under the
//                    row of tiles to show one app's windows. 36 high, a 20px
//                    icon, the title alone — the application's name would be the
//                    same on every line, since every line IS that application.
//
//                      ┌────────────────────────────────────────────┐
//                      │ ▪  Untitled document — 3                   │
//                      └────────────────────────────────────────────┘
//
// Selected is the same in both: an `accentWash` fill and a `lineStrong` edge,
// exactly as a selected tile.
//
// NOT PROVEN ON HARDWARE. Checked statically (tests/test-shell.sh section 38).
// =============================================================================
import QtQuick

import Quickshell.Widgets

import "../../theme"

Item {
    id: root

    // The window this line stands for.
    //
    // ⚠️ NOT `window`. Qt attaches a `window` property to items inside a Window,
    //   and a name an object already has is found before a name this file
    //   declares — the exact bug section 26 of tests/test-shell.sh exists to
    //   catch, written up at the PanelWindow in components/search/FlowSearch.qml.
    required property var toplevel

    // The icon and the application name to draw. Passed in rather than looked
    // up here: the caller already has the resolved entry, and asking
    // AppIdentity again once per row per repaint would be work for no answer
    // that could differ.
    property string iconSource: ""
    property string appName: ""

    // Short form (the Mac profile's expanded list) or full (the Windows
    // profile's panel). See the drawing above.
    property bool compact: false

    property bool selected: false

    signal clicked()

    readonly property string title: root.toplevel
        ? (root.toplevel.title && root.toplevel.title !== ""
            ? root.toplevel.title
            : root.appName)
        : ""

    implicitHeight: root.compact
        ? Theme.switcherExpandRowHeight
        : Theme.switcherWindowRowHeight
    height: implicitHeight

    Rectangle {
        id: plate

        anchors.fill: parent
        radius: root.compact
            ? Theme.switcherExpandRowRadius
            : Theme.switcherWindowRowRadius

        color: root.selected ? Theme.accentWash : "transparent"
        border.width: root.selected ? Theme.hairline : 0
        border.color: Theme.lineStrong

        IconImage {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: root.compact
                ? Theme.switcherExpandRowPaddingH
                : Theme.switcherWindowRowPaddingH
            anchors.verticalCenter: parent.verticalCenter

            implicitSize: root.compact
                ? Theme.switcherExpandIconSize
                : Theme.switcherWindowIconSize
            source: root.iconSource
            asynchronous: true
            visible: root.iconSource !== ""
        }

        // ---- the words -------------------------------------------------------
        // A Column rather than two anchored Texts, so that the compact form —
        // which has one line, not two — centres correctly without a second set
        // of anchors that only applies half the time.
        Column {
            anchors.left: icon.visible ? icon.right : parent.left
            anchors.leftMargin: root.compact
                ? Theme.switcherExpandRowGap
                : Theme.switcherWindowRowGap
            anchors.right: parent.right
            anchors.rightMargin: root.compact
                ? Theme.switcherExpandRowPaddingH
                : Theme.switcherWindowRowPaddingH
            anchors.verticalCenter: parent.verticalCenter

            spacing: 0

            Text {
                width: parent.width

                text: root.title
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsBody
                // The design's 400 in the compact list, 500 in the full row: a
                // title that has a second line under it has to win against it.
                font.weight: root.compact ? Font.Normal : Font.Medium
                color: Theme.ink
                textFormat: Text.PlainText

                // A window title is somebody else's string and can be any
                // length at all. Eliding at the end keeps the panel the width
                // the design says it is.
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                visible: !root.compact && root.appName !== ""

                text: root.appName
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsCaption
                font.weight: Font.Normal        // the design's 400
                color: Theme.inkMute
                textFormat: Text.PlainText

                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
