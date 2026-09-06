// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// MenuRow — one line in the Aquarius (logo) menu
// =============================================================================
// The logo menu is a short list of plain text items — About This PC, System
// Settings, and the session actions — in the manner of the Apple menu. This is
// one of those lines, and a separator is drawn by this same file when
// `isSeparator` is set, so LogoMenu.qml can hand the whole list to one Repeater
// without a second delegate.
//
// WHAT A ROW LOOKS LIKE
//
//   ┌──────────────────────────────────┐
//   │  About This PC                    │   <- normal
//   │  Restart              Confirm?    │   <- armed: a second click runs it
//   │  Updates unavailable              │   <- disabled: quiet, ignores the mouse
//   ├──────────────────────────────────┤   <- a separator (isSeparator: true)
//   └──────────────────────────────────┘
//
// It knows nothing about what any item DOES. It draws a label, lights up when it
// is the selected/hovered one, says "Confirm?" when it has been armed, and
// reports that it was clicked or that the pointer moved onto it. LogoMenu.qml
// owns the meaning, the selection and the two-step confirm.
//
// Every colour and size comes from Theme; there is not a hex value or a bare
// pixel in this file, the same rule the rest of the shell obeys.
// =============================================================================
import QtQuick

import "../../theme"

Item {
    id: root

    // The bold text of the item. Empty for a separator.
    property string label: ""

    // A quiet trailing note on the right. Today only the confirm prompt uses it.
    property string note: ""

    // Draw a dividing rule instead of a row. LogoMenu puts one between the
    // top group and the session actions.
    property bool isSeparator: false

    // The keyboard/hover selection is on this row.
    property bool selected: false

    // Greyed and unclickable — the "Updates unavailable" case.
    property bool disabled: false

    // Armed by a first activation and waiting for a second. Destructive items
    // (Restart, Power Off, Log Out) use this so a stray click cannot end the
    // session; the row says "Confirm?" while it is armed.
    property bool awaitingConfirm: false

    signal activated()

    // The pointer moved onto this row. LogoMenu makes it the selected one, so
    // that mouse and keyboard share a single highlight.
    signal hovered()

    implicitWidth: rowLabel.implicitWidth + Theme.logoMenuRowPaddingH * 2
                   + (noteLabel.visible ? noteLabel.implicitWidth + Theme.logoMenuRowGap : 0)
    implicitHeight: root.isSeparator
                    ? Theme.hairline + Theme.logoMenuSeparatorMargin * 2
                    : Theme.logoMenuRowHeight

    // ---- a separator ---------------------------------------------------------
    Rectangle {
        visible: root.isSeparator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.logoMenuSeparatorMargin
        anchors.rightMargin: Theme.logoMenuSeparatorMargin
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.hairline
        color: Theme.line
    }

    // ---- a real row ----------------------------------------------------------
    Rectangle {
        visible: !root.isSeparator
        anchors.fill: parent
        anchors.leftMargin: Theme.logoMenuSeparatorMargin
        anchors.rightMargin: Theme.logoMenuSeparatorMargin
        radius: Theme.radiusSm

        // A selected/hovered row lights with the ordinary hover wash; while it
        // is pressed it deepens to the press wash, the same two-tone the bar
        // items use. A disabled row never lights.
        color: root.disabled ? "transparent"
             : mouse.pressed ? Theme.pressWash
             : root.selected  ? Theme.hoverWash
                              : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFast
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeOut
            }
        }

        Text {
            id: rowLabel
            anchors.left: parent.left
            anchors.leftMargin: Theme.logoMenuRowPaddingH - Theme.logoMenuSeparatorMargin
            // Fill the width the card gives us and elide if a label (or a long
            // drive name) does not fit, rather than overflowing the card. The
            // card has a fixed width, so this cannot feed back into its size.
            anchors.right: noteLabel.visible ? noteLabel.left : parent.right
            anchors.rightMargin: noteLabel.visible
                                 ? Theme.logoMenuRowGap
                                 : (Theme.logoMenuRowPaddingH - Theme.logoMenuSeparatorMargin)
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsBody
            color: root.disabled ? Theme.inkMute : Theme.ink
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            id: noteLabel
            anchors.right: parent.right
            anchors.rightMargin: Theme.logoMenuRowPaddingH - Theme.logoMenuSeparatorMargin
            anchors.verticalCenter: parent.verticalCenter
            visible: root.note.length > 0
            text: root.note
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsMicro
            // The confirm prompt is the only note there is, and it is a warning,
            // so it takes the danger role rather than a quiet grey.
            color: Theme.danger
            textFormat: Text.PlainText
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !root.isSeparator && !root.disabled
        hoverEnabled: enabled
        acceptedButtons: Qt.LeftButton
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: root.hovered()
        onClicked: root.activated()
    }

    Accessible.role: root.isSeparator ? Accessible.Separator : Accessible.MenuItem
    Accessible.name: root.label
    Accessible.description: root.awaitingConfirm ? qsTr("Activate again to confirm") : ""
}
