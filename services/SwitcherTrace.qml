// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SwitcherTrace — the app switcher's flight recorder
// =============================================================================
// WHY THIS EXISTS, IN ONE PARAGRAPH
//
//   Royce, on the bench, three times now: "sometimes it won't switch to the
//   selected app." Every fix so far has been REASONED OUT OF THE SOURCE — read
//   labwc, read Qt, read xremap, work out an order of events that would explain
//   it, fix that order. Twice that produced a real fix. It has never produced
//   EVIDENCE. "Sometimes" cannot be argued with; it can only be recorded.
//
//   So this file turns the switcher into something that writes down what
//   happened. When the switcher misses, Royce turns the trace on, makes it miss
//   again, and copies out twenty lines that say exactly which step did not
//   happen. Nobody has to guess after that.
//
// =============================================================================
// IT IS OFF UNLESS YOU TURN IT ON
// =============================================================================
// Two ways to turn it on, and they mean the same thing:
//
//     AQ_SWITCHER_TRACE=1            the dedicated switch
//     AQ_TRACE=switcher              a comma-separated list of areas, for when
//                                    other parts of the shell grow traces too
//                                    (AQ_TRACE=switcher,dock would do both)
//
// ⚠️ AQ_LOG IS NOT A SWITCH, AND IT NEVER WAS.
//   It is easy to assume `AQ_LOG` is a knob with categories in it, because that
//   is what the name sounds like. It is not. In AquariusOS `AQ_LOG` is a FILE
//   PATH — /usr/bin/aquarius-session sets it to the session log, and
//   /usr/libexec/aquarius-shell-start pipes the whole shell into it. So AQ_LOG
//   decides WHERE these lines land, and the two variables above decide WHETHER
//   they are written at all. Both are needed and they do different jobs.
//
// WHERE THE LINES GO. Nowhere new. `console.info` from QML is the shell's
// standard output, and /usr/libexec/aquarius-shell-start already sends that,
// prefixed "[shell]", into $AQ_LOG — which is ~/.local/state/aquarius/session.log
// on a real machine. No second log file, no file handle of our own, nothing to
// rotate. docs/app-switcher.md has the exact commands for reading it.
//
// =============================================================================
// WHAT ONE LINE LOOKS LIKE
// =============================================================================
//     [shell] switcher +0000ms open-request  delta=1 open=false entries=6
//     [shell] switcher +0003ms surface       visible=true
//     [shell] switcher +0038ms focus-gained
//     [shell] switcher +0402ms key-release   key=Super_L(0x1000053) mods=0x0 \
//                                            grace=false saw=false restart=false
//     [shell] switcher +0402ms decision      release action=none grace=arm ...
//     [shell] switcher +0462ms commit        index=2 app=org.gnome.Nautilus ...
//     [shell] switcher +0562ms focus-check   wanted=... got=... match=false
//
// The `+NNNNms` is milliseconds SINCE THE PANEL LAST OPENED, not wall-clock
// time, and that is deliberate: every question about this feature is a question
// about how many milliseconds apart two things were. The wall-clock time is on
// the line too, at the end, for lining up against the rest of the session log.
// =============================================================================
pragma Singleton

import Quickshell

