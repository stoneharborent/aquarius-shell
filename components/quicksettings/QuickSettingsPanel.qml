// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// QuickSettingsPanel — the 330px drawer, exactly as the V2 design draws it
// =============================================================================
//   ┌────────────────────────────────────────┐
//   │  ┌───────────────┐  ┌───────────────┐  │
//   │  │ ((• Wi-Fi     │  │  ᛒ  Bluetooth │  │   the 2x2 grid
//   │  │     HarborNet │  │     Pad · Buds│  │
//   │  └───────────────┘  └───────────────┘  │
//   │  ┌───────────────┐  ┌───────────────┐  │
//   │  │  ☾  Focus     │  │  🎮 Game Mode │  │   <- 4th tile is adaptive
//   │  │     Notifs on │  │     Switch    │  │
//   │  └───────────────┘  └───────────────┘  │
//   │                                        │
//   │  Sound                            64%  │
//   │  ●━━━━━━━━━━━○──────────────────────   │
//   │  Brightness                       80%  │
//   │  ●━━━━━━━━━━━━━━━━○─────────────────   │
//   │  ────────────────────────────────────  │
//   │  ▮▮▮▯ Battery 82% · about 6 hr left    │
//   └────────────────────────────────────────┘
//
// WHAT THIS PANEL IS FOR, IN ONE SENTENCE
//   Everything a person reaches for most, in one drawer, instead of six little
//   popups hanging off six different tray icons. That is the whole idea, and it
//   is the same idea the KDE Wave-2 widget shipped: KDE has no such panel out of
//   the box, and turning Bluetooth off and turning the volume down are two
//   clicks in two different places there.
//
// WHY THE FOUR TILES ARE LOADED AND THE TWO SLIDERS ARE NOT
//   A tile that fails to load has to leave a placeholder behind, or the 2x2 grid
//   gets a hole in it and the panel looks broken. A slider that fails can simply
//   not be there — the panel gets shorter and nothing is misaligned. So tiles go
//   through QsTileSlot (read its header; the Wi-Fi tile genuinely needs it
//   today) and sliders are plain children that hide themselves.
//
// THE DESIGN'S "All settings" LINK IS DELIBERATELY MISSING
//   The V2 footer ends with an "All settings" link. The KDE port pointed it at
//   `systemsettings`, because KDE has a settings app. This shell does not have
//   one yet — a Settings surface is Phase P3 — and a link that opens nothing is
//   worse than no link. When P3 ships one, it goes here, on the right of the
//   battery line, and the battery line stops filling the width.
//
// SIZE
//   The design says 330px wide with 16px of padding. The height is whatever the
//   contents come to, which is what lets the panel shrink on a desktop where the
//   battery line and possibly the brightness slider are both hidden.
// =============================================================================
import QtQuick
import QtQuick.Layouts

import "../../theme"

Item {
    id: root

    // True while the panel is actually on screen. Passed down to anything that
    // would otherwise poll in the background forever — today that is the
    // brightness slider, which runs a subprocess to read the backlight.
    property bool live: false

    implicitWidth: Theme.qsWidth
    implicitHeight: content.implicitHeight + Theme.qsPadding * 2

    // The panel's own surface. `surface` is the theme's brightest paper — the
    // colour it keeps for cards and popups — sitting above the bar's `panel`.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surface
        border.width: Theme.hairline
        border.color: Theme.lineStrong
    }

    // Works out whether this is a handheld, and therefore what goes in the
    // fourth square. Read QsPlatform.qml before changing anything about it.
    QsPlatform {
        id: platform
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Theme.qsPadding
        spacing: 0

        // ---- 1. the four toggles --------------------------------------------
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.qsTileGap
            rowSpacing: Theme.qsTileGap

            QsTileSlot {
                Layout.fillWidth: true
                tileSource: "TileWifi.qml"
                fallbackTitle: qsTr("Wi-Fi")
                fallbackGlyph: "wifi-off"
            }

            QsTileSlot {
                Layout.fillWidth: true
                tileSource: "TileBluetooth.qml"
                fallbackTitle: qsTr("Bluetooth")
                fallbackGlyph: "bluetooth-off"
            }

            QsTileSlot {
                Layout.fillWidth: true
                tileSource: "TileFocus.qml"
                fallbackTitle: qsTr("Focus")
                fallbackGlyph: "moon"
            }

            // The adaptive one: Game Mode on a handheld, Performance elsewhere.
            QsTileSlot {
                Layout.fillWidth: true
                tileSource: platform.fourthTileSource
                fallbackTitle: platform.fourthTileFallbackTitle
                fallbackGlyph: platform.fourthTileFallbackGlyph
            }
        }

        // ---- 2. the sliders --------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.qsSlidersTop
            spacing: Theme.qsSliderGap

            SliderVolume {
                Layout.fillWidth: true
            }

            SliderBrightness {
                Layout.fillWidth: true
                live: root.live
            }
        }

        // ---- 3. the battery line ---------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.qsFooterTop
            Layout.preferredHeight: Theme.hairline
            color: Theme.line

            // On a desktop with no battery there is nothing under this rule, so
            // the rule itself would be a line with nothing below it.
            visible: battery.visible
        }

        BatteryLine {
            id: battery
            Layout.fillWidth: true
            Layout.topMargin: Theme.qsFooterPaddingTop
        }
    }
}
