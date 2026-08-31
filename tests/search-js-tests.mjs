// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// The only code in this repository that actually RUNS before it reaches Linux
// =============================================================================
// Everything else here is QML, and QML needs a Qt engine, which does not exist
// on a Mac. But two files in components/search/ are not QML — fuzzy.js and
// calc.js are plain JavaScript, on purpose, precisely so that the two pieces of
// real LOGIC in the search palette can be executed and checked on the machine
// they are written on.
//
// So this file is not a bracket count or a grep. It loads those two libraries
// and asserts what they do.
//
// HOW IT LOADS THEM
//   A QML `.pragma library` file is ordinary JavaScript with one non-standard
//   line at the top. That line is stripped, the rest is evaluated in a fresh
//   node VM context, and the functions come out the other side. If the file ever
//   stops being plain JavaScript — if somebody reaches for a QML type inside it
//   — this harness stops working, which is exactly the alarm we want.
//
// Run it directly:   node tests/search-js-tests.mjs
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

    // Strip the QML-only pragma; everything else must be valid JavaScript.
    const stripped = source.replace(/^\s*\.pragma\s+library\s*$/m, "");

    const context = vm.createContext({ Math, Number, String, Object, Error, isFinite });
    vm.runInContext(stripped, context, { filename: relativePath });
    return context;
}

let failures = 0;
let checks = 0;

