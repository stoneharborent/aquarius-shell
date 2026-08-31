// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// fuzzy.js — how the Flow Search palette decides what you meant
// =============================================================================
// WHAT THIS IS
//   Plain JavaScript. No QML types, no Quickshell, no state — every function
//   here takes strings and returns a number. That is deliberate: it means this
//   file can be run and CHECKED on a Mac, by node, without a QML engine
//   anywhere. tests/search-js-tests.mjs does exactly that, and it is the only
//   part of this shell that has ever actually been EXECUTED before reaching a
//   Linux machine.
//
//   `.pragma library` tells QML that this file holds no per-instance state and
//   can be shared by every importer. It also forbids touching QML objects from
//   in here, which is the property that makes it testable.
//
// THE IDEA
//   A person types "kd" and means Kdenlive. They type "vid" and might mean
//   "Video Editor" (the generic name) or "kdenlive" (the id) or a program whose
//   description mentions video. All of those should match — but not equally, and
//   the difference has to be big enough that the right answer is reliably first.
//
//   So matching is TIERED. Each tier is a band of scores that cannot overlap
//   with the tier below it, no matter how the within-tier tie-breaks fall:
//
//     1000        the text IS the query                    "Files" / "files"
//      860-900    the text STARTS WITH the query           "kd" -> "Kdenlive"
//      760-800    a WORD in the text starts with it        "term" -> "GNOME Terminal"
//      710-750    it is the text's INITIALS                "vlc" -> "Video Lan Client"
//      610-650    the query appears somewhere inside       "ent" -> "Kdenlive"
//      200-500    the letters appear in ORDER, with gaps   "kde" -> "KDE Connect"
//       -1        no match at all
//
//   Inside a tier, shorter text wins, because when two programs both start with
//   what you typed you almost always meant the one whose name is closest to it.
//   That tie-break is capped so it can never push a result out of its tier.
//
// WHY NOT A LIBRARY
//   Because adding a dependency to a repo that ships text files to a
//   distro-packaged binary would mean inventing a packaging story for the sake
//   of ~120 lines of string handling. See docs/flow-search.md.
// =============================================================================
.pragma library

// Returned by every scoring function when the query does not match at all.
var NO_MATCH = -1;

// Characters that end one "word" and begin another. Used both for the
// word-prefix tier and for working out a text's initials.
var BOUNDARIES = " \t-_./\\:,+&()[]{}";

// The most a within-tier tie-break may subtract. Every tier is 50 points tall,
// so 40 keeps the tiers strictly ordered with room to spare.
var MAX_TIE_BREAK = 40;

function isBoundary(ch) {
    return BOUNDARIES.indexOf(ch) !== -1;
}

// Shorter texts score slightly higher within their tier. Capped, see above.
function tieBreak(hayLength, needleLength) {
    var extra = hayLength - needleLength;
    if (extra <= 0)
        return 0;
    var penalty = Math.floor(extra / 2);
    return penalty > MAX_TIE_BREAK ? MAX_TIE_BREAK : penalty;
}

// "GNOME System Monitor" -> "gsm". Used for the initials tier, which is how
// people reach an app whose name they only ever say as letters.
function initialsOf(text) {
    var out = "";
    var atWordStart = true;
    for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i);
        if (isBoundary(ch)) {
            atWordStart = true;
            continue;
        }
        if (atWordStart) {
            out += ch;
            atWordStart = false;
        }
    }
    return out;
}

// The loosest tier: every letter of the query appears in the text, in order,
// with anything allowed in between. Scored on how TIGHT that run is, so
// "kde" against "KDE Connect" (three letters together, at the start) beats
// "kde" against "Kate Document Editor" (three letters scattered).
function subsequenceScore(hay, needle) {
    var hayIndex = 0;
    var bonus = 0;
    var skipped = 0;
    var lastMatch = -2;

    for (var n = 0; n < needle.length; n++) {
        var target = needle.charAt(n);
        var found = -1;
        while (hayIndex < hay.length) {
            if (hay.charAt(hayIndex) === target) {
                found = hayIndex;
                break;
            }
            hayIndex++;
        }
        if (found === -1)
            return NO_MATCH;

        if (found === 0 || isBoundary(hay.charAt(found - 1)))
            bonus += 30;                       // landed on the start of a word
        if (found === lastMatch + 1)
            bonus += 15;                       // ran straight on from the last letter

        skipped += (lastMatch < 0) ? found : (found - lastMatch - 1);
        lastMatch = found;
        hayIndex++;
    }

    var score = 300 + bonus - skipped * 2;
    if (score < 200)
        score = 200;
    if (score > 500)
        score = 500;
    return score;
}

// Score ONE piece of text against the query. 0-1000, or NO_MATCH (-1).
// Case is ignored. Both sides are trimmed; neither is otherwise altered.
function score(haystack, needle) {
    if (haystack === null || haystack === undefined)
        return NO_MATCH;
    if (needle === null || needle === undefined)
        return NO_MATCH;

    var hay = String(haystack).toLowerCase().trim();
    var query = String(needle).toLowerCase().trim();

    if (hay.length === 0 || query.length === 0)
        return NO_MATCH;

    if (hay === query)
        return 1000;

    var tie = tieBreak(hay.length, query.length);
    var at = hay.indexOf(query);

    if (at === 0)
        return 900 - tie;                      // starts with

    if (at > 0 && isBoundary(hay.charAt(at - 1)))
        return 800 - tie;                      // a word inside it starts with

    var initials = initialsOf(hay);
    if (initials.length > 1 && initials.indexOf(query) === 0)
        return 750 - tie;                      // it is the initials

    if (at > 0)
        return 650 - tie;                      // appears somewhere inside

    return subsequenceScore(hay, query);       // letters in order, or no match
}

// Score a set of weighted fields and keep the best.
//
//   fields: [{ text: "Kdenlive", weight: 1.0 }, { text: "Video Editor", weight: 0.7 }]
//
// A weight below 1 says "matching here counts for less than matching the name".
// Because the tiers are 1000-scale, a 0.65-weighted EXACT match (650) still
// beats a full-weight subsequence match (<=500) — which is the behaviour we
// want: a keyword you typed exactly is a better signal than a name you nearly
// typed. Returns NO_MATCH if nothing matched.
function bestScore(fields, needle) {
    if (!fields || fields.length === 0)
        return NO_MATCH;

    var best = NO_MATCH;
    for (var i = 0; i < fields.length; i++) {
        var field = fields[i];
        if (!field || !field.text)
            continue;
        var raw = score(field.text, needle);
        if (raw === NO_MATCH)
            continue;
        var weight = (field.weight === undefined) ? 1.0 : field.weight;
        var weighted = Math.round(raw * weight);
        if (weighted > best)
            best = weighted;
    }
    return best;
}

// Convenience for anything that only wants a yes/no.
function matches(haystack, needle) {
    return score(haystack, needle) !== NO_MATCH;
}
