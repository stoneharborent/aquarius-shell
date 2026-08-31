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
    readonly property int fsCaption: 12    // <- the top bar's size
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
