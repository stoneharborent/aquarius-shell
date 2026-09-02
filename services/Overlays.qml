// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// Overlays — only one thing at a time may own the keyboard
// =============================================================================
// THE BUG THIS FILE EXISTS TO KILL
//
//   Found on the bench on 2026-09-01, and written up as defect 1 in
//   docs/first-run-on-hardware.md:
//
//     Open Quick Settings. Then press the search key.
//
//     The palette appears. It dims the desktop. It shows a blinking text
//     cursor. And every single keystroke goes somewhere else — nothing at all
//     is typed into it, and nothing on screen tells you why.
//
//   The reason is not a bug in either component. Quick Settings is a
//   `PopupWindow` with `grabFocus: true`, which asks the COMPOSITOR for an
//   input grab: "send me the next click wherever it lands, so I can dismiss
//   myself". A grab is exclusive by definition. While the compositor is holding
//   one, the layer surface the palette just put on screen can ask for keyboard
//   focus as politely as it likes and will not get it.
//
//   So this is not something either window can fix by itself. It is a rule
//   about the SHELL: two surfaces must never both believe they have the
//   keyboard. Somewhere has to hold that rule, and a rule shared by three
//   components that live in three different directories belongs in a singleton,
//   the same way Focus does (see services/FocusState.qml).
//
// THE RULE, IN ONE SENTENCE
//
//   ONE EXCLUSIVE OVERLAY AT A TIME: opening any of Flow Search, Quick Settings
//   or the notifications panel closes the other two, whichever way round it
//   happens.
//
//   It is symmetric on purpose. "The palette dismisses Quick Settings but not
//   the other way round" is one more thing for a person to learn about their
//   own desktop, and it would leave the mirror-image bug (palette open, click
//   the status cluster) alive for somebody to re-find in six months. One rule,
//   both directions, no exceptions — that is cheaper to implement AND cheaper
//   to explain.
//
// WHY THE NOTIFICATIONS PANEL IS IN HERE TOO
//
//   It does NOT take a compositor grab — it is a layer-shell `PanelWindow` with
//   `focusable: true`, which is a request, not a grab, so it is not the thing
//   that caused defect 1. It is included anyway for two reasons that have
//   nothing to do with grabs:
//
//     * it and Quick Settings are drawn in exactly the same corner, 8px under
//       the bar, so having both open is a visual collision;
//     * it covers the whole screen with a click-catcher, so with it open the
//       "click outside to dismiss" of anything else lands on the wrong window.
//
//   And beyond both: a rule with an exception is not a rule anybody remembers.
//
// HOW IT WORKS
//
//   Each overlay does two things, and no more:
//
//     1. REGISTERS itself when it is created, handing over a function that
//        closes it, and UNREGISTERS when it is destroyed.
//     2. Calls `claim()` on the way open — before it shows anything.
//
//   `claim(owner)` calls every OTHER registered closer. That is the whole
//   mechanism. Nothing here knows what a search palette or a Wi-Fi tile is; it
//   is a list of "here is how to shut me up" callbacks.
//
// ⚠️ WHY THIS IS A LIST AND NOT A SINGLE `whichOneIsOpen` STRING
//
//   Because Quick Settings is not one object. TopBar builds one entire bar per
//   monitor with `Variants`, and each bar carries its own `QuickSettingsPopup`
//   anchored to its own status cluster (it has to — a popup has to hang off a
//   real item on a real screen). On a two-monitor desk there are two of them,
//   and "close Quick Settings" has to mean BOTH, not the one that happens to be
//   remembered. The same is true of anything else that ever goes per-screen.
//
//   So: registrations are a list, every entry is closed, and the count of
//   entries is nobody's business but this file's.
//
// ⚠️ UNREGISTERING IS NOT OPTIONAL
//
//   `Variants` destroys a screen's windows when that monitor is unplugged. A
//   closer left in the list after its object is gone would be called on the
//   next claim, on a destroyed object. Every registrant pairs its
//   `Component.onCompleted` with a `Component.onDestruction`.
//
// WHAT THIS DELIBERATELY DOES NOT DO
//
//   It does not open anything, and it holds no idea of "the current overlay"
//   that could drift out of step with what is actually on screen. Each overlay
//   still owns its own open/closed state; this only ever asks them to close.
//   A registry that could get out of sync with reality would be a second source
//   of truth, and the shell already has a rule about those.
//
// NOT PROVEN ON HARDWARE. The wiring is written and checked statically
// (tests/test-shell.sh section 27); it has not been re-run on the bench PC.
// See docs/first-run-on-hardware.md, defect 1.
// =============================================================================
pragma Singleton

import Quickshell

Singleton {
    id: root

    // The registered overlays: a plain array of { owner, close } records.
    //
    // `owner` is the QML object, used only as an identity so that an overlay
    // opening does not ask itself to close. `close` is a function that takes no
    // arguments and puts that overlay away.
    //
    // Nothing outside this file reads it. It is a `property var` rather than a
    // JavaScript variable purely so it survives as object state.
    property var registrations: []

    // Called by each overlay as it is created.
    //
    // closeFn should be a small arrow function that calls the overlay's own
    // close method — `() => root.closeSearch()` rather than the bare
    // `root.closeSearch`. A bare method reference detaches from its object, and
    // while every closer in this shell happens to use explicit ids inside and
    // would survive that, the wrapper costs one line and removes the question.
    function register(owner, closeFn): void {
        if (!owner || !closeFn)
            return;

        // Registering twice would close the same overlay twice — harmless, but
        // it is a symptom of wiring gone wrong, so refuse it quietly.
        for (let i = 0; i < root.registrations.length; i++) {
            if (root.registrations[i].owner === owner)
                return;
        }

        // Concat rather than push: reassigning the property is what makes the
        // change visible to QML's property system. Nothing binds to this today,
        // and a list that only sometimes notifies is a trap for whoever does.
        root.registrations = root.registrations.concat([{
            owner: owner,
            close: closeFn
        }]);
    }

    // Called by each overlay as it is destroyed. See the warning above about
    // unplugged monitors.
    function unregister(owner): void {
        root.registrations = root.registrations.filter(entry => entry.owner !== owner);
    }

    // "I am about to open. Everybody else, go away."
    //
    // Call this BEFORE putting the surface on screen, so that the compositor
    // has already been told to drop the old grab by the time the new surface
    // asks for one.
    //
    // Closing is expected to be idempotent — every closer in this shell begins
    // by checking whether it is open at all — so calling this when nothing else
    // is open costs nothing.
    function claim(owner): void {
        const entries = root.registrations;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].owner !== owner)
                entries[i].close();
        }
    }

    // Close everything, including the caller. Not used by the overlays
    // themselves; it is here for the cases that will want it later — starting
    // a screen recording, going into Game Mode, locking the screen.
    function closeAll(): void {
        root.claim(null);
    }
}
