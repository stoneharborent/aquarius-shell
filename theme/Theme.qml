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

// QtQuick is imported for its VALUE TYPES, not for anything visible. `color` is
// not a built-in QML type — it arrives with QtQuick — so a file that declares
// `property color` without this line fails to load with the unhelpful message
// "color is not a type". Nothing is drawn from here; this is a palette.
import QtQuick

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

    readonly property color success: root.colors.success
    readonly property color warn: root.colors.warn
    readonly property color danger: root.colors.danger
    readonly property color starred: root.colors.starred

    readonly property color accent: root.colors.accent
    readonly property color inkOnAccent: root.colors.inkOnAccent
    readonly property color accentWash: root.colors.accentWash

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
    // THE SIZE KNOB — one number that makes the whole shell bigger or smaller
    // =========================================================================
    // WHY THIS EXISTS
    //   On the bench, 2026-09-03, the shell drew correctly and read TOO SMALL.
    //   Two separate things can cause that and they are worth keeping apart:
    //
    //     1. The OUTPUT SCALE. The compositor was running the monitor at 1.0
    //        when the same monitor under GNOME had been scaled up. That is not
    //        a design problem — everything on screen is small, not just us —
    //        and it is fixed in the session, not here (see the AquariusOS
    //        os-image repo, `aquarius-display-scale`).
    //
    //     2. The DESIGN's OWN BASE SIZES. Even at a correct output scale, a
    //        30px bar and a 12px caption may simply be smaller than Royce
    //        wants on a big desktop monitor. That is a design judgement, and
    //        it is HIS to make — which means he has to be able to try 1.15,
    //        1.25 and 1.5 on the real machine in seconds, without an edit, a
    //        rebuild, or a person on a Mac guessing for him.
    //
    //   This knob is for case 2. Set AQ_UI_SCALE in the environment before the
    //   shell starts and every size, gap, corner and font size in the design
    //   is multiplied by it:
    //
    //       AQ_UI_SCALE=1.25 qs -p .
    //
    //   The Aquarius Session exports it from ~/.config/aquarius/display.conf
    //   (`ui=1.25`), so on AquariusOS the way to change it is `aq display ui
    //   1.25` and log back in. Unset or unreadable means 1.0, which is exactly
    //   the design as drawn — this knob changes nothing by default.
    //
    // THE RULE THAT KEEPS IT HONEST
    //   Every numeric size token below is written `root.px(N)`, where N is the
    //   artboard's number. Not one of them is a bare number. That is what makes
    //   the multiplier total rather than partial — a single token left bare
    //   would refuse to grow with the rest and the design would come apart at
    //   1.5. tests/test-shell.sh section 30 fails the build if one appears.
    //
    //   Colours, durations, opacities and the two motion multipliers are NOT
    //   sizes and are deliberately left alone. Making an animation 1.25x longer
    //   because the bar got taller would be a bug, not a feature.
    //
    // WHAT IT DOES NOT DO
    //   It does not touch other applications. Firefox, Resolve and every GTK or
    //   Qt app get their size from the compositor's output scale, which is case
    //   1 above. This number moves the Aquarius shell only.

    // The multiplier. 1.0 = the design exactly as drawn.
    //
    // Clamped to 0.5–3.0 on purpose: a typo of `AQ_UI_SCALE=125` should give a
    // shell that is comically large but still usable and still fixable, not one
    // whose top bar is taller than the monitor and cannot be clicked away.
    readonly property real uiScaleMin: 0.5
    readonly property real uiScaleMax: 3.0

    readonly property real ui: {
        const raw = Quickshell.env("AQ_UI_SCALE");
        if (!raw)
            return 1.0;
        const asked = parseFloat(raw);
        // parseFloat("banana") is NaN, and NaN fails every comparison — so this
        // one test covers both "not a number" and "a negative number".
        if (!(asked > 0))
            return 1.0;
        return Math.min(root.uiScaleMax, Math.max(root.uiScaleMin, asked));
    }

    // Turn an artboard number into the number to actually draw.
    //
    // Rounded, because a 30.75px bar is a blurry bar: Qt will happily lay out
    // on a fraction and the result is a half-lit row of pixels along the
    // bottom edge. Whole numbers here, and the compositor's own fractional
    // output scale (a different thing, applied after this) does the smooth
    // part properly.
    //
    // The floor of 1 protects the hairlines. `hairline` is 1, and at 0.5x
    // Math.round(0.5) is 0 — a border that exists in the design and does not
    // exist on screen. Anything the design says is visible stays visible.
    function px(n: int): int {
        if (root.ui === 1.0)
            return n;
        const scaled = Math.round(n * root.ui);
        return (n > 0 && scaled < 1) ? 1 : scaled;
    }

    // =========================================================================
    // SPACING — the step ladder every gap in the shell is built from
    // =========================================================================
    // Straight out of tokens/spacing.css. If a gap in a design is not on this
    // ladder, the design is wrong or the measurement is wrong — check before
    // inventing a number.
    readonly property int sp1: root.px(4)
    readonly property int sp2: root.px(8)
    readonly property int sp3: root.px(12)
    readonly property int sp4: root.px(16)
    readonly property int sp5: root.px(24)
    readonly property int sp6: root.px(32)
    readonly property int sp7: root.px(48)
    readonly property int sp8: root.px(64)

    // =========================================================================
    // CORNERS
    // =========================================================================
    readonly property int radiusSm: root.px(7)    // inputs, toggles
    readonly property int radiusMd: root.px(9)    // buttons
    readonly property int radiusLg: root.px(12)   // cards
    readonly property int radiusXl: root.px(16)   // panels, windows

    // =========================================================================
    // CONTROLS
    // =========================================================================
    readonly property int controlHeight: root.px(36)
    readonly property int controlHeightSm: root.px(28)

    // =========================================================================
    // THE TOP BAR — measured off the V2 artboard
    // =========================================================================
    // <header style="height:30px; padding:0 10px; gap:2px;
    //                border-bottom:1px solid ...">
    //   .bar-item { height:22px; padding:0 8px; gap:6px; border-radius:6px }
    readonly property int barHeight: root.px(30)          // the whole bar
    readonly property int barPaddingH: root.px(10)        // space before the first / after the last item
    readonly property int barItemSpacing: root.px(2)      // space BETWEEN bar items
    readonly property int barItemHeight: root.px(22)      // the hover pill's height
    readonly property int barItemPaddingH: root.px(8)     // space inside a bar item, left and right
    readonly property int barItemGap: root.px(6)          // space between two things inside one item
    readonly property int barItemRadius: root.px(6)       // the hover pill's corners
    readonly property int barLogoSize: root.px(14)        // the Aquarius mark, drawn 14x14
    readonly property int hairline: root.px(1)            // every 1px rule in the shell
    readonly property int barGlyphSize: root.px(15)       // a status glyph (Wi-Fi, speaker) in the bar
    readonly property int barTrayIconSize: root.px(16)    // a system tray application's own icon

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
    readonly property int qsWidth: root.px(330)
    readonly property int qsPadding: root.px(16)
    readonly property int qsTileGap: root.px(10)          // between tiles, both directions
    readonly property int qsTileHeight: root.px(52)       // 10 + 32 chip + 10
    readonly property int qsTilePaddingH: root.px(12)
    readonly property int qsTilePaddingV: root.px(10)
    readonly property int qsTileInnerGap: root.px(10)     // chip -> text
    readonly property int qsChipSize: root.px(32)
    readonly property int qsChipGlyphSize: root.px(15)
    readonly property int qsSlidersTop: root.px(16)       // grid -> first slider
    readonly property int qsSliderGap: root.px(14)        // slider -> slider
    readonly property int qsSliderLabelGap: root.px(8)    // label row -> track
    readonly property int qsTrackHeight: root.px(6)
    readonly property int qsHandleSize: root.px(16)
    readonly property int qsFooterTop: root.px(14)        // last slider -> the hairline
    readonly property int qsFooterPaddingTop: root.px(12) // the hairline -> the battery line
    readonly property int qsFooterGap: root.px(8)
    readonly property int qsBatteryGlyphWidth: root.px(22)
    readonly property int qsBatteryGlyphHeight: root.px(11)

    // Where the panel sits once it is open: the design draws it 38px from the
    // top of a 30px bar, i.e. 8px of air under the bar.
    //
    // The design's other number — 12px in from the right edge of the screen —
    // is NOT a token, because it is not set anywhere. The panel hangs off the
    // right-hand end of the bar's own contents, so barPaddingH (10) plus the
    // status item's padding already puts it there. Writing 12 as well would
    // inset it twice.
    readonly property int qsPopupGap: root.px(8)

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
    readonly property int dockTileSize: root.px(44)        // one app tile, square
    readonly property int dockTileRadius: root.px(11)      // that tile's corners
    readonly property int dockTileInset: root.px(6)        // icon inset inside the tile*
    readonly property int dockGap: root.px(9)              // space BETWEEN tiles
    readonly property int dockPaddingH: root.px(13)        // space inside the slab, sides
    readonly property int dockPaddingV: root.px(9)         // space inside the slab, top/bottom
    readonly property int dockRadius: root.px(16)          // the slab's corners
    readonly property int dockScreenMargin: root.px(10)    // slab's gap to the screen edge
    readonly property int dockDotSize: root.px(4)          // the running-app dot
    readonly property int dockDotGap: root.px(3)           // tile bottom -> dot top

    // How solid that dot is. The design draws one state; these two come from
    // the Plasma theme's tasks.svg, which used 0.55 for "running" and 0.8 for
    // "running and focused". Keeping both means the dock can say which of
    // several open apps you are actually in, at no cost in ink.
    readonly property real dockDotOpacity: 0.55
    readonly property real dockDotOpacityActive: 0.8

    readonly property int dockSeparatorHeight: root.px(28) // the rule before the + tile
    readonly property int dockLift: root.px(4)             // how far a hovered tile rises
    readonly property real dockHoverScale: 1.08   // and how much it grows
    readonly property int dockGlyphSize: root.px(13)       // the two-letter icon fallback
    readonly property int dockAddGlyphSize: root.px(18)    // the "+" on the add tile

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
    readonly property int searchWidth: root.px(560)           // the palette's width
    readonly property int searchTop: root.px(170)             // its distance from the top of the screen
    readonly property int searchPanelPadding: root.px(8)      // space inside the panel's edge
    readonly property int searchIconSize: root.px(17)         // the magnifier at the left of the field

    readonly property int searchFieldPaddingH: root.px(14)
    readonly property int searchFieldPaddingV: root.px(12)
    readonly property int searchFieldGap: root.px(12)

    readonly property int searchListPaddingH: root.px(2)
    readonly property int searchListPaddingV: root.px(6)

    readonly property int searchRowPaddingH: root.px(14)
    readonly property int searchRowPaddingV: root.px(10)
    readonly property int searchRowGap: root.px(12)
    readonly property int searchRowRadius: root.px(10)
    readonly property int searchRowIconSize: root.px(30)
    readonly property int searchRowIconRadius: root.px(8)

    readonly property int searchHintPaddingH: root.px(6)
    readonly property int searchHintPaddingV: root.px(2)
    readonly property int searchHintRadius: root.px(5)

    readonly property int searchFooterPaddingH: root.px(14)
    readonly property int searchFooterPaddingV: root.px(9)

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
    readonly property int notifPanelWidth: root.px(350)      // the panel AND the toasts
    readonly property int notifChipSize: root.px(34)         // the rounded icon chip
    readonly property int notifIconSize: root.px(15)         // the glyph inside the chip
    readonly property int notifGroupIconSize: root.px(16)    // the app icon on a group header

    // How tall the scrolling list of notifications may get before it scrolls
    // instead of growing. Not a design number — the artboard draws three rows
    // and stops. 420 is twenty rows' worth of a short list, which keeps the
    // panel comfortably inside a 768px-tall laptop screen with the footer.
    readonly property int notifMaxListHeight: root.px(420)

    // =========================================================================
    // TYPE
    // =========================================================================
    // The OS installs Sora, Inter and JetBrains Mono as system fonts. In the
    // nested test harness on somebody else's machine they may be missing, so
    // each family has a generic partner below — the shell then falls back to
    // whatever that machine has rather than rendering boxes. See harness/README.md.
    //
    // The choosing happens ONCE, here, when the shell starts: `Qt.fontFamilies()`
    // is the list of families this machine actually has, and `pickFont` returns
    // the wanted one if it is in that list and the generic one if it is not. So
    // `Theme.fontBody` is always a family that exists, and every component can
    // keep writing the ordinary `font.family: Theme.fontBody`.
    //
    // Why not `font.families: [wanted, generic]`, which is the obvious Qt way to
    // say the same thing? Because the Quickshell build AquariusOS runs
    // (quickshell 0.2.1 on Qt 6.11) does not expose `families` on the font group
    // at all — assigning it stops the whole shell from loading with "Cannot
    // assign to non-existent property families". Found on the first real run,
    // 2026-09-01. `font.family` works everywhere; this file absorbs the rest.
    readonly property string fontDisplayFallback: "sans-serif"
    readonly property string fontBodyFallback: "sans-serif"
    readonly property string fontMonoFallback: "monospace"

    readonly property var installedFonts: Qt.fontFamilies()

    function pickFont(wanted: string, generic: string): string {
        return root.installedFonts.indexOf(wanted) !== -1 ? wanted : generic
    }

    readonly property string fontDisplay: root.pickFont("Sora", root.fontDisplayFallback)
    readonly property string fontBody: root.pickFont("Inter", root.fontBodyFallback)
    readonly property string fontMono: root.pickFont("JetBrains Mono", root.fontMonoFallback)

    // The scale, from tokens/typography.css. Sizes are in points-as-pixels the
    // same way the design draws them; Qt's `font.pixelSize` is the matching
    // property, NOT `font.pointSize` (which would rescale with system DPI and
    // stop matching the artboard).
    readonly property int fsHero: root.px(64)
    readonly property int fsDisplay: root.px(48)
    readonly property int fsTitle: root.px(34)
    readonly property int fsHeading: root.px(24)
    readonly property int fsSubhead: root.px(18)
    readonly property int fsBody: root.px(15)
    readonly property int fsSmall: root.px(14)      // design says 13.5px; Qt wants a whole number
    readonly property int fsCaption: root.px(12)    // <- the top bar's size, and a QS tile's title
    readonly property int fsMicro: root.px(11)      // <- a QS tile's subtitle (design 10.5px) and
                                           //    a slider's label (design 11px)
    readonly property int fsMono: root.px(13)       // design says 12.5px; same rounding
    readonly property int fsMonoSm: root.px(11)     // design says 10.5px; the keyboard hints
                                           // and the Flow Search footnote. There is
                                           // no body step this small on purpose —
                                           // it is only ever used for mono asides.

    // --- two steps below the published scale ---------------------------------
    // tokens/typography.css stops at caption (12px). The shell's popups go
    // smaller than any page the token sheet was drawn for: QS tile subtitles
    // (10.5px), slider labels (11px), notification body text (11.5px), the
    // Flow Search footnote and keyboard hints (10.5px mono), and notification
    // timestamps (10px mono). Rather than let components each invent their own
    // 11, the two steps are named ONCE above — fsMicro and fsMonoSm. Three P2
    // tracks arrived at them independently with three different roundings;
    // they unified on 11 at the merge. If the design system ever publishes its
    // own micro steps, re-point these rather than keeping a second opinion.

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
