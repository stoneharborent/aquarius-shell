// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// progress.js — reading the two hints that turn a notification into a bar
// =============================================================================
// A notification can carry more than words. The freedesktop specification lets
// the sending application attach "hints", and two of them are what this file is
// about:
//
//   value                             an integer, 0 to 100. "This job is 42%
//                                     done." A server that understands it draws
//                                     a progress bar. GNOME Shell does not; we
//                                     do, which is the point of this file.
//
//   x-canonical-private-synchronous   a name, like "aq-ingest" or "volume".
//                                     "This message REPLACES the last one with
//                                     the same name." It is how a volume popup
//                                     stays one popup instead of becoming
//                                     fifteen while you hold the key down.
//
// https://specifications.freedesktop.org/notification-spec/latest/hints.html
//
// WHY THIS IS A .js FILE AND NOT PART OF NotificationStore.qml
//   Same reason as components/search/fuzzy.js: QML needs a Qt engine, which
//   does not exist on the Mac this repo is written on, so anything written in
//   QML travels to the bench machine with nothing having executed it. Plain
//   JavaScript can be run by node right here — tests/notifications-js-tests.mjs
//   does exactly that. Everything in this file is therefore a pure function of
//   its arguments: no QML types, no Theme, no Quickshell, no state.
//
// WHAT IT HAS TO BE PARANOID ABOUT
//   These hints arrive over D-Bus from ANY application on the machine, and the
//   specification's word for what an application must send is not a promise
//   about what it will send. A string where an integer belongs, a number past
//   100, a negative one, a null — every one of those has to come out of here as
//   "no progress bar" rather than as a bar drawn 3000 pixels wide.
// =============================================================================
.pragma library

// The hint names, spelled once.
var VALUE_HINT = "value";
var SYNC_HINT = "x-canonical-private-synchronous";

// What `percentOf` returns when there is no usable progress in a notification.
// A sentinel rather than null so that callers can compare numbers without first
// having to ask whether they have one.
var NO_PROGRESS = -1;

// -----------------------------------------------------------------------------
// The progress value
// -----------------------------------------------------------------------------

/**
 * The 0–100 in a notification's hints, or NO_PROGRESS if there isn't a usable
 * one.
 *
 * Accepts a number or a string of digits, because both turn up: the hint is
 * specified as a D-Bus int32, but an application sending it as a string is the
 * commonest small mistake and refusing to draw its bar helps nobody.
 *
 * Out-of-range values are CLAMPED, not rejected. A job that reports 104% has
 * miscounted its own work, which is not a reason to take its progress bar away
 * one second before it finishes.
 */
function percentOf(hints) {
    if (!hints)
        return NO_PROGRESS;

    var raw = hints[VALUE_HINT];

    // ONLY a number or a string of digits. Not a boolean, not an object, and
    // above all not an array — JavaScript's Number([50]) is 50, so a hint sent
    // as a list would quietly become a progress bar built on a coincidence.
    if (typeof raw !== "number" && typeof raw !== "string")
        return NO_PROGRESS;
    if (raw === "")
        return NO_PROGRESS;

    var value = Number(raw);
    if (!isFinite(value))
        return NO_PROGRESS;

    value = Math.round(value);
    if (value < 0)
        return 0;
    if (value > 100)
        return 100;
    return value;
}

/** Is there a bar to draw at all? */
function hasProgress(hints) {
    return percentOf(hints) !== NO_PROGRESS;
}

/**
 * Is this a job still running, as opposed to one that has finished?
 *
 * The toast layer uses this to decide whether a notification may be taken off
 * the screen by its own clock. A conversion that takes twenty minutes must not
 * be represented by a progress bar that vanished after five seconds; the same
 * notification at 100% is finished news and may expire like anything else.
 */
function isRunning(hints) {
    var percent = percentOf(hints);
    return percent !== NO_PROGRESS && percent < 100;
}

// -----------------------------------------------------------------------------
// The replace-me-by-name hint
// -----------------------------------------------------------------------------

/**
 * The name a notification asks to be replaced under, or "" if it did not ask.
 *
 * Only strings count. A number or an object here is a sender's bug, and using
 * it as a key would silently merge unrelated notifications into one another —
 * which is a message going missing, the one failure this shell is not allowed.
 */
function tagOf(hints) {
    if (!hints)
        return "";
    var tag = hints[SYNC_HINT];
    if (typeof tag !== "string")
        return "";
    return tag;
}

/**
 * Where in a list of on-screen toasts an arriving one belongs, given the tags
 * already up there.
 *
 * Returns the index of the toast it replaces, or -1 for "this is a new one, put
 * it at the end". `tags` is the list of tags of the toasts currently showing, in
 * the order they are showing, and an untagged toast is "".
 *
 * An empty tag never matches anything — otherwise every ordinary notification
 * on the machine would replace every other ordinary notification, and the
 * desktop would only ever show you the most recent thing that happened.
 */
function replacesIndex(tags, tag) {
    if (!tag)
        return -1;
    for (var i = 0; i < tags.length; ++i) {
        if (tags[i] === tag)
            return i;
    }
    return -1;
}
