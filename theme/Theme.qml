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
    readonly property color accentWash: root.colors.accentWash

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
    // NOTIFICATIONS — measured off the V2 artboard
    // =========================================================================
    // From "AquariusOS Desktop Shell.html", the block with id="ovNotif" (the
    // same panel published on its own as "AquariusOS Shell Notifications.html"):
    //
    //   .panel  { right:12px; top:38px; width:350px; padding:16px;
    //             border-radius: var(--radius-lg) }
    //   .notif  { gap:12px; padding:12px; border-radius:12px }
    //   .notif .ni { width:34px; height:34px; border-radius:9px }   <- icon chip
    //   the svg inside .ni is drawn 15x15
    //
    // Only the numbers that are NOT already on a ladder above are named here.
    // The panel's 16px padding is `sp4`, the 12px row padding and 12px right
    // offset are `sp3`, the 8px gap between rows is `sp2`, and both 12px
    // corner radii are `radiusLg` — those are used directly, not restated.
    //
    // The design's `top:38px` is the 30px bar plus 8px of air, so the popup is
    // positioned with a `sp2` top margin against a window that already starts
    // below the bar. There is no "38" anywhere in the code, and there should
    // not be: if the bar's height ever changes, the gap should stay 8.
    readonly property int notifPanelWidth: 350      // the panel AND the toasts
    readonly property int notifChipSize: 34         // the rounded icon chip
    readonly property int notifIconSize: 15         // the glyph inside the chip
    readonly property int notifGroupIconSize: 16    // the app icon on a group header

    // How tall the scrolling list of notifications may get before it scrolls
    // instead of growing. Not a design number — the artboard draws three rows
    // and stops. 420 is twenty rows' worth of a short list, which keeps the
    // panel comfortably inside a 768px-tall laptop screen with the footer.
    readonly property int notifMaxListHeight: 420

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

    // --- two steps below the published scale ---------------------------------
    // tokens/typography.css stops at caption (12px). The shell's popups go
    // smaller than any page the token sheet was drawn for: the V2 notifications
    // artboard sets its body text at 11.5px and its timestamps at 10px mono,
    // inline, because there was no token for either.
    //
    // Rather than let two components each invent their own 11, the two steps
    // are named here — which is the same bargain every other number in this
    // file makes. If the design system ever publishes its own micro steps,
    // these should be re-pointed at those and not kept as a second opinion.
    readonly property int fsMicro: 11      // design says 11.5px; notification body text
    readonly property int fsMonoSm: 10     // notification timestamps, in the mono face

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