function check(description, actual, expected) {
    checks += 1;
    const same = Object.is(actual, expected);
    if (!same) {
        failures += 1;
        console.log(`  FAIL ${description}`);
        console.log(`       expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
    }
}

function checkTrue(description, actual) {
    check(description, actual === true, true);
}

// =============================================================================
console.log("");
console.log("--- fuzzy.js: the tiers are in the right order ---");
// =============================================================================
const fuzzy = loadQmlLibrary("components/search/fuzzy.js");
const score = (h, n) => fuzzy.score(h, n);

// The tiers, from the comment at the top of fuzzy.js. Each of these must land
// inside its own band and never inside a lower one.
checkTrue("an exact match scores 1000", score("Files", "files") === 1000);
checkTrue("a prefix match is in the 860-900 band",
    score("Kdenlive", "kd") >= 860 && score("Kdenlive", "kd") <= 900);
checkTrue("a word-start match is in the 760-800 band",
    score("GNOME Terminal", "term") >= 760 && score("GNOME Terminal", "term") <= 800);
checkTrue("an initials match is in the 710-750 band",
    score("Video Lan Client", "vlc") >= 710 && score("Video Lan Client", "vlc") <= 750);
checkTrue("a mid-word match is in the 610-650 band",
    score("Kdenlive", "enli") >= 610 && score("Kdenlive", "enli") <= 650);
checkTrue("a scattered match is at or below 500",
    score("Kate Document Editor", "kdt") <= 500);
check("something that does not match at all", score("Kdenlive", "zzz"), -1);

// The whole point of the tiers: the RIGHT app has to come first.
checkTrue("'kd' prefers Kdenlive over KDE Connect's description",
    score("Kdenlive", "kd") > score("Manage KDE Connect devices", "kd"));
checkTrue("'term' prefers Terminal over Wireshark's 'terminate'",
    score("Terminal", "term") > score("terminate a capture", "term"));
checkTrue("a shorter name outranks a longer one at the same tier",
    score("Files", "fil") > score("Files and Folders Manager", "fil"));
checkTrue("but never far enough to drop a tier",
    score("A Very Long Application Name Indeed", "a very")
        > score("Not the application you meant", "very"));

console.log("--- fuzzy.js: edges ---");
check("an empty query matches nothing", score("Files", ""), -1);
check("empty text matches nothing", score("", "files"), -1);
check("a null haystack is handled", score(null, "files"), -1);
check("an undefined query is handled", score("Files", undefined), -1);
checkTrue("case is ignored both ways", score("FILES", "files") === 1000);
checkTrue("surrounding spaces are ignored", score("  Files  ", "files") === 1000);

console.log("--- fuzzy.js: weighted fields ---");
const fields = [
    { text: "Kdenlive", weight: 1.0 },
    { text: "Video Editor", weight: 0.7 },
    { text: "org.kde.kdenlive", weight: 0.6 }
];
checkTrue("the best field wins", fuzzy.bestScore(fields, "kd") >= 860);
checkTrue("a weaker field still matches when it is the only one that can",
    fuzzy.bestScore(fields, "video editor") > 0);
// This is the property that lets a keyword you typed EXACTLY beat a name you
// only nearly typed — the reason the tiers are 1000-scale and the weights are
// fractions rather than the other way round.
checkTrue("a weighted exact match beats a full-weight scattered one",
    fuzzy.bestScore([{ text: "video editor", weight: 0.65 }], "video editor")
        > fuzzy.bestScore([{ text: "Kate Document Editor", weight: 1.0 }], "kdt"));
// But a weight is not a veto: initials on a full-weight name still win, which
// is why typing "vlc" finds the player and not a keyword that merely contains it.
checkTrue("a full-weight initials match beats a weighted exact one",
    fuzzy.bestScore([{ text: "Video Lan Client", weight: 1.0 }], "vlc")
        > fuzzy.bestScore([{ text: "vlc", weight: 0.65 }], "vlc"));
check("no fields at all", fuzzy.bestScore([], "kd"), -1);
check("a field with no text is skipped", fuzzy.bestScore([{ text: "", weight: 1 }], "kd"), -1);

// =============================================================================
console.log("");
console.log("--- calc.js: sums ---");
// =============================================================================
const calc = loadQmlLibrary("components/search/calc.js");
const text = (source) => {
    const result = calc.evaluate(source);
    return result.ok ? result.text : null;
};

check("the design's own example", text("24 * 60"), "1440");
check("addition", text("2+2"), "4");
check("subtraction", text("10 - 3"), "7");
check("division", text("7/2"), "3.5");
check("remainder", text("17 % 5"), "2");
check("power", text("2^10"), "1024");
check("power groups right to left", text("2^3^2"), "512");
check("brackets change the order", text("(2+3)*4"), "20");
check("multiplication before addition", text("2+3*4"), "14");
check("unary minus", text("-4 + 10"), "6");
check("a decimal without a leading zero", text(".5 * 4"), "2");
check("scientific notation", text("2e3 + 1"), "2001");
check("the typographic multiply sign", text("6 × 7"), "42");
check("the typographic divide sign", text("84 ÷ 2"), "42");

console.log("--- calc.js: constants and functions ---");
check("pi is available", text("pi * 2 / pi"), "2");
check("e is available", text("ln(e) + 1"), "2");
check("sqrt", text("sqrt(144)"), "12");
check("a function of a function", text("floor(sqrt(30))"), "5");
check("min takes many arguments", text("min(4, 2, 9)"), "2");
check("max takes many arguments", text("max(4, 2, 9)"), "9");
check("pow takes exactly two", text("pow(3, 4)"), "81");

console.log("--- calc.js: float noise is hidden ---");
check("0.1 + 0.2 does not show its tail", text("0.1 + 0.2"), "0.3");
check("a third is still a third", text("1/3"), "0.333333333333");

console.log("--- calc.js: when it must stay quiet ---");
// This is the safety-critical half. Everything here MUST return null, because
// each one is either not a calculation or is somebody typing something else.
check("a bare number is not a calculation", text("8"), null);
check("a bracketed number is not a calculation", text("(8)"), null);
check("an app name", text("kdenlive"), null);
check("two words", text("lock screen"), null);
check("an empty string", text(""), null);
check("only spaces", text("   "), null);
check("null", text(null), null);
check("a half-typed sum", text("2 +"), null);
check("an unclosed bracket", text("(2+3"), null);
check("a stray closing bracket", text("2+3)"), null);
check("an unknown function", text("frobnicate(2)"), null);
check("a function with no brackets", text("sqrt 4"), null);
check("a function with no arguments", text("sqrt()"), null);
check("the wrong number of arguments", text("pow(2)"), null);
check("division by zero is not a number to show", text("1/0"), null);
check("a name that is not a constant", text("x + 1"), null);
check("trailing rubbish after a valid sum", text("2+2 apples"), null);

console.log("--- calc.js: it cannot reach anything outside itself ---");
// These are the strings that would matter if this had been written with eval().
// They must all be refused as ordinary parse errors, not run.
check("a property lookup", text("Math.PI"), null);
check("a global", text("globalThis"), null);
check("a call on a global", text("process.exit(1)"), null);
check("a function literal", text("(function(){return 1})()"), null);
check("a semicolon separated pair", text("1; 2"), null);
check("an assignment", text("a = 1"), null);
check("a template literal", text("`x`"), null);
check("a string", text('"hello"'), null);
checkTrue("a very long expression is bounded, not run forever",
    calc.evaluate("1+".repeat(500) + "1").ok === false);
checkTrue("deep nesting is bounded",
    calc.evaluate("(".repeat(200) + "1" + ")".repeat(200)).ok === false);

// =============================================================================
console.log("");
if (failures > 0) {
    console.log(`  ${failures} of ${checks} checks FAILED.`);
    process.exit(1);
}
console.log(`  OK   all ${checks} search-logic checks passed (and these ones really ran).`);
