// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// The app switcher's key rules, actually executed
// =============================================================================
// components/switcher/switcher-keys.js decides what the switcher should do
// about one key event. Every bug this shell has had in that area was a SEQUENCE
// — a release, then a chord, then a modifier coming back, in that order and a
// few milliseconds apart — and a sequence is the one thing reading the code
// never catches. So the sequences are written out below and run.
//
// Same trick as tests/search-js-tests.mjs and tests/notifications-js-tests.mjs:
// a QML `.pragma library` file is ordinary JavaScript with one non-standard
// line at the top, so node can strip that line and run the rest.
//
// THE KEY NUMBERS ARE THE REAL ONES. QML hands the rulebook `Qt.Key_Escape` and
// friends, and the table below is those same values out of Qt's own
// qnamespace.h. They are part of Qt's public API and have not moved since Qt 4.
//
// Run it directly:   node tests/switcher-js-tests.mjs
// Or with the rest:  ./tests/test-shell.sh
// =============================================================================
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..");

function loadQmlLibrary(relativePath) {
    const source = readFileSync(join(repoRoot, relativePath), "utf8");

    if (!/^\s*\.pragma\s+library\s*$/m.test(source)) {
        throw new Error(`${relativePath} is missing its '.pragma library' line`);
    }

    const stripped = source.replace(/^\s*\.pragma\s+library\s*$/m, "");
    const context = vm.createContext({ Math, Number, String, Object, Error });
    vm.runInContext(stripped, context, { filename: relativePath });
    return context;
}

let failures = 0;
let checks = 0;

