// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// switcher-keys.js — what the app switcher should do about one key event
// =============================================================================
// WHY THIS IS A SEPARATE FILE
//   The switcher's key handling is the most argued-about twenty lines in this
//   repository. It has been changed three times by bench findings (2026-09-07,
//   09-08 and 09-14), and every one of those findings was a sequence of events
//   arriving in a particular ORDER — the sort of thing that is impossible to
//   check by reading and trivial to check by running.
//
//   So the DECISIONS live here, as plain JavaScript with no QML in them, and
//   tests/switcher-js-tests.mjs runs them through node: real sequences, real
//   answers, on a machine with no screen. AppSwitcher.qml keeps the doing —
//   moving the selection, starting the timer, closing the panel.
//
//   The long WHY, in plain language, is in the header of AppSwitcher.qml and in
//   docs/app-switcher.md. This file is the rulebook, not the explanation.
//
// HOW TO READ A DECISION
//   Every function takes:
//     k      the Qt key numbers, handed in from QML (Qt.Key_Escape and friends)
//            so that no number is written down twice.
//     key    the key this event is about.
//     state  three facts the panel knows:
//              graceRunning     a commit is pending — the modifier came up in
//                               the last sixty milliseconds and nothing has
//                               happened since.
//              sawKeyEvent      this panel has received AT LEAST ONE keyboard
//                               event since it opened. See "the fast tap".
//              remapperModifier a modifier the remapper pressed as part of a
//                               chord, whose release must be ignored (0 = none).
//   and returns:
//     action            "none" | "cancel" | "down" | "up" | "commit"
//     grace             what to do with the commit timer:
//                         "stop" call it off, "arm" start it, "keep" leave it
//     remapperModifier  the new value of that state
//     gestureRestart    true = the NEXT Tab should open the panel afresh rather
//                       than step along it. See below.
//     handled           true = the event is ours; do not pass it on.
//
// =============================================================================
// THE FAST TAP — the 2026-09-14 bench finding, and the one new rule here
// =============================================================================
// Royce: "the app switcher command sometimes doesn't select or switch apps if
// the command is hit too quickly."
//
// WHAT IS ACTUALLY HAPPENING. Pressing Command-Tab runs a small program, which
// talks to the shell, which puts a surface on screen, which the compositor then
// hands the keyboard to. That takes a few tens of milliseconds. Let go of
// Command inside that gap and labwc posts the release to whatever had the
// keyboard BEFORE the panel did — the window you were in. The panel never sees
// it, so it never commits: it just sits there, and nothing switches. This was
// written down as a known limit when the switcher was built; the bench says it
// happens often enough to be a bug.
//
// WE CANNOT SEE THE RELEASE WE MISSED. Wayland tells a client the modifier
// state when it hands over the keyboard, but Qt keeps that to itself — it does
// not turn the keys held at focus time into events (qwaylandinputdevice.cpp,
// keyboard_enter: `Q_UNUSED(keys)`). So the panel genuinely cannot tell "still
// holding Command" from "let go before you could see it".
//
// BUT THE NEXT PRESS TELLS US. Whatever the person does next, there are only
// two possibilities, and they look completely different:
//
//   they were still holding      the very next thing the panel hears is the
//                                RELEASE of that modifier. A modifier that is
//                                already down cannot be pressed again.
//   the release was lost         they press Command again to have another go —
//                                and THAT press lands on the panel, because by
//                                now it certainly has the keyboard.
//
// So: THE FIRST KEYBOARD EVENT AFTER THE PANEL OPENS BEING A MODIFIER *PRESS*
// MEANS THE PREVIOUS GESTURE'S RELEASE NEVER REACHED US. Nothing else can
// produce it. When it happens the panel is told to start the gesture over, so
// the second Command-Tab lands on the app the first one should have — exactly
// as though the panel had been shut when it was pressed. Pressing the keys
// again, which is what a person does anyway, is now the fix.
//
// ⚠️ WHY IT IS "THE FIRST EVENT" AND NOT SIMPLY "A MODIFIER PRESS". Aquarius
//   Keys (xremap) presses the modifier again all the time — it lets go of
//   Command for a few milliseconds to send a remapped chord and then puts it
//   back (the 2026-09-07 finding). But by then the panel has ALREADY heard
//   that release and the chord's own keys, so `sawKeyEvent` is true and the
//   resurrection is not mistaken for a fresh gesture. A panel that restarted on
//   any modifier press would break Command-Down, which is the fix before this
//   one.
// =============================================================================
.pragma library

// The four names a modifier can arrive under. Which one Qt reports depends on
// the keymap, and Alt is the Windows profile's modifier, so all four count.
function isModifier(k, key) {
    return key === k.meta || key === k.superL || key === k.superR || key === k.alt;
}

function decision(action, grace, remapperModifier, gestureRestart, handled) {
    return {
        action: action,
        grace: grace,
        remapperModifier: remapperModifier,
        gestureRestart: gestureRestart,
        handled: handled
    };
}

// ---- a key going DOWN --------------------------------------------------------
// ⚠️ A KEY ARRIVING CALLS OFF A PENDING COMMIT, and that is on purpose: the
//   remapper's chords arrive in the instant after it lets go of the modifier,
//   and a chord means the person is still driving the panel. Every branch below
//   therefore says "stop".
function pressDecision(k, key, state) {
    // `graceRunning` is "the modifier came up within the last sixty
    // milliseconds and nothing has arrived since". A person cannot produce
    // that; the remapper produces it on every remapped chord. So this one
    // boolean is "the remapper sent this, not the person".
    var fromRemapper = !!state.graceRunning;
    var remapper = state.remapperModifier || 0;

    if (key === k.escape)
        return decision("cancel", "stop", remapper, false, true);

    // Ctrl+End / Ctrl+Home are what the Mac keys map makes of Command+Down and
    // Command+Up. Under the switcher they mean Down and Up.
    if (key === k.down || key === k.end)
        return decision("down", "stop", remapper, false, true);

    if (key === k.up || key === k.home)
        return decision("up", "stop", remapper, false, true);

    if (isModifier(k, key)) {
        if (fromRemapper) {
            // The chord's own modifier, or the remapper putting Command back.
            // Its release must not be read as the person letting go.
            return decision("none", "stop", key, false, true);
        }
        // Nothing has reached this panel since it opened, and now a modifier is
        // being pressed: the previous gesture ended where we could not see it.
        // Start over. (See the long note above.)
        return decision("none", "stop", remapper, !state.sawKeyEvent, true);
    }

    // Enter means two things, and who sent it decides which: from the remapper
    // it is Command+Down with Files in front, which means Down; from a person
    // it means "this one".
    if (key === k.ret || key === k.enter)
        return decision(fromRemapper ? "down" : "commit", "stop", remapper, false, true);

    // Anything else: not ours, but it still calls off a pending commit, because
    // a person pressing a key is a person who has not finished.
    return decision("none", "stop", remapper, false, false);
}

// ---- a key coming UP ---------------------------------------------------------
// THE COMMIT. The release of the modifier is what "let go of Command to go to
// the app you picked" is made of — and it does not commit on the spot, it arms
// a sixty-millisecond timer, so that the remapper's momentary let-go can be
// called off by the chord that follows it.
function releaseDecision(k, key, state) {
    var remapper = state.remapperModifier || 0;

    if (!isModifier(k, key))
        return decision("none", "keep", remapper, false, false);

    if (remapper === key) {
        // The remapper putting down the modifier it picked up for a chord.
        // Not a person letting go, so no commit is armed.
        return decision("none", "keep", 0, false, true);
    }

    return decision("none", "arm", remapper, false, true);
}
