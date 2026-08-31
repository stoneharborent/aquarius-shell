// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// Theme — the ONE place every component asks about colour, size and type
// =============================================================================
// THE RULE, AND IT IS THE WHOLE POINT OF THIS FILE
//   No component anywhere in this repo may contain a colour value, a font name,
//   or a hand-typed pixel size. Components ask this file. This file asks Ice.qml
//   or Midnight.qml. That is the only path.
//
//   Why so strict? Because a shell is dozens of small pieces, and the moment two
//   of them disagree about what "the quiet grey" is, the desktop stops looking
//   designed and starts looking assembled. Every desktop that looks cheap looks
//   cheap for exactly this reason.
//
// HOW TO SWITCH THEMES
//   Change `dark` below. Everything repaints, because every component's colour
//   is a live binding through here.
//
//   Later (Phase P3) this will follow the system's own light/dark setting via
//   the freedesktop appearance portal, the same signal GNOME and KDE apps read.
//   It is a one-line change here when that lands: `dark` stops being a stored
//   value and becomes a binding to the portal. Nothing else in the repo moves.
//
// WHERE THE SIZES COME FROM
//   The V2 design system — os-image/branding/design-system/, specifically the
//   "AquariusOS Desktop Shell.html" artboard and tokens/{spacing,typography,
//   effects}.css. Those artboards are drawn at 1280x800, and the numbers below
//   are that drawing's numbers. Colour is the one thing NOT taken from V2: V2's
//   palette is the old dark "Flow State" identity, and colour now comes from
//   Ice. Geometry and type carry over unchanged.
// =============================================================================
pragma Singleton

import Quickshell

