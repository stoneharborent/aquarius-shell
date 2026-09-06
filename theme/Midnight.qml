// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// Midnight — the dark palette. Ice's designed twin, NOT a second design.
// =============================================================================
// Every role in this file has the same name as the matching role in Ice.qml,
// and they are the only two files allowed to contain raw colour values. That
// pairing is what lets a component be written once and look right in both
// themes: a component asks for `Theme.ink`, and the theme in force decides
// whether that means deep navy or ice blue.
//
// If you add a role here, add it to Ice.qml in the same sitting. A role that
// exists in one palette and not the other WILL crash the shell the moment
// somebody flips the theme, and the crash will happen on Royce's machine and
// not on yours.
//
// The "#AARRGGBB" opacity note at the top of Ice.qml applies here too. Note
// that Midnight's hairlines are tinted ICE BLUE, not white — that is on
// purpose, and it is what makes the dark theme read as the same family.
// =============================================================================
pragma Singleton

import Quickshell

// QtQuick is imported for its VALUE TYPES, not for anything visible. `color` is
// not a built-in QML type — it arrives with QtQuick — so a file that declares
// `property color` without this line fails to load with the unhelpful message
// "color is not a type". Nothing is drawn from here; this is a palette.
import QtQuick

Singleton {
    readonly property string name: "Midnight"
    readonly property bool isDark: true

    // --- Surfaces ---------------------------------------------------------------
    readonly property color bg: "#0B1220"          // deep-ocean navy
    readonly property color bgSoft: "#111A2B"
    readonly property color surface: "#121C2E"
    readonly property color surfaceAlt: "#1B2940"
    readonly property color panel: "#152033"       // THE TOP BAR

    // The dock's slab — Ice's twin. See the long note beside `dockSurface` in
    // Ice.qml for why the dock is drawn a step off the bar's `panel` tone. On
    // Midnight the ground is already dark, so the dock does not have the "faint
    // rectangle on white" problem Ice has; the job here is only to keep the two
    // themes coherent, so this is the same one-step move — a touch DARKER than
    // `panel` (#152033), toward `bg` (#0B1220) — which reads as the slab sitting
    // a little deeper than the bar rather than as a second panel colour.
    readonly property color dockSurface: "#111A2B"

    // --- Ink --------------------------------------------------------------------
    readonly property color ink: "#DCE9F4"         // ice-blue text
    readonly property color inkProse: "#DCE9F4"    // Midnight has no deeper prose ink
    readonly property color inkSoft: "#93A7BC"
    readonly property color inkMute: "#5C6E82"

    // --- Hairlines (tinted ice, not white) ---------------------------------------
    readonly property color line: "#14DCF3FF"        // iceBlue at 8%
    readonly property color lineStrong: "#29DCF3FF"  // iceBlue at 16%

    // --- Hover / pressed washes --------------------------------------------------
    readonly property color hoverWash: "#14DCE9F4"   // ink at 8%
    readonly property color pressWash: "#21DCE9F4"   // ink at 13%

    // --- Quick Settings: tile and slider washes -----------------------------------
    // Ice's twins. Same percentages, Midnight's own ink and accent. See the long
    // note beside these in Ice.qml for where the percentages come from.
    //
    // Midnight is the theme the V2 design was actually drawn in, so these are the
    // closest to the original artwork: a tile is a wash of near-white ink, a lit
    // tile is a wash of the accent blue.
    readonly property color tileIdle: "#12DCE9F4"        // ink at 7%
    readonly property color tileHover: "#1CDCE9F4"       // ink at 11%
    readonly property color tileChip: "#1FDCE9F4"        // ink at 12%
    readonly property color tileDisabled: "#08DCE9F4"    // ink at 3%
    readonly property color tileActive: "#2900BFFF"      // accent at 16%
    readonly property color tileActiveHover: "#3800BFFF" // accent at 22%
    readonly property color trackIdle: "#1FDCE9F4"       // ink at 12%
    readonly property color handleFill: "#DCE9F4"        // ink — the design's white handle
    readonly property color handleShadow: "#66000000"    // black at 40%, as the design draws it

    // --- Overlays -----------------------------------------------------------------
    // Ice's twin — read Ice.qml for what it is for. Midnight dims harder than
    // Ice (60% against 35%) because a dark desktop under a dark panel needs
    // more separation to read as "behind" at all. (accentWash lives further
    // down, beside the accents it belongs to.)
    readonly property color scrim: "#990B1220"       // bg navy at 60%

    // Ice's twin — read Ice.qml for what it is for. The SAME value in both
    // themes, deliberately: a screen going dim is a screen going dark, and it
    // does not have an opinion about light and dark mode.
    readonly property color dimInk: "#05070B"
    // Ice's twin — read Ice.qml for why the app switcher dims so much less than
    // everything else. Midnight dims harder here for the same reason it dims
    // harder above: a dark panel over a dark desktop needs more separation
    // before it reads as being in front. 30% against Ice's 12%, in the same
    // ratio the two `scrim` values already sit in.
    readonly property color switcherScrim: "#4D0B1220" // bg navy at 30%

    // --- Semantic colours, tuned for a dark ground -------------------------------
    readonly property color success: "#5FC9B0"
    readonly property color warn: "#E0A35A"
    readonly property color danger: "#E07B7B"
    readonly property color starred: "#E6B947"

    // --- The four accents ---------------------------------------------------------
    readonly property color accent: aquariusBlue
    readonly property color aquariusBlue: "#00BFFF"  // Deep Sky Blue
    readonly property color indigo: "#9B82FF"
    readonly property color turquoise: "#40E0D0"
    readonly property color aquamarine: "#7FFFD4"

    // The ink that goes ON TOP of an accent-coloured surface — a pressed tile,
    // a selected row. NOT named `onAccent`: QML reads any name shaped `onSomething`
    // as a signal handler for the signal `Something`, so `onAccent` refuses to
    // load at all ("Cannot assign a value to a signal"). Learned the hard way,
    // first run on hardware, 2026-09-01.
    readonly property color inkOnAccent: "#08121E"

    // The accent as a wash. Ice's twin — see the long note beside `accentWash`
    // in Ice.qml for what it is for and the one thing it does not do.
    //
    // Midnight's accent is a much brighter blue than Ice's, so the SAME 16%
    // that reads as a gentle tint on white would glare on deep navy. It is
    // dialled back to 12% here on purpose; the two are meant to look equally
    // quiet, not to carry equal numbers.
    readonly property color accentWash: "#1F00BFFF"  // aquariusBlue at 12%
}
