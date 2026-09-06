// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// QsTile — the look of one Quick Settings toggle
// =============================================================================
// One quarter of the 2x2 grid:
//
//   ┌──────────────────────────────┐
//   │  ╭───╮   Wi-Fi               │   <- title, 12px, semibold
//   │  │ ((•│  HarborNet 5G        │   <- subtitle, 11px, quiet
//   │  ╰───╯                       │
//   └──────────────────────────────┘
//     ^ the 32px round chip. Lit, it fills with the accent and the glyph goes
//       to the on-accent colour. Unlit, it is a soft wash of the ink.
//
// This file knows NOTHING about Wi-Fi, Bluetooth, batteries or power. It is the
// look and the click, and that is all. Each Tile*.qml supplies the meaning. That
// split is what lets one of them fail to load (see QsTileSlot.qml) without
// taking the panel with it.
//
// THE THREE STATES, AND WHY THE THIRD ONE MATTERS
//   on          the thing is switched on. Accent wash, filled chip.
//   off         the thing is switched off. Ink wash, ink chip.
//   unavailable there is nothing to switch — no Bluetooth chip in the machine,
//               no power profiles daemon. The tile still DRAWS, so the grid
//               keeps its shape, but it is dimmed and ignores clicks.
//
//   Leaving a hole in a 2x2 grid reads as broken rather than as deliberate. A
//   dimmed tile reads as "your computer does not have this", which is the truth.
//
// Every number and colour here comes from Theme. See the QUICK SETTINGS block in
// theme/Theme.qml for where the design took them from.
// =============================================================================
import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    // --- what a Tile*.qml sets ------------------------------------------------

    // The bold line: "Wi-Fi", "Bluetooth", "Focus".
    property string title: ""

    // The quiet line under it: the network name, the connected devices, "Off".
    property string subtitle: ""

    // A key from QsGlyph's table. A name that is not in that table draws nothing
    // and is caught by tests/test-shell.sh, not at runtime.
    property string glyph: ""

    // Is the thing switched on? The only input to the "lit" look.
    property bool active: false

    // False when the hardware or the service behind this tile is missing.
    property bool available: true

    // Some tiles have a fuller settings page behind them — Wi-Fi has a network
    // picker, Bluetooth a device list, Performance the whole power panel. When a
    // tile sets this true it grows a small chevron in its top-right corner, a
    // SEPARATE hit target from the switch: tapping the tile still toggles, and
    // tapping the chevron opens that page. Focus (a shell switch, nothing behind
    // it) and Game Mode (a session hand-off, not a settings page) leave it false.
    // Added 2026-09-06 (R6).
    property bool hasDetail: false

    // Emitted on click. The Tile*.qml decides what a click means — and for
    // TileGameMode it does not mean "toggle" at all, which is why this signal is
    // named for the gesture rather than for a state change.
    signal activated()

    // Emitted when the detail chevron is used, by click or by keyboard. The
    // Tile*.qml that sets `hasDetail` handles this by opening its Settings page.
    signal detailRequested()

    implicitHeight: Theme.qsTileHeight
    radius: Theme.radiusLg

    color: !root.available          ? Theme.tileDisabled
         : root.active              ? (mouse.containsMouse ? Theme.tileActiveHover
                                                           : Theme.tileActive)
         : mouse.containsMouse      ? Theme.tileHover
                                    : Theme.tileIdle

    border.width: Theme.hairline
    border.color: Theme.line

    opacity: root.available ? 1.0 : 0.45

    // A short fade, so toggling reads as a switch moving rather than as the
    // panel redrawing itself.
    Behavior on color {
        ColorAnimation {
            duration: Theme.durFast
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeOut
        }
    }

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.title
    Accessible.description: root.subtitle
    Accessible.checked: root.active

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.qsTilePaddingH
        // Keep the two text lines clear of the chevron in the top-right corner
        // when there is one, so a long network name does not run under it.
        anchors.rightMargin: root.hasDetail ? Theme.qsDetailHitSize : Theme.qsTilePaddingH
        anchors.topMargin: Theme.qsTilePaddingV
        anchors.bottomMargin: Theme.qsTilePaddingV
        spacing: Theme.qsTileInnerGap

        // The round chip.
        Rectangle {
            Layout.preferredWidth: Theme.qsChipSize
            Layout.preferredHeight: Theme.qsChipSize
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2

            color: root.active ? Theme.accent : Theme.tileChip

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durFast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeOut
                }
            }

            QsGlyph {
                anchors.centerIn: parent
                glyph: root.glyph
                size: Theme.qsChipGlyphSize

                // On a lit chip the glyph sits on solid accent, so it has to be
                // the colour the theme keeps for exactly that: text drawn on top
                // of a filled accent shape.
                color: root.active ? Theme.inkOnAccent : Theme.ink
            }
        }

        // The two lines.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.ink
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsCaption
                font.weight: Font.DemiBold      // the design's 600
                textFormat: Text.PlainText
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                visible: text.length > 0

                // The design writes this as the primary text at 72% opacity.
                // This shell has a named role for second-tier text — inkSoft —
                // and uses it, because a theme with an answer for "quieter text"
                // should not be overridden by an opacity trick. It is the same
                // colour to the eye and it survives a theme flip.
                color: Theme.inkSoft
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsMicro
                textFormat: Text.PlainText
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.available
        enabled: root.available
        acceptedButtons: Qt.LeftButton
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }

    // ---- the detail chevron --------------------------------------------------
    // A distinct hit target from the switch above. It is DECLARED AFTER `mouse`
    // so it stacks above it in the corner it covers: a click that lands on the
    // chevron opens the settings page, a click anywhere else on the tile toggles
    // the switch. Only present when the tile has a page behind it AND the thing
    // is available at all — offering "more settings" for hardware that is not
    // there would be a dead end.
    Item {
        id: detail
        visible: root.hasDetail && root.available
        enabled: detail.visible

        width: Theme.qsDetailHitSize
        height: Theme.qsDetailHitSize
        anchors.top: parent.top
        anchors.right: parent.right

        // Reachable from the keyboard as well as the pointer. The Quick Settings
        // panel does not take keyboard focus today (it opens as a PopupWindow
        // without it), so Tab cannot reach this yet — but the handlers are here
        // so it works the day it can, the same forward-looking choice the dock's
        // add tile made.
        activeFocusOnTab: detail.visible
        Keys.onReturnPressed: root.detailRequested()
        Keys.onEnterPressed: root.detailRequested()
        Keys.onSpacePressed: root.detailRequested()

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("%1 settings").arg(root.title)
        Accessible.description: qsTr("Open the full settings page")

        QsGlyph {
            anchors.centerIn: parent
            glyph: "chevron"
            size: Theme.qsDetailArrowSize
            // Quiet by default, and it lifts to the primary ink when the pointer
            // is over its box, so it is discoverable without shouting.
            color: chevronMouse.containsMouse ? Theme.ink : Theme.inkMute
        }

        // A faint focus ring, so keyboard users can see where they are once the
        // panel can be tabbed into.
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.hairline
            radius: Theme.radiusSm
            color: "transparent"
            border.width: Theme.hairline
            border.color: Theme.accent
            visible: detail.activeFocus
        }

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detailRequested()
        }
    }
}
