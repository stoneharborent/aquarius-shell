// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// BarItem — one slot in the top bar
// =============================================================================
// Everything that sits in the bar sits in one of these: the logo, the app name,
// the clock, and later the Wi-Fi/battery/tray cluster. It does three jobs and
// no others:
//
//   1. Puts the right amount of space around whatever you put inside it.
//   2. Paints the hover "pill" — a soft tinted rounded rectangle — but ONLY if
//      the item is something you can actually click.
//   3. Reports clicks.
//
// The measurements are the design's: 22px tall, 8px of space inside on the left
// and right, 6px between two things inside the same item, 6px corners on the
// pill. All of them live in Theme.qml; none of them are typed here.
//
// A NOTE ON THE HOVER PILL
//   It is a tint painted ON TOP of the bar, not the bar becoming see-through.
//   The bar itself stays solid. This is the same call the Plasma theme made
//   (os-image/docs/plasma-style.md, "Glass removed") and it is kept here so the
//   two shells look like the same product while both exist.
//
// HOW TO USE IT
//   BarItem {
//       interactive: true
//       onClicked: doSomething()
//       Text { text: "hello" }
//   }
//   Anything you nest inside lands in a horizontal row, centred.
// =============================================================================
import QtQuick

import "../../theme"

Item {
    id: root

    // Anything nested inside this component goes into the row below.
    default property alias contentItems: row.data

    // Set to true for things a person can click. Leave false for labels — an
    // item that lights up on hover but does nothing when clicked is a small lie
    // the interface tells, and those add up.
    property bool interactive: false

    signal clicked()

    // Right-click. Only the system tray needs this: a StatusNotifierItem's menu
    // is opened with the secondary button, and a tray without its menus is not a
    // tray. Everything else in the bar leaves this unconnected, and an
    // unconnected signal costs nothing.
    signal rightClicked()

    implicitWidth: row.implicitWidth + Theme.barItemPaddingH * 2
    implicitHeight: Theme.barItemHeight

    // The hover / pressed pill.
    Rectangle {
        anchors.fill: parent
        radius: Theme.barItemRadius
        visible: root.interactive && (mouse.containsMouse || mouse.pressed)
        color: mouse.pressed ? Theme.pressWash : Theme.hoverWash
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.barItemGap
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function (event) {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
