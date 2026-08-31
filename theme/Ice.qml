// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// Ice — the light palette. This is AquariusOS's MAIN colour theme.
// =============================================================================
// WHERE THESE NUMBERS COME FROM
//   Aquarius Writer (the Mac app) ships two companion themes built from one
//   25-colour brand palette: "Ice" (light) and "Midnight" (dark). Royce named
//   Ice as the source for the OS's colour theme on 2026-08-31. The values below
//   were copied out of that palette, one for one — see
//   docs/adr/0001-framework.md for the paper trail, and the Ice token sheet in
//   the custom-DE research folder for the full story.
//
// WHY IT MATTERS THAT ICE IS *LIGHT*
//   Nearly every Linux desktop leads with a dark theme. AquariusOS leads with a
//   light one, and keeps Midnight (see Midnight.qml) as its dark mode. That is
//   a deliberate brand statement, not an oversight.
//
// HOW COLOURS WITH TRANSPARENCY ARE WRITTEN
//   QML understands "#AARRGGBB" — the FIRST two characters are the opacity.
//   So "#1A16273A" means "the ink colour #16273A, at 10% opacity"
//   (0x1A is 26, and 26/255 is about 10%). Every translucent value below has a
//   comment saying which colour it is and at what percentage, so nobody has to
//   do that arithmetic in their head again.
//
// DO NOT ADD COLOURS HERE that are not in the Aquarius palette. If a component
// needs a colour that does not exist yet, that is a design decision — it goes
// through the design system first, then lands here.
// =============================================================================
pragma Singleton

import Quickshell

Singleton {
    // --- What this palette is called, for anything that wants to say so -------
    readonly property string name: "Ice"
    readonly property bool isDark: false

    // --- Surfaces: the things colour sits ON ----------------------------------
    readonly property color bg: "#EAF1F8"          // the ground; window backgrounds
    readonly property color bgSoft: "#DFEAF4"      // slightly recessed areas
    readonly property color surface: "#F7FBFE"     // cards and popups — brightest paper
    readonly property color surfaceAlt: "#E4EDF6"  // secondary cards
    readonly property color panel: "#F0F6FC"       // panels and chrome — THE TOP BAR

    // --- Ink: the text ---------------------------------------------------------
    readonly property color ink: "#16273A"         // primary text — deep navy, not black
    readonly property color inkProse: "#0E1B2A"    // long-form reading text (deepest)
    readonly property color inkSoft: "#47586B"     // secondary text
    readonly property color inkMute: "#7C90A4"     // tertiary and disabled text

    // --- Hairlines: the 1px rules between things -------------------------------
    readonly property color line: "#1A16273A"        // ink at 10%
    readonly property color lineStrong: "#2E16273A"  // ink at 18%

    // --- Hover / pressed washes ------------------------------------------------
    // The design paints a tint ON TOP of the bar rather than making the bar
    // see-through. These are that tint.
    readonly property color hoverWash: "#1416273A"   // ink at 8%
    readonly property color pressWash: "#2116273A"   // ink at 13%

    // --- Semantic colours, tuned for a light ground ----------------------------
    readonly property color success: "#1F9E8C"
    readonly property color warn: "#C2792E"
    readonly property color danger: "#C8463B"
    readonly property color starred: "#C28B22"

    // --- The four accents ------------------------------------------------------
    // Aquarius Blue is the default. The other three exist so a person can pick
    // one in Settings later; nothing in P1 switches between them yet.
    readonly property color accent: aquariusBlue
    readonly property color aquariusBlue: "#2C8FC4"
    readonly property color indigo: "#6E2BE0"
    readonly property color turquoise: "#0E9AA0"
    readonly property color aquamarine: "#12A07C"

    // Text drawn ON TOP of a filled accent shape (a pressed toggle, a badge).
    readonly property color onAccent: "#FFFFFF"
}
