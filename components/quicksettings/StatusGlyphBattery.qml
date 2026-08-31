// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// StatusGlyphBattery — the battery in the top bar
// =============================================================================
// The same UPower aggregate device the Quick Settings footer reads, drawn with
// the same QsBatteryGlyph. On a machine with no battery it takes no space at
// all, which is why it is an Item wrapping the glyph rather than the glyph
// itself: an invisible zero-width Item lets the bar close up cleanly.
//
// The number is deliberately NOT drawn beside it. The design's bar shows a
// battery pictogram and no percentage — the percentage lives in the Quick
// Settings panel, one click away. A bar that shows every number it has is a
// dashboard, and this is a bar.
// =============================================================================
import QtQuick

import Quickshell.Services.UPower

import "../../theme"

Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool haveBattery:
        root.device !== null && root.device.ready && root.device.isLaptopBattery

    visible: root.haveBattery
    implicitWidth: root.haveBattery ? glyph.implicitWidth : 0
    implicitHeight: root.haveBattery ? glyph.implicitHeight : 0

    Accessible.role: Accessible.StaticText
    Accessible.name: root.haveBattery
        ? qsTr("Battery %1%").arg(Math.round(root.device.percentage))
        : ""

    QsBatteryGlyph {
        id: glyph

        anchors.centerIn: parent

        // Scaled down from the panel's 22x11 to sit inside a 22px-tall bar item
        // without crowding it. The glyph keeps its proportions because both
        // numbers come from the same pair of tokens.
        implicitWidth: Theme.barGlyphSize + 3
        implicitHeight: implicitWidth * Theme.qsBatteryGlyphHeight
                        / Theme.qsBatteryGlyphWidth

        level: root.haveBattery
            ? Math.max(0, Math.min(1, root.device.percentage / 100))
            : 0
        charging: root.haveBattery
            && root.device.state === UPowerDeviceState.Charging
    }
}