Singleton {
    id: root

    // ---- is it on? -----------------------------------------------------------
    // Worked out once, when the shell starts. There is deliberately no way to
    // turn it on while the shell is running: it would mean a file watcher and a
    // reload path for a diagnostic, and logging out and back in is a smaller
    // thing to ask than a moving target is to debug.
    //
    // `Quickshell.env` returns null for a variable that is not set, so every
    // read below is written to survive that.
    readonly property bool enabled: {
        const direct = Quickshell.env("AQ_SWITCHER_TRACE") || "";
        if (direct === "1" || direct === "true" || direct === "yes")
            return true;

        const areas = Quickshell.env("AQ_TRACE") || "";
        if (areas === "")
            return false;

        // Split on commas and spaces, trim each piece, and look for our name.
        // `indexOf` on the raw string would say yes to AQ_TRACE=noswitcher.
        const parts = areas.replace(/\s/g, ",").split(",");
        for (let i = 0; i < parts.length; i++) {
            if (parts[i].trim() === "switcher")
                return true;
        }
        return false;
    }

    // ---- the clock -----------------------------------------------------------
    // Milliseconds since the panel last opened. `mark()` resets it.
    property double origin: 0

    function mark(): void {
        root.origin = Date.now();
    }

    // Four digits of milliseconds, zero-padded, so the lines line up in a column
    // and a gap is visible by eye rather than by arithmetic. Anything over ten
    // seconds simply gets wider; it is not worth clamping.
    function stamp(): string {
        const ms = Math.max(0, Math.round(Date.now() - root.origin));
        let text = String(ms);
        while (text.length < 4)
            text = "0" + text;
        return "+" + text + "ms";
    }

    // ---- writing a line ------------------------------------------------------
    // `event` is one word from a small fixed vocabulary — open-request, surface,
    // focus-gained, focus-lost, key-press, key-release, decision, commit,
    // activate, focus-check, retry, cancel, close. Keeping it to one word means
    // the whole trace can be filtered with a single grep.
    //
    // `fields` is a plain object; it is printed as name=value pairs in whatever
    // order the object gives them, which for an object literal is the order it
    // was written in.
    //
    // ⚠️ THE `enabled` CHECK IS FIRST, BEFORE ANY WORK.
    //   These calls sit in the key handlers — the most timing-sensitive code in
    //   this shell — and a trace that cost a millisecond to decide not to print
    //   would be changing the very thing it was brought in to measure.
    function log(event: string, fields: var): void {
        if (!root.enabled)
            return;

        let line = "switcher " + root.stamp() + " " + event;
        while (line.length < 34)
            line += " ";

        if (fields) {
            const names = Object.keys(fields);
            for (let i = 0; i < names.length; i++)
                line += " " + names[i] + "=" + root.show(fields[names[i]]);
        }

        // The wall-clock time last, so that a trace line can be lined up with
        // the rest of the session log and with anything journalctl says.
        line += " at=" + new Date().toISOString();

        console.info(line);
    }

    // Turn one value into something readable and, above all, SHORT. A trace
    // line that wraps in a terminal is a trace line nobody reads.
    function show(value: var): string {
        if (value === null || value === undefined)
            return "none";
        if (value === true)
            return "true";
        if (value === false)
            return "false";
        if (typeof value === "number")
            return String(value);
        if (typeof value === "string")
            return value === "" ? "''" : value;
        return String(value);
    }

    // ---- naming a window -----------------------------------------------------
    // A Toplevel printed raw is something like "Toplevel(0x55d3f0a12340)", which
    // is unreadable but is also the only STABLE identity a window has from out
    // here — there is no window id in the foreign-toplevel protocol that we can
    // see. So both halves are printed: the app id, which a person can read, and
    // the object's own address, which is what tells two windows of the same
    // application apart from one line to the next.
    //
    // A window that has since been destroyed comes back as "gone", and that on
    // its own answers one of the open questions about this bug.
    function window(win: var): string {
        if (!win)
            return "none";

        let appId = "";
        let handle = "";
        try {
            appId = win.appId || "?";
            handle = String(win);
        } catch (error) {
            return "gone";
        }

        // Keep only the address out of "Toplevel(0x…)", which is the only part
        // of it that carries information. Cut at the first character that is
        // not part of a hex number — done by hand rather than with a regular
        // expression, because the character we are cutting at is a closing
        // bracket and tests/test-shell.sh counts brackets in this file.
        const at = handle.indexOf("0x");
        if (at !== -1) {
            let out = "";
            for (let i = at; i < handle.length; i++) {
                const c = handle.charAt(i);
                if ("0123456789abcdefABCDEFx".indexOf(c) === -1)
                    break;
                out += c;
            }
            handle = out;
        }

        return appId + "@" + handle;
    }
}
