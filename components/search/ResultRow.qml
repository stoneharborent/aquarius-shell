// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// ResultRow — one line in the Flow Search palette
// =============================================================================
// The design's `.res` rule, in QML:
//
//   ┌──────────────────────────────────────────────────────────┐
//   │ ▢  Kdenlive                                     ↵ open   │
//   │    Edit videos                                            │
//   └──────────────────────────────────────────────────────────┘
//     ^  ^                                            ^
//     |  |                                            the key cap (.res kbd)
//     |  title (bold) over subtitle (quiet)
//     the 30x30 tile: a real icon if the system theme has one, else
//     the two-letter monogram the design draws, else a single glyph
//
// COLOUR COMES IN AS A ROLE NAME, NOT AS A COLOUR
//   `tint` is the string "accent", "success", "warn", "danger" or "ink", and
//   the switch below turns it into a Theme value. That is what lets
//   SearchEngine.qml decide a calculator row is green without SearchEngine.qml
//   containing green — the repo's one-source-of-truth rule, kept intact through
//   a layer that has no business knowing about colour.
//
// WHY ANCHORS AND NOT A Row
//   A Row positions its children horizontally and leaves their vertical
//   position alone, so anchoring a child of a Row to its vertical centre is the
//   kind of thing that works until it does not. Three anchored items is plainer
//   and has one behaviour.
// =============================================================================
import QtQuick

import Quickshell.Widgets

import "../../theme"

Item {
    id: root

    // The result object from SearchEngine. See that file for the field list.
    required property var result

    // Drawn as the selected row — the one Enter will act on.
    property bool selected: false

    // Set while this row is waiting for a second Enter (see FlowSearch.qml).
    property bool awaitingConfirm: false

    signal activated()

    implicitHeight: Math.max(tile.height, labels.implicitHeight)
        + Theme.searchRowPaddingV * 2

    Accessible.role: Accessible.Button
    Accessible.name: root.result.title
    Accessible.description: root.awaitingConfirm
        ? qsTr("Press Enter again to confirm")
        : root.result.subtitle

    // ---- which theme colour "tint" means ------------------------------------
    readonly property color tintColor: {
        switch (root.result.tint) {
        case "accent": return Theme.accent;
        case "success": return Theme.success;
        case "warn": return Theme.warn;
        case "danger": return Theme.danger;
        default: return Theme.inkSoft;
        }
    }

    // ---- the row's own background -------------------------------------------
    // Selected wins over hover: the keyboard is the primary way through this
    // list, and a mouse drifting across it must not look like it has taken over.
    Rectangle {
        anchors.fill: parent
        radius: Theme.searchRowRadius
        color: root.selected
            ? Theme.accentWash
            : (mouse.containsMouse ? Theme.hoverWash : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFast
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeOut
            }
        }
    }

    // ---- the tile --------------------------------------------------------------
    Rectangle {
        id: tile

        anchors.left: parent.left
        anchors.leftMargin: Theme.searchRowPaddingH
        anchors.verticalCenter: parent.verticalCenter

        width: Theme.searchRowIconSize
        height: Theme.searchRowIconSize
        radius: Theme.searchRowIconRadius

        // No plate behind a real application icon — icons are drawn to sit on
        // the desktop, not inside a chip. The plate is what makes a monogram or
        // a glyph read as an icon-shaped thing.
        color: icon.visible ? "transparent" : Theme.surfaceAlt

        IconImage {
            id: icon

            anchors.fill: parent
            asynchronous: true
            source: root.result.iconSource || ""

            // Quickshell.iconPath(name, true) returns "" when the icon theme has
            // nothing by that name, so an empty source means "fall back to the
            // monogram", not "still loading".
            visible: root.result.iconSource !== ""
        }

        Text {
            anchors.centerIn: parent
            visible: !icon.visible

            text: root.result.glyph !== ""
                ? root.result.glyph
                : root.result.monogram

            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fsCaption
            font.weight: Font.DemiBold
            color: root.result.glyph !== "" ? root.tintColor : Theme.inkSoft
            textFormat: Text.PlainText
        }
    }

    // ---- the key cap ------------------------------------------------------------
    // Only the selected row shows one, because it is a statement about what
    // Enter does right now, and Enter only does one thing at a time.
    Rectangle {
        id: hint

        anchors.right: parent.right
        anchors.rightMargin: Theme.searchRowPaddingH
        anchors.verticalCenter: parent.verticalCenter

        visible: root.selected && root.result.hint !== ""

        width: hintLabel.implicitWidth + Theme.searchHintPaddingH * 2
        height: hintLabel.implicitHeight + Theme.searchHintPaddingV * 2
        radius: Theme.searchHintRadius
        color: "transparent"
        border.width: Theme.hairline
        border.color: Theme.lineStrong

        Text {
            id: hintLabel
            anchors.centerIn: parent
            text: root.awaitingConfirm ? qsTr("↵ again") : root.result.hint
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsMonoSm
            font.weight: Font.Medium
            color: root.awaitingConfirm ? Theme.danger : Theme.inkMute
            textFormat: Text.PlainText
        }
    }

    // ---- title and subtitle ------------------------------------------------------
    Column {
        id: labels

        anchors.left: tile.right
        anchors.leftMargin: Theme.searchRowGap
        anchors.right: parent.right
        anchors.rightMargin: Theme.searchRowPaddingH
            + (hint.visible ? hint.width + Theme.searchRowGap : 0)
        anchors.verticalCenter: parent.verticalCenter

        spacing: 0

        Text {
            width: parent.width
            text: root.result.title
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsSmall     // design 13px; the ladder's nearest step
            font.weight: Font.Medium
            color: Theme.ink
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text.length > 0

            // While a destructive action waits for its second Enter, the
            // subtitle says so. It is the only place that can say it without
            // moving anything else on screen.
            text: root.awaitingConfirm
                ? qsTr("Press Enter again to confirm")
                : root.result.subtitle

            font.family: Theme.fontBody
            font.pixelSize: Theme.fsCaption   // design 11px; nearest step
            color: root.awaitingConfirm ? Theme.danger : Theme.inkMute
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
