// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// The notification progress logic, actually executed
// =============================================================================
// components/notifications/progress.js reads the two hints that turn a
// notification into a progress bar. Those hints arrive over D-Bus from ANY
// application on the machine, which means this file's job is mostly to prove
// what happens when one of them sends rubbish.
//
// Same trick as tests/search-js-tests.mjs: a QML `.pragma library` file is
// ordinary JavaScript with one non-standard line at the top, so node can strip
// that line and run the rest — on the Mac this repo is written on, before
// anything reaches a Linux machine.
//
// Run it directly:   node tests/notifications-js-tests.mjs
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
    const context = vm.createContext({ Math, Number, String, Object, Error, isFinite });
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

const progress = loadQmlLibrary("components/notifications/progress.js");
const { percentOf, hasProgress, isRunning, tagOf, replacesIndex, NO_PROGRESS } = progress;

// -----------------------------------------------------------------------------
console.log("--- progress.js: a bar appears when, and only when, one is meant to ---");

check("no hints at all", percentOf(null), NO_PROGRESS);
check("hints with nothing in them", percentOf({}), NO_PROGRESS);
check("an ordinary notification, no value hint", percentOf({ urgency: 1 }), NO_PROGRESS);
check("zero is a real percentage, not an absence", percentOf({ value: 0 }), 0);
check("a percentage", percentOf({ value: 42 }), 42);
check("finished", percentOf({ value: 100 }), 100);

check("hasProgress agrees with percentOf", hasProgress({ value: 0 }), true);
check("hasProgress on an ordinary notification", hasProgress({ summary: "hi" }), false);
check("hasProgress with no hints", hasProgress(undefined), false);

// -----------------------------------------------------------------------------
console.log("--- progress.js: what an application sends is not what it promised ---");

// The hint is specified as a D-Bus int32. These are the ways it turns up anyway.
check("a whole number as a string", percentOf({ value: "42" }), 42);
check("a fraction is rounded, not truncated", percentOf({ value: 41.6 }), 42);
check("past the end is clamped, not dropped", percentOf({ value: 140 }), 100);
check("below zero is clamped", percentOf({ value: -5 }), 0);
check("a word", percentOf({ value: "nearly there" }), NO_PROGRESS);
check("an empty string", percentOf({ value: "" }), NO_PROGRESS);
check("null", percentOf({ value: null }), NO_PROGRESS);
check("undefined", percentOf({ value: undefined }), NO_PROGRESS);
check("a boolean is not a percentage", percentOf({ value: true }), NO_PROGRESS);
check("false is not zero here", percentOf({ value: false }), NO_PROGRESS);
check("an object", percentOf({ value: {} }), NO_PROGRESS);
check("an array", percentOf({ value: [50] }), NO_PROGRESS);
check("not a number", percentOf({ value: NaN }), NO_PROGRESS);
check("infinity", percentOf({ value: Infinity }), NO_PROGRESS);

// -----------------------------------------------------------------------------
console.log("--- progress.js: a running job's toast may not be taken off the screen ---");

check("mid-job", isRunning({ value: 42 }), true);
check("just started", isRunning({ value: 0 }), true);
check("one percent short", isRunning({ value: 99 }), true);
check("finished is finished", isRunning({ value: 100 }), false);
check("over-reported is still finished", isRunning({ value: 150 }), false);
check("an ordinary notification is not a job", isRunning({ summary: "hi" }), false);
check("no hints", isRunning(null), false);

// -----------------------------------------------------------------------------
console.log("--- progress.js: the replace-me-by-name hint ---");

const SYNC = "x-canonical-private-synchronous";

check("a tag", tagOf({ [SYNC]: "aq-ingest" }), "aq-ingest");
check("no tag", tagOf({ value: 10 }), "");
check("no hints", tagOf(null), "");
check("a number where a name belongs is not a name", tagOf({ [SYNC]: 7 }), "");
check("an object is not a name", tagOf({ [SYNC]: {} }), "");
check("an empty tag stays empty", tagOf({ [SYNC]: "" }), "");

console.log("--- progress.js: which toast an arriving one replaces ---");

check("the only one with that name", replacesIndex(["", "aq-ingest", ""], "aq-ingest"), 1);
check("the first one with that name", replacesIndex(["v", "v"], "v"), 0);
check("nothing up there matches", replacesIndex(["", "volume"], "aq-ingest"), -1);
check("nothing is up there at all", replacesIndex([], "aq-ingest"), -1);

// THIS IS THE ONE THAT MATTERS. If an untagged notification could match another
// untagged notification, every ordinary message on the machine would replace
// every other ordinary message, and the desktop would only ever show you the
// most recent thing that happened.
check("an untagged one replaces nothing", replacesIndex(["", "", ""], ""), -1);
check("an untagged one is not matched by a tagged one", replacesIndex(["", ""], "volume"), -1);

// =============================================================================
console.log("");
if (failures > 0) {
    console.log(`  ${failures} of ${checks} checks FAILED.`);
    process.exit(1);
}
console.log(`  OK   all ${checks} notification-progress checks passed (and these ones really ran).`);
