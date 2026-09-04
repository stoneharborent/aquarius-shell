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
//   effects}.css. Those artboards are drawn at 1280x800. Colour is the one
//   thing NOT taken from V2: V2's palette is the old dark "Flow State"
//   identity, and colour now comes from Ice.
//
//   THE NUMBERS BELOW ARE NO LONGER THE ARTBOARD'S NUMBERS — READ THIS.
//   On 2026-09-03 Royce ran the shell on a 55" 4K Samsung Odyssey Ark, with
//   the session output scale at 1.25 (the value GNOME had been using on that
//   machine), and made the call:
//
//       "1.25 reads right for the whole shell, except the dock,
//        which should be the size it has at 1.5."
//
//   So the design moved to meet him. Every size token below is now
//   **1.25x the original 2026-08 artboard number, and the dock's tokens are
//   1.5x** (approved by Royce on a 55" 4K at output scale 1.25, 2026-09-03).
//   Each section's comment still quotes the artboard's CSS as the paper trail,
//   with the shipped number beside it, so nobody has to guess which is which.
//
//   That means AQ_UI_SCALE is back to what a knob should be: 1.0 is "the
//   design as designed", not "the design Royce already told us was too small".
//   Every number was produced by rounding the artboard number the same way
//   px() would have — so what ships at 1.0 is pixel-for-pixel what he approved.
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
    // WHAT 1.0 MEANS NOW — the question below has been ANSWERED
    //   This knob was built on 2026-09-03 so Royce could try 1.15, 1.25 and 1.5
    //   on the real machine and say which was right. He did, the same day: 1.25
    //   for the shell, 1.5 for the dock. Those numbers are now baked into the
    //   tokens further down, so **1.0 is the answer, not the old too-small
    //   design.** The knob survives because the question comes back — a
    //   different monitor, a different chair, a guest who wants everything
    //   bigger — and because a shell that can only be one size is a shell that
    //   has to be edited and rebuilt to be adjusted.
    //
    //   Read the rest of this block as the history it is. Everything it says
    //   about how the knob WORKS is still exactly true.
    //
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
    //     2. The DESIGN's OWN BASE SIZES. Even at a correct output scale, the
    //        30px bar and 12px caption the artboard drew may simply be smaller
    //        than Royce wants on a big desktop monitor. (They were: that is why
    //        the bar is 38 and the caption 15 today.) That is a design
    //        judgement, and
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
    // tokens/spacing.css drew this ladder as 4/8/12/16/24/32/48/64; the shell
    // ships it at 1.25x (5/10/15/20/30/40/60/80). If a gap in a design is not
    // on this ladder, the design is wrong or the measurement is wrong — check
    // before inventing a number.
    readonly property int sp1: root.px(5)
    readonly property int sp2: root.px(10)
    readonly property int sp3: root.px(15)
    readonly property int sp4: root.px(20)
    readonly property int sp5: root.px(30)
    readonly property int sp6: root.px(40)
    readonly property int sp7: root.px(60)
    readonly property int sp8: root.px(80)

    // =========================================================================
    // CORNERS
    // =========================================================================
    // Artboard 7 / 9 / 12 / 16, shipped at 1.25x.
    readonly property int radiusSm: root.px(9)    // inputs, toggles
    readonly property int radiusMd: root.px(11)   // buttons
    readonly property int radiusLg: root.px(15)   // cards
    readonly property int radiusXl: root.px(20)   // panels, windows

    // =========================================================================
    // CONTROLS
    // =========================================================================
    // Artboard 36 / 28, shipped at 1.25x.
    readonly property int controlHeight: root.px(45)
    readonly property int controlHeightSm: root.px(35)

    // =========================================================================
    // THE TOP BAR — measured off the V2 artboard, then grown 1.25x
    // =========================================================================
    // <header style="height:30px; padding:0 10px; gap:2px;
    //                border-bottom:1px solid ...">
    //   .bar-item { height:22px; padding:0 8px; gap:6px; border-radius:6px }
    //
    // Those are the artboard's numbers. The bar SHIPS at 1.25x of them — 30
    // became 38, 22 became 28, and so on — because a 30px bar disappeared on a
    // 55" monitor (Royce, 2026-09-03). `hairline` is the one exception: a
    // hairline is one pixel by definition, and 1.25 rounds back to 1 anyway.
    readonly property int barHeight: root.px(38)          // the whole bar
    readonly property int barPaddingH: root.px(13)        // space before the first / after the last item
    readonly property int barItemSpacing: root.px(3)      // space BETWEEN bar items
    readonly property int barItemHeight: root.px(28)      // the hover pill's height
    readonly property int barItemPaddingH: root.px(10)     // space inside a bar item, left and right
    readonly property int barItemGap: root.px(8)          // space between two things inside one item
    readonly property int barItemRadius: root.px(8)       // the hover pill's corners
    readonly property int barLogoSize: root.px(18)        // the Aquarius mark, drawn 14x14
    readonly property int hairline: root.px(1)            // every 1px rule in the shell
    readonly property int barGlyphSize: root.px(19)       // a status glyph (Wi-Fi, speaker) in the bar
    readonly property int barTrayIconSize: root.px(20)    // a system tray application's own icon

    // =========================================================================
    // QUICK SETTINGS — measured off the V2 artboard, then grown 1.25x
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
    // The panel's corner uses radiusLg, which is what the design's
    // var(--radius-lg) resolves to — NOT radiusXl, even though the comment on
    // radiusXl says "panels". The design is the authority here.
    //
    // Every number below is 1.25x the CSS above, for the reason given at the
    // top of the file. One of them is 1.25x-and-a-pixel: a tile is padding +
    // chip + padding, and 13 + 40 + 13 is 66 where 52 x 1.25 rounds to 65. The
    // arithmetic wins — a tile that is one pixel shorter than the thing inside
    // it is a clipped chip, which is visible, and one pixel of extra height is
    // not.
    readonly property int qsWidth: root.px(413)
    readonly property int qsPadding: root.px(20)
    readonly property int qsTileGap: root.px(13)          // between tiles, both directions
    readonly property int qsTileHeight: root.px(66)       // 13 + 40 chip + 13
    readonly property int qsTilePaddingH: root.px(15)
    readonly property int qsTilePaddingV: root.px(13)
    readonly property int qsTileInnerGap: root.px(13)     // chip -> text
    readonly property int qsChipSize: root.px(40)
    readonly property int qsChipGlyphSize: root.px(19)
    readonly property int qsSlidersTop: root.px(20)       // grid -> first slider
    readonly property int qsSliderGap: root.px(18)        // slider -> slider
    readonly property int qsSliderLabelGap: root.px(10)   // label row -> track
    readonly property int qsTrackHeight: root.px(8)
    readonly property int qsHandleSize: root.px(20)
    readonly property int qsFooterTop: root.px(18)        // last slider -> the hairline
    readonly property int qsFooterPaddingTop: root.px(15) // the hairline -> the battery line
    readonly property int qsFooterGap: root.px(10)
    readonly property int qsBatteryGlyphWidth: root.px(28)
    readonly property int qsBatteryGlyphHeight: root.px(14)

    // Where the panel sits once it is open: the design draws it 38px from the
    // top of a 30px bar, i.e. 8px of air under the bar — 10px here, at 1.25x.
    // The air is a token and the 38 is not, which is exactly why the bar could
    // grow to 38 of its own without anybody having to notice this line.
    //
    // The design's other number — 12px in from the right edge of the screen —
    // is NOT a token, because it is not set anywhere. The panel hangs off the
    // right-hand end of the bar's own contents, so barPaddingH plus the status
    // item's padding already puts it there. Writing 12 as well would inset it
    // twice.
    readonly property int qsPopupGap: root.px(10)

    // =========================================================================
    // THE DOCK — measured off the V2 artboard, then grown 1.5x
    // =========================================================================
    // THE DOCK IS DELIBERATELY BIGGER THAN THE REST OF THE SHELL. Everywhere
    // else in this file the artboard number is multiplied by 1.25; here it is
    // multiplied by 1.5. That is not a typo and it is not drift — it is Royce's
    // call on the bench, 2026-09-03, on a 55" 4K at output scale 1.25:
    //
    //     "1.25 reads right for the whole shell, except the dock,
    //      which should be the size it has at 1.5."
    //
    // There is a reason it lands differently, and it is worth knowing before
    // anybody "fixes" it. The bar and the panels are read — they hold text, and
    // text has its own legible size. The dock is AIMED AT: it is a row of click
    // targets you hit with a pointer from across a very large desk, and a
    // pointer target wants to be bigger than the type beside it. Docks on every
    // other desktop are outsized relative to their panels for the same reason.
    //
    // The whole block moves together — tile, gap, padding, slab corner, screen
    // margin, dot, lift, glyphs. Growing only the tile would give a 66px icon
    // in a slab still built for a 44px one, and the dock would look padded
    // wrong rather than bigger. tests/test-shell.sh section 31 guards the
    // dock-to-bar ratio so a later "let us shrink the bar a little" cannot
    // quietly shrink this too.
    //
    // From "AquariusOS Desktop Shell.html", the `.dock-ico` rule and the dock
    // container's inline style — the ARTBOARD's numbers, i.e. what each token
    // below is 1.5x of:
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
    // the tile's bottom edge". On the artboard, a 4px dot left a 3px gap
    // between tile and dot — that gap is dockDotGap — and 3 + 4 = 7 fitted
    // inside the slab's 9px bottom padding with 2px to spare. At 1.5x the same
    // sum is 5 + 6 = 11 inside 14, so it still fits, with 3px to spare.
    readonly property int dockTileSize: root.px(66)        // one app tile, square
    readonly property int dockTileRadius: root.px(17)      // that tile's corners
    readonly property int dockTileInset: root.px(9)        // icon inset inside the tile*
    readonly property int dockGap: root.px(14)             // space BETWEEN tiles
    readonly property int dockPaddingH: root.px(20)        // space inside the slab, sides
    readonly property int dockPaddingV: root.px(14)        // space inside the slab, top/bottom
    readonly property int dockRadius: root.px(24)          // the slab's corners
    readonly property int dockScreenMargin: root.px(15)    // slab's gap to the screen edge
    readonly property int dockDotSize: root.px(6)          // the running-app dot
    readonly property int dockDotGap: root.px(5)           // tile bottom -> dot top

    // THE DOT HAS NO OPACITY TOKENS ANY MORE — 2026-09-04.
    //   It used to be drawn in Theme.accent at 0.55 when running and 0.8 when
    //   focused, the two numbers the Plasma theme's tasks.svg used. Those were
    //   fine while every tile sat on its own recessed slab: the slab said
    //   "app", so the dot only had to whisper "and it is open".
    //
    //   The slabs are gone (Royce, on the bench, 2026-09-04 — see DockItem.qml),
    //   so the dot is now the ONLY mark that says an app is running, and a
    //   whisper is no longer enough. Measured against Ice's panel, the old dot
    //   came out at 1.9:1 when running and 2.6:1 when focused — both under the
    //   3:1 that WCAG asks of a non-text indicator, and both genuinely hard to
    //   see across a room from a 55" screen.
    //
    //   So both states are now drawn SOLID, and the state is carried by the
    //   COLOUR instead: Theme.accent when the app is the one you are in,
    //   Theme.inkMute when it is merely open. Measured against each theme's
    //   panel that is 3.3:1 and 3.0:1 on Ice, 7.7:1 and 3.1:1 on Midnight —
    //   every state over the bar, on both themes, and the two are told apart by
    //   hue rather than by a difference in fadedness that a light theme cannot
    //   carry. Nothing to put here: both colours are roles that already exist.

    readonly property int dockSeparatorHeight: root.px(42) // the rule before the + tile
    readonly property int dockLift: root.px(6)             // how far a hovered tile rises
    readonly property real dockHoverScale: 1.08   // and how much it grows
    readonly property int dockGlyphSize: root.px(20)       // the two-letter icon fallback
    readonly property int dockAddGlyphSize: root.px(27)    // the "+" on the add tile

    // * The design draws two-letter placeholders rather than real icons, so it
    //   has no inset to measure. The artboard's inset was 6: the Plasma theme's
    //   4-in-32 tile inset scaled to a 44px tile (round(44 * 4 / 32) = 6), the
    //   number the KDE dock's artwork already used, kept so the two docks line
    //   up while both exist. 9 is that same 6 at 1.5x, and 9/66 is exactly
    //   6/44 — the icon sits in the tile the way it always did.

    // =========================================================================
    // THE FLOW SEARCH PALETTE — measured off the V2 artboard, then grown 1.25x
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
    // than ladder numbers, and they live here so no component types them. And
    // like the top bar, each token is 1.25x the CSS quoted above — the palette
    // is 700 wide, not 560.
    readonly property int searchWidth: root.px(700)           // the palette's width
    readonly property int searchTop: root.px(213)             // its distance from the top of the screen
    readonly property int searchPanelPadding: root.px(10)      // space inside the panel's edge
    readonly property int searchIconSize: root.px(21)         // the magnifier at the left of the field

    readonly property int searchFieldPaddingH: root.px(18)
    readonly property int searchFieldPaddingV: root.px(15)
    readonly property int searchFieldGap: root.px(15)

    readonly property int searchListPaddingH: root.px(3)
    readonly property int searchListPaddingV: root.px(8)

    readonly property int searchRowPaddingH: root.px(18)
    readonly property int searchRowPaddingV: root.px(13)
    readonly property int searchRowGap: root.px(15)
    readonly property int searchRowRadius: root.px(13)
    readonly property int searchRowIconSize: root.px(38)
    readonly property int searchRowIconRadius: root.px(10)

    readonly property int searchHintPaddingH: root.px(8)
    readonly property int searchHintPaddingV: root.px(3)
    readonly property int searchHintRadius: root.px(6)

    readonly property int searchFooterPaddingH: root.px(18)
    readonly property int searchFooterPaddingV: root.px(11)

    // =========================================================================
    // NOTIFICATIONS — measured off the V2 artboard, then grown 1.25x
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
    // (Those ladder steps are themselves 1.25x now, so the panel's padding
    // draws at 20 and its corner at 15. Naming the step rather than the number
    // is what let the whole panel grow without one edit in this section.)
    //
    // The design's `top:38px` is the 30px bar plus 8px of air, so the popup is
    // positioned with a `sp2` top margin against a window that already starts
    // below the bar. There is no "38" anywhere in the code, and there should
    // not be: the bar's height DID change — 30 to 38 — and this gap correctly
    // did not have to.
    readonly property int notifPanelWidth: root.px(438)      // the panel AND the toasts
    readonly property int notifChipSize: root.px(43)         // the rounded icon chip
    readonly property int notifIconSize: root.px(19)         // the glyph inside the chip
    readonly property int notifGroupIconSize: root.px(20)    // the app icon on a group header

    // How tall the scrolling list of notifications may get before it scrolls
    // instead of growing. Not a design number — the artboard draws three rows
    // and stops. 420 was twenty rows' worth of a short list, which kept the
    // panel comfortably inside a 768px-tall laptop screen with the footer;
    // 525 is that at 1.25x, and the rows it holds grew by the same 1.25x, so
    // it is still twenty rows and still fits the same screen.
    readonly property int notifMaxListHeight: root.px(525)

    // =========================================================================
    // THE LOGIN SCREEN
    // =========================================================================
    // The greeter — greeter/greeter.qml — is the first thing anybody sees, and
    // the only part of this shell that runs before anyone has logged in. It has
    // no artboard of its own; it is built out of the same pieces as everything
    // else, at the same sizes, so that the screen you log in at and the desktop
    // you land on are visibly one design.
    //
    // The numbers below are chosen against the shell's existing ladder rather
    // than invented: the card is a little wider than the Flow Search palette
    // minus its margins, its padding is sp5, its corners are radiusXl, and the
    // password box is the shell's standard control height. When a real artboard
    // exists, these get re-pointed at it.
    //
    // ⚠️ They are all px() like everything else, so AQ_UI_SCALE resizes the
    // login screen too. That matters more here than anywhere: the login screen
    // is the one place a person cannot open Settings to fix the size.
    readonly property int greeterCardWidth: root.px(520)     // the card the password is in
    readonly property int greeterCardPadding: root.px(30)    // sp5, inside its edge
    readonly property int greeterSectionGap: root.px(20)     // sp4, between the card's rows
    readonly property int greeterClockGap: root.px(50)       // the clock -> the card
    readonly property int greeterAvatarSize: root.px(96)     // the big picture above your name
    readonly property int greeterAvatarGlyphSize: root.px(38) // the initials when there is no picture
    readonly property int greeterLogoSize: root.px(26)       // the Aquarius mark on the card
    readonly property int greeterLogoGap: root.px(10)        // mark -> the word AquariusOS
    readonly property int greeterFieldPaddingH: root.px(18)  // inside the password box
    readonly property int greeterListRowHeight: root.px(58)  // one person in the list
    readonly property int greeterListRowRadius: root.px(14)
    readonly property int greeterListAvatarSize: root.px(38) // their picture in that row
    readonly property int greeterListGap: root.px(15)        // picture -> name
    readonly property int greeterPillPaddingH: root.px(14)   // the session pill at the foot
    readonly property int greeterPillPaddingV: root.px(8)
    readonly property int greeterPillRadius: root.px(10)
    readonly property int greeterHintGap: root.px(18)        // the card -> the keyboard hints

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

    // The scale, from tokens/typography.css, at 1.25x like everything else that
    // is not the dock. Sizes are in points-as-pixels the same way the design
    // draws them; Qt's `font.pixelSize` is the matching property, NOT
    // `font.pointSize` (which would rescale with system DPI and stop matching
    // the artboard).
    //
    // The "design says" notes below are the ORIGINAL token-sheet sizes, kept as
    // the paper trail. The shipped number is on the left. So the top bar's
    // caption is a 12px design step drawn at 15px, and that is on purpose.
    //
    // Type is where growing the design is most obviously right and most easily
    // second-guessed: a 12px caption is a perfectly good caption on a laptop
    // and unreadable across a 55" desk. If someone ever wants the old sizes
    // back, that is AQ_UI_SCALE=0.8, not an edit here.
    //                                   design step ->  shipped
    readonly property int fsHero: root.px(80)       // 64
    readonly property int fsDisplay: root.px(60)    // 48
    readonly property int fsTitle: root.px(43)      // 34
    readonly property int fsHeading: root.px(30)    // 24
    readonly property int fsSubhead: root.px(23)    // 18
    readonly property int fsBody: root.px(19)       // 15
    readonly property int fsSmall: root.px(18)      // 14 (design 13.5px; Qt wants a whole number)
    readonly property int fsCaption: root.px(15)    // 12 <- the top bar's size, and a QS tile's title
    readonly property int fsMicro: root.px(14)      // 11 <- a QS tile's subtitle (design 10.5px) and
                                           //       a slider's label (design 11px)
    readonly property int fsMono: root.px(16)       // 13 (design 12.5px; same rounding)
    readonly property int fsMonoSm: root.px(14)     // 11 (design 10.5px) — the keyboard hints
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
    // they unified on 11 at the merge, and 11 is what the 14 above is 1.25x of.
    // If the design system ever publishes its own micro steps, re-point these
    // rather than keeping a second opinion.

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