Singleton {
    id: root

    // =========================================================================
    // WHICH PALETTE IS IN FORCE
    // =========================================================================
    // false = Ice (light) — AquariusOS's main theme.
    // true  = Midnight (dark).
    property bool dark: false

    // `colors` is the palette object itself. Components normally use the
    // shortcuts underneath instead, but a component that wants to pass a whole
    // palette around can use this.
    readonly property var colors: root.dark ? Midnight : Ice

    // --- Colour shortcuts -----------------------------------------------------
    // These exist so a component writes `Theme.ink` instead of
    // `Theme.colors.ink`, which is shorter to read and shorter to get wrong.
    readonly property color bg: root.colors.bg
    readonly property color bgSoft: root.colors.bgSoft
    readonly property color surface: root.colors.surface
    readonly property color surfaceAlt: root.colors.surfaceAlt
    readonly property color panel: root.colors.panel

    readonly property color ink: root.colors.ink
    readonly property color inkProse: root.colors.inkProse
    readonly property color inkSoft: root.colors.inkSoft
    readonly property color inkMute: root.colors.inkMute

    readonly property color line: root.colors.line
    readonly property color lineStrong: root.colors.lineStrong

    readonly property color hoverWash: root.colors.hoverWash
    readonly property color pressWash: root.colors.pressWash

    readonly property color success: root.colors.success
    readonly property color warn: root.colors.warn
    readonly property color danger: root.colors.danger
    readonly property color starred: root.colors.starred

    readonly property color accent: root.colors.accent
    readonly property color onAccent: root.colors.onAccent

    // Quick Settings washes. See the note beside them in Ice.qml.
    readonly property color tileIdle: root.colors.tileIdle
    readonly property color tileHover: root.colors.tileHover
    readonly property color tileChip: root.colors.tileChip
    readonly property color tileDisabled: root.colors.tileDisabled
    readonly property color tileActive: root.colors.tileActive
    readonly property color tileActiveHover: root.colors.tileActiveHover
    readonly property color trackIdle: root.colors.trackIdle
    readonly property color handleFill: root.colors.handleFill
    readonly property color handleShadow: root.colors.handleShadow

    // =========================================================================
    // SPACING — the step ladder every gap in the shell is built from
    // =========================================================================
    // Straight out of tokens/spacing.css. If a gap in a design is not on this
    // ladder, the design is wrong or the measurement is wrong — check before
    // inventing a number.
    readonly property int sp1: 4
    readonly property int sp2: 8
    readonly property int sp3: 12
    readonly property int sp4: 16
    readonly property int sp5: 24
    readonly property int sp6: 32
    readonly property int sp7: 48
    readonly property int sp8: 64

    // =========================================================================
    // CORNERS
    // =========================================================================
    readonly property int radiusSm: 7    // inputs, toggles
    readonly property int radiusMd: 9    // buttons
    readonly property int radiusLg: 12   // cards
    readonly property int radiusXl: 16   // panels, windows

    // =========================================================================
    // CONTROLS
    // =========================================================================
    readonly property int controlHeight: 36
    readonly property int controlHeightSm: 28

    // =========================================================================
    // THE TOP BAR — measured off the V2 artboard
    // =========================================================================
    // <header style="height:30px; padding:0 10px; gap:2px;
    //                border-bottom:1px solid ...">
    //   .bar-item { height:22px; padding:0 8px; gap:6px; border-radius:6px }
    readonly property int barHeight: 30          // the whole bar
    readonly property int barPaddingH: 10        // space before the first / after the last item
    readonly property int barItemSpacing: 2      // space BETWEEN bar items
    readonly property int barItemHeight: 22      // the hover pill's height
    readonly property int barItemPaddingH: 8     // space inside a bar item, left and right
    readonly property int barItemGap: 6          // space between two things inside one item
    readonly property int barItemRadius: 6       // the hover pill's corners
    readonly property int barLogoSize: 14        // the Aquarius mark, drawn 14x14
    readonly property int hairline: 1            // every 1px rule in the shell
    readonly property int barGlyphSize: 15       // a status glyph (Wi-Fi, speaker) in the bar
    readonly property int barTrayIconSize: 16    // a system tray application's own icon

    // =========================================================================
    // QUICK SETTINGS — measured off the V2 artboard
    // =========================================================================
    // Source: os-image/branding/design-system/"AquariusOS Desktop Shell.html",
    // the `#ovTray` block and the `.qs-toggle` / `.slider` rules beside it:
    //
    //   .panel  { right:12px; top:38px; width:330px; padding:16px;
    //             border-radius: var(--radius-lg) }
    //   grid    { grid-template-columns:1fr 1fr; gap:10px }
    //   .qs-toggle { padding:10px 12px; border-radius:12px; gap:10px }
    //   .qs-toggle .ic { width:32px; height:32px; border-radius:50% }
    //   sliders { margin-top:16px; gap:14px }  label row { margin-bottom:8px }
    //   .slider { height:6px }  .slider u { width:16px; height:16px }
    //   footer  { margin-top:14px; padding-top:12px; gap:8px }
    //
    // The panel's corner uses radiusLg (12), which is what the design's
    // var(--radius-lg) resolves to — NOT radiusXl, even though the comment on
    // radiusXl says "panels". The design is the authority here.
    readonly property int qsWidth: 330
    readonly property int qsPadding: 16
    readonly property int qsTileGap: 10          // between tiles, both directions
    readonly property int qsTileHeight: 52       // 10 + 32 chip + 10
    readonly property int qsTilePaddingH: 12
    readonly property int qsTilePaddingV: 10
    readonly property int qsTileInnerGap: 10     // chip -> text
    readonly property int qsChipSize: 32
    readonly property int qsChipGlyphSize: 15
    readonly property int qsSlidersTop: 16       // grid -> first slider
    readonly property int qsSliderGap: 14        // slider -> slider
    readonly property int qsSliderLabelGap: 8    // label row -> track
    readonly property int qsTrackHeight: 6
    readonly property int qsHandleSize: 16
    readonly property int qsFooterTop: 14        // last slider -> the hairline
    readonly property int qsFooterPaddingTop: 12 // the hairline -> the battery line
    readonly property int qsFooterGap: 8
    readonly property int qsBatteryGlyphWidth: 22
    readonly property int qsBatteryGlyphHeight: 11

    // Where the panel sits once it is open: the design draws it 38px from the
    // top of a 30px bar, i.e. 8px of air under the bar.
    //
    // The design's other number — 12px in from the right edge of the screen —
    // is NOT a token, because it is not set anywhere. The panel hangs off the
    // right-hand end of the bar's own contents, so barPaddingH (10) plus the
    // status item's padding already puts it there. Writing 12 as well would
    // inset it twice.
    readonly property int qsPopupGap: 8

    // =========================================================================
    // TYPE
    // =========================================================================
    // The OS installs Sora, Inter and JetBrains Mono as system fonts. In the
    // nested test harness on somebody else's machine they may be missing, so
    // each family below ends in a generic name — the shell then falls back to
    // whatever that machine has rather than rendering boxes. See harness/README.md.
    readonly property string fontDisplay: "Sora"
    readonly property string fontBody: "Inter"
    readonly property string fontMono: "JetBrains Mono"
    readonly property string fontDisplayFallback: "sans-serif"
    readonly property string fontBodyFallback: "sans-serif"
    readonly property string fontMonoFallback: "monospace"

    // The scale, from tokens/typography.css. Sizes are in points-as-pixels the
    // same way the design draws them; Qt's `font.pixelSize` is the matching
    // property, NOT `font.pointSize` (which would rescale with system DPI and
    // stop matching the artboard).
    readonly property int fsHero: 64
    readonly property int fsDisplay: 48
    readonly property int fsTitle: 34
    readonly property int fsHeading: 24
    readonly property int fsSubhead: 18
    readonly property int fsBody: 15
    readonly property int fsSmall: 14      // design says 13.5px; Qt wants a whole number
    readonly property int fsCaption: 12    // <- the top bar's size, and a QS tile's title
    readonly property int fsMicro: 11      // <- a QS tile's subtitle (design 10.5px) and
                                           //    a slider's label (design 11px)
    readonly property int fsMono: 13       // design says 12.5px; same rounding

    // =========================================================================
    // MOTION
    // =========================================================================
    // --dur-fast / --dur-med / --ease-out from tokens/effects.css. The easing is
    // a CSS cubic-bezier; QML spells the same curve as four numbers fed to
    // Easing.bezierCurve, in the same order.
    readonly property int durFast: 120
    readonly property int durMed: 220
    readonly property var easeOut: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
}