function check(description, actual, expected) {
    checks += 1;
    if (!Object.is(actual, expected)) {
        failures += 1;
        console.log(`  FAIL ${description}`);
        console.log(`       expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
    }
}

const { pressDecision, releaseDecision, keyName } =
    loadQmlLibrary("components/switcher/switcher-keys.js");

// Qt's key numbers, exactly as AppSwitcher.qml's `keyCodes` hands them over.
const K = {
    escape: 0x01000000,
    down: 0x01000015,
    end: 0x01000011,
    up: 0x01000013,
    home: 0x01000010,
    meta: 0x01000022,
    superL: 0x01000053,
    superR: 0x01000054,
    alt: 0x01000023,
    ret: 0x01000004,
    enter: 0x01000005
};

const LETTER_A = 0x41;

// -----------------------------------------------------------------------------
// A tiny model of the panel, so a whole gesture can be written as a list of
// events. It holds only what the rulebook is given: whether the commit timer is
// running, whether anything has been heard yet, and which modifier the remapper
// is holding. `commits` counts how many times the panel would have gone to the
// selected app.
// -----------------------------------------------------------------------------
function panel() {
    return {
        graceRunning: false,
        sawKeyEvent: false,
        remapperModifier: 0,
        gestureRestart: false,
        actions: [],
        commits: 0
    };
}

function apply(p, d) {
    p.sawKeyEvent = true;
    p.remapperModifier = d.remapperModifier;
    if (d.gestureRestart) p.gestureRestart = true;
    if (d.grace === "stop") p.graceRunning = false;
    else if (d.grace === "arm") p.graceRunning = true;
    if (d.action !== "none") p.actions.push(d.action);
    return d;
}

function press(p, key) {
    return apply(p, pressDecision(K, key, p));
}

function release(p, key) {
    return apply(p, releaseDecision(K, key, p));
}

// Sixty milliseconds go by with nothing arriving: the timer fires and the panel
// commits. This is the ONLY way a commit happens.
function graceFires(p) {
    if (p.graceRunning) {
        p.graceRunning = false;
        p.commits += 1;
        p.actions.push("commit");
    }
}

// -----------------------------------------------------------------------------
console.log("--- the ordinary gesture: hold ⌘, tap Tab, let go ---");
{
    const p = panel();           // the panel is open; Tab came in over IPC
    release(p, K.superL);        // ⌘ comes up
    check("the release arms the commit", p.graceRunning, true);
    check("it does not commit on the spot", p.commits, 0);
    graceFires(p);
    check("sixty milliseconds later it commits", p.commits, 1);
    check("and it is not a restarted gesture", p.gestureRestart, false);
}

// The Windows profile holds Alt instead, and Qt may report the Mac key under
// any of three names depending on the keymap. All four must commit.
for (const [name, key] of [["Meta", K.meta], ["Super_L", K.superL],
                           ["Super_R", K.superR], ["Alt", K.alt]]) {
    const p = panel();
    release(p, key);
    graceFires(p);
    check(`letting go of ${name} commits`, p.commits, 1);
}

// -----------------------------------------------------------------------------
console.log("--- ⌘↓ in an ordinary app: Aquarius Keys sends Ctrl+End (2026-09-07) ---");
{
    // xremap has to let go of ⌘ to send the chord, then puts it back.
    const p = panel();
    release(p, K.superL);        // the momentary let-go
    check("a commit is armed by it", p.graceRunning, true);
    press(p, K.end);             // the chord's key, arriving at once
    check("the chord opens the window list", p.actions.join(","), "down");
    check("and calls the commit off", p.graceRunning, false);
    press(p, K.superL);          // xremap resurrects ⌘
    check("the resurrection is not a fresh gesture", p.gestureRestart, false);
    check("nor is it remembered as a chord's modifier", p.remapperModifier, 0);

    // Now the person really does let go.
    release(p, K.superL);
    graceFires(p);
    check("the real let-go still commits", p.commits, 1);
}

// -----------------------------------------------------------------------------
console.log("--- ⌘↑ in Files: Aquarius Keys sends Alt+Up, a DIFFERENT modifier ---");
{
    const p = panel();
    release(p, K.superL);        // the momentary let-go
    press(p, K.alt);             // the chord's own modifier
    check("the chord's modifier is remembered", p.remapperModifier, K.alt);
    press(p, K.up);
    check("Up walks back up the list", p.actions.join(","), "up");
    release(p, K.alt);           // and the remapper puts it down again
    check("its release does not arm a commit", p.graceRunning, false);
    check("and it is forgotten again", p.remapperModifier, 0);
    graceFires(p);
    check("so nothing was committed by the chord", p.commits, 0);
}

// -----------------------------------------------------------------------------
console.log("--- ⌘↓ in Files: Aquarius Keys sends Enter, which means two things ---");
{
    // From the remapper — it arrives in the instant after the let-go.
    const p = panel();
    release(p, K.superL);
    check("Enter from the remapper means Down", press(p, K.enter).action, "down");
}
{
    // From a person — nothing came up a moment ago.
    const p = panel();
    check("Enter from a person means go there", press(p, K.ret).action, "commit");
}

// -----------------------------------------------------------------------------
console.log("--- the fast tap: the release landed somewhere else (2026-09-14) ---");
{
    // ⌘-Tab, let go inside the gap before the panel has the keyboard. The panel
    // is open and has heard NOTHING. Then ⌘ is pressed again for another go.
    const p = panel();
    check("nothing has been heard yet", p.sawKeyEvent, false);

    press(p, K.superL);
    check("a first-ever modifier press restarts the gesture", p.gestureRestart, true);
    check("it commits nothing on its own", p.commits, 0);
    check("and it is not read as a remapper chord", p.remapperModifier, 0);

    // The second Tab opens afresh (AppSwitcher.step does that); this gesture
    // then behaves exactly like an ordinary one.
    p.gestureRestart = false;
    release(p, K.superL);
    graceFires(p);
    check("and the second gesture commits normally", p.commits, 1);
}
{
    // THE CASE THIS MUST NOT BREAK: a modifier press that is NOT the first
    // thing heard is the remapper resurrecting ⌘ mid-gesture. Restarting there
    // would throw away a selection the person is in the middle of using.
    const p = panel();
    release(p, K.superL);
    press(p, K.end);
    press(p, K.superL);
    check("a mid-gesture modifier press does not restart", p.gestureRestart, false);
}
{
    // And a modifier press after any other key is not a fresh gesture either.
    const p = panel();
    press(p, LETTER_A);
    press(p, K.meta);
    check("a modifier press after a stray key does not restart", p.gestureRestart, false);
}
{
    // Only a PRESS says it. A release as the first event is the ordinary case
    // — the panel got the keyboard in time.
    const p = panel();
    release(p, K.superL);
    check("a first-ever modifier RELEASE is the normal path", p.gestureRestart, false);
    graceFires(p);
    check("and it commits", p.commits, 1);
}

// -----------------------------------------------------------------------------
console.log("--- Escape, and keys the panel does not want ---");
{
    const p = panel();
    check("Escape cancels", press(p, K.escape).action, "cancel");
}
{
    const p = panel();
    const d = press(p, LETTER_A);
    check("a letter is not ours", d.handled, false);
    check("and it does nothing", d.action, "none");
}
{
    const p = panel();
    release(p, K.superL);
    press(p, LETTER_A);
    graceFires(p);
    check("but a key arriving does call a pending commit off", p.commits, 0);
}
{
    const p = panel();
    const d = release(p, LETTER_A);
    check("releasing a letter is not ours", d.handled, false);
    check("and leaves the timer alone", d.grace, "keep");
}

// -----------------------------------------------------------------------------
console.log("--- the arrows, under both names ---");
for (const [name, key, expected] of [["Down", K.down, "down"], ["End", K.end, "down"],
                                     ["Up", K.up, "up"], ["Home", K.home, "up"]]) {
    const p = panel();
    check(`${name} means ${expected}`, press(p, key).action, expected);
}

// -----------------------------------------------------------------------------
console.log("--- the trace can name every key the rulebook has an opinion about ---");
// Added 2026-09-15 with the flight recorder. The names are what Royce reads off
// the bench; a key the rulebook knows about but the namer does not would print
// as a bare number in exactly the trace somebody is trying to read.
for (const [name, key] of [["Escape", K.escape], ["Down", K.down], ["End", K.end],
                           ["Up", K.up], ["Home", K.home], ["Meta", K.meta],
                           ["Super_L", K.superL], ["Super_R", K.superR],
                           ["Alt", K.alt], ["Return", K.ret], ["Enter", K.enter]]) {
    check(`${name} is named, not numbered`, keyName(K, key), name);
}
{
    // Every key the rulebook reacts to must have a name. This is the check that
    // catches "a key was added to the rules and not to the namer": anything the
    // rulebook handles, or acts on, has to come back as something other than a
    // bare hex number.
    for (const key of Object.values(K)) {
        const p = panel();
        const d = pressDecision(K, key, p);
        if (d.handled || d.action !== "none") {
            check(`a key the rules act on (0x${key.toString(16)}) has a name`,
                  /^0x/.test(keyName(K, key)), false);
        }
    }
}
{
    // A key it has no opinion about is honestly printed as a number.
    check("a plain letter prints as hex", keyName(K, LETTER_A), "0x41");
}

// -----------------------------------------------------------------------------
console.log("");
if (failures === 0) {
    console.log(`  OK   ${checks} checks passed.`);
    process.exit(0);
}
console.log(`  ${failures} of ${checks} checks FAILED.`);
process.exit(1);
