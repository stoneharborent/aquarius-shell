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
// HOW THE THEME IS CHOSEN — updated in P2
//   `dark` used to be a stored value somebody flipped by hand. It now FOLLOWS
//   THE SYSTEM: if the machine says it prefers dark, the shell is Midnight; if
//   it says light, or says nothing at all, the shell is Ice.
//
//   The question is asked through the freedesktop appearance portal — the same
//   standard GNOME apps, KDE apps and every Flatpak read — and the asking lives
//   in services/SystemAppearance.qml, not here. This file only decides what to
//   do with the answer, which is the decision that belongs to the theme.
//
//   Three cases, and the third is the one that matters:
//     system says dark      -> Midnight
//     system says light     -> Ice
//     nothing answers       -> `storedDark` below, which is Ice
//
//   That last case covers any machine where no portal answers. A missing
//   portal must never be a broken-looking desktop; it just means AquariusOS's
//   own decision stands, and AquariusOS's own decision is light.
//
//   (In the nested harness the shell may well pick up the HOST desktop's
//   setting, since it is the host's portal on the bus. That is fine and even
//   useful — but it is untested, like everything else here.)
//
//   `dark` is still a writable property. Assigning to it (from a future
//   Settings panel, say) breaks the binding in the ordinary QML way and pins
//   the theme by hand. That is deliberate: following the system is the default,
//   not a cage.
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

import "../services"

Singleton {
    id: root

    // =========================================================================
    // WHICH PALETTE IS IN FORCE
    // =========================================================================
    // false = Ice (light) — AquariusOS's main theme.
    // true  = Midnight (dark).

    // What we fall back to when the system has no opinion, or when there is no
    // portal to ask. Ice-first is the AquariusOS identity decision (Royce,
    // 2026-08-31), so this is false and should stay false.
    property bool storedDark: false

    // The live answer. Follows the system; falls back to `storedDark`.
    // Writable on purpose — see the note at the top of this file.
    property bool dark: SystemAppearance.hasPreference
                        ? SystemAppearance.prefersDark
                        : root.storedDark

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

    readonly property color scrim: root.colors.scrim
    readonly property color accentWash: root.colors.accentWash

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
    // THE DOCK — measured off the V2 artboard
    // =========================================================================
    // From "AquariusOS Desktop Shell.html", the `.dock-ico` rule and the dock
    // container's inline style:
    //
    //   container  left:50%; bottom:10px; gap:9px; padding:9px 13px;
    //              border-radius:16px; border:1px solid ...
    //   .dock-ico  width:44px; height:44px; border-radius:11px;
    //              font:600 13px var(--font-display)
    //   .dock-ico:hover  transform: translateY(-4px) scale(1.08)
    //   .dock-ico i      bottom:-7px; width:4px; height:4px; border-radius:50%
    //   separator  width:1px; height:28px
    //   the + tile font-size:18px
    //
    // The dot's "bottom:-7px" is CSS for "the dot's BOTTOM edge sits 7px below
    // the tile's bottom edge". With a 4px dot that leaves a 3px gap between the
    // tile and the dot, which is what dockDotGap is. 3 + 4 = 7, and the dock's
    // 9px bottom padding has room for it with 2px to spare.
    readonly property int dockTileSize: 44        // one app tile, square
    readonly property int dockTileRadius: 11      // that tile's corners
    readonly property int dockTileInset: 6        // icon inset inside the tile*
    readonly property int dockGap: 9              // space BETWEEN tiles
    readonly property int dockPaddingH: 13        // space inside the slab, sides
    readonly property int dockPaddingV: 9         // space inside the slab, top/bottom
    readonly property int dockRadius: 16          // the slab's corners
    readonly property int dockScreenMargin: 10    // slab's gap to the screen edge
    readonly property int dockDotSize: 4          // the running-app dot
    readonly property int dockDotGap: 3           // tile bottom -> dot top

    // How solid that dot is. The design draws one state; these two come from
    // the Plasma theme's tasks.svg, which used 0.55 for "running" and 0.8 for
    // "running and focused". Keeping both means the dock can say which of
    // several open apps you are actually in, at no cost in ink.
    readonly property real dockDotOpacity: 0.55
    readonly property real dockDotOpacityActive: 0.8

    readonly property int dockSeparatorHeight: 28 // the rule before the + tile
    readonly property int dockLift: 4             // how far a hovered tile rises
    readonly property real dockHoverScale: 1.08   // and how much it grows
    readonly property int dockGlyphSize: 13       // the two-letter icon fallback
    readonly property int dockAddGlyphSize: 18    // the "+" on the add tile

    // * The design draws two-letter placeholders rather than real icons, so it
    //   has no inset to measure. 6 is the Plasma theme's 4-in-32 tile inset
    //   scaled to 44 (round(44 * 4 / 32) = 6) — the number the KDE dock's
    //   artwork already used, kept so the two docks line up while both exist.

    // =========================================================================
    // THE FLOW SEARCH PALETTE — measured off the V2 artboard
    // =========================================================================
    // Source: "AquariusOS Shell Search.html", which is an iframe onto
    // "AquariusOS Desktop Shell.html#search". The numbers below are that
    // drawing's numbers, read straight out of its inline styles:
    //
    //   .panel  { left:50%; top:170px; width:560px; padding:8px; radius:12px }
    //   header  { padding:12px 14px; gap:12px; border-bottom:1px }
    //   list    { padding:6px 2px }
    //   .res    { padding:10px 14px; gap:12px; border-radius:10px }
    //   .res .ri{ width:30px; height:30px; border-radius:8px }
    //   .res kbd{ border-radius:5px; padding:2px 6px }
    //   footer  { padding:9px 14px; border-top:1px }
    //
    // Same reasoning as the top bar above: these are artboard numbers rather
    // than ladder numbers, and they live here so no component types them.
    readonly property int searchWidth: 560           // the palette's width
    readonly property int searchTop: 170             // its distance from the top of the screen
    readonly property int searchPanelPadding: 8      // space inside the panel's edge
    readonly property int searchIconSize: 17         // the magnifier at the left of the field

    readonly property int searchFieldPaddingH: 14
    readonly property int searchFieldPaddingV: 12
    readonly property int searchFieldGap: 12

    readonly property int searchListPaddingH: 2
    readonly property int searchListPaddingV: 6

    readonly property int searchRowPaddingH: 14
    readonly property int searchRowPaddingV: 10
    readonly property int searchRowGap: 12
    readonly property int searchRowRadius: 10
    readonly property int searchRowIconSize: 30
    readonly property int searchRowIconRadius: 8

    readonly property int searchHintPaddingH: 6
    readonly property int searchHintPaddingV: 2
    readonly property int searchHintRadius: 5

    readonly property int searchFooterPaddingH: 14
    readonly property int searchFooterPaddingV: 9

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
    readonly property int fsMonoSm: 11     // design says 10.5px; the keyboard hints
                                           // and the Flow Search footnote. There is
                                           // no body step this small on purpose —
                                           // it is only ever used for mono asides.

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
