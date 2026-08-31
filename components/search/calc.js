// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// calc.js — the inline calculator behind the Flow Search box
// =============================================================================
// You type "24 * 60" and the palette offers "1440". That is all this file does.
//
// WHY IT IS WRITTEN OUT LONGHAND INSTEAD OF CALLING eval()
//   `eval("24 * 60")` would be four characters of work and a genuinely bad idea.
//   The string being evaluated is whatever a person typed into a box that has
//   the whole desktop's keyboard focus, and `eval` would happily run
//   `Quickshell.reload()`, or a loop that never ends, or anything else in scope.
//   Nothing about "it is only my own machine" makes that acceptable in a shell.
//
//   So the expression is TOKENISED and PARSED by hand. The parser understands
//   numbers, five operators, brackets, and a fixed list of function and constant
//   names. Any name not on that list is an error, not a lookup. There is no path
//   from this file to anything outside it — the only things it can reach are
//   `Math` functions named in FUNCTIONS below.
//
// WHAT IT UNDERSTANDS
//   numbers      12   3.5   1e6   .5
//   operators    +  -  *  /  %  ^      and the typographic  ×  ÷
//   brackets     ( )
//   constants    pi   tau   e
//   functions    sqrt cbrt abs round floor ceil exp ln log log2 log10
//                sin cos tan asin acos atan
//                min(a, b, ...)  max(a, b, ...)  pow(a, b)
//
//   `^` is power and binds right-to-left, so 2^3^2 is 512, not 64.
//   `%` is remainder, NOT percent-of. "50% of 80" is a future provider, not
//   this one, and the docs say so rather than half-implementing it.
//
// WHEN IT STAYS QUIET
//   `evaluate` returns ok:false unless the whole string parses AND the
//   expression actually DID something — at least one binary operator or one
//   function call. Typing "8" gets you your app results, not a row telling you
//   that 8 is 8. Typing "kd" is not a calculation and never becomes one.
//
// Like fuzzy.js this is `.pragma library`: plain JavaScript, no QML, no state,
// and therefore runnable by node on a Mac. tests/search-js-tests.mjs does.
// =============================================================================
.pragma library

// Hard stops. A search box is fed keystrokes, so both the token count and the
// bracket depth are bounded to keep a pathological string from costing anything.
var MAX_TOKENS = 256;
var MAX_DEPTH = 32;

var CONSTANTS = {
    "pi": Math.PI,
    "tau": Math.PI * 2,
    "e": Math.E
};

// arity -1 means "one or more arguments".
var FUNCTIONS = {
    "sqrt":  { arity: 1,  apply: function (a) { return Math.sqrt(a[0]); } },
    "cbrt":  { arity: 1,  apply: function (a) { return Math.cbrt(a[0]); } },
    "abs":   { arity: 1,  apply: function (a) { return Math.abs(a[0]); } },
    "round": { arity: 1,  apply: function (a) { return Math.round(a[0]); } },
    "floor": { arity: 1,  apply: function (a) { return Math.floor(a[0]); } },
    "ceil":  { arity: 1,  apply: function (a) { return Math.ceil(a[0]); } },
    "exp":   { arity: 1,  apply: function (a) { return Math.exp(a[0]); } },
    "ln":    { arity: 1,  apply: function (a) { return Math.log(a[0]); } },
    "log":   { arity: 1,  apply: function (a) { return Math.log10(a[0]); } },
    "log2":  { arity: 1,  apply: function (a) { return Math.log2(a[0]); } },
    "log10": { arity: 1,  apply: function (a) { return Math.log10(a[0]); } },
    "sin":   { arity: 1,  apply: function (a) { return Math.sin(a[0]); } },
    "cos":   { arity: 1,  apply: function (a) { return Math.cos(a[0]); } },
    "tan":   { arity: 1,  apply: function (a) { return Math.tan(a[0]); } },
    "asin":  { arity: 1,  apply: function (a) { return Math.asin(a[0]); } },
    "acos":  { arity: 1,  apply: function (a) { return Math.acos(a[0]); } },
    "atan":  { arity: 1,  apply: function (a) { return Math.atan(a[0]); } },
    "pow":   { arity: 2,  apply: function (a) { return Math.pow(a[0], a[1]); } },
    "min":   { arity: -1, apply: function (a) { return Math.min.apply(null, a); } },
    "max":   { arity: -1, apply: function (a) { return Math.max.apply(null, a); } }
};

// precedence, and whether it groups right-to-left
var BINARY = {
    "+": { precedence: 1, rightAssociative: false },
    "-": { precedence: 1, rightAssociative: false },
    "*": { precedence: 2, rightAssociative: false },
    "/": { precedence: 2, rightAssociative: false },
    "%": { precedence: 2, rightAssociative: false },
    "^": { precedence: 3, rightAssociative: true }
};

function isDigit(ch) {
    return ch >= "0" && ch <= "9";
}

function isLetter(ch) {
    return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z");
}

// ---------------------------------------------------------------------------
// Step 1 — turn the string into a flat list of tokens, or throw.
// ---------------------------------------------------------------------------
function tokenize(source) {
    var tokens = [];
    var i = 0;

    while (i < source.length) {
        var ch = source.charAt(i);

        if (ch === " " || ch === "\t") {
            i++;
            continue;
        }

        if (isDigit(ch) || (ch === "." && isDigit(source.charAt(i + 1)))) {
            var start = i;
            while (i < source.length && isDigit(source.charAt(i)))
                i++;
            if (source.charAt(i) === ".") {
                i++;
                while (i < source.length && isDigit(source.charAt(i)))
                    i++;
            }
            // An exponent, but only when it really is one: "1e6" and "1e-6" are
            // numbers, while "1e" is the number 1 followed by the constant e.
            var maybeExponent = source.charAt(i);
            if (maybeExponent === "e" || maybeExponent === "E") {
                var after = source.charAt(i + 1);
                var afterSign = source.charAt(i + 2);
                if (isDigit(after) || ((after === "+" || after === "-") && isDigit(afterSign))) {
                    i += 2;
                    while (i < source.length && isDigit(source.charAt(i)))
                        i++;
                }
            }
            tokens.push({ type: "number", value: parseFloat(source.slice(start, i)) });
            continue;
        }

        if (isLetter(ch)) {
            var nameStart = i;
            while (i < source.length && isLetter(source.charAt(i)))
                i++;
            tokens.push({ type: "name", value: source.slice(nameStart, i).toLowerCase() });
            continue;
        }

        // The typographic multiply and divide signs, so a value pasted out of a
        // document works the way it looks.
        if (ch === "×") { tokens.push({ type: "op", value: "*" }); i++; continue; }
        if (ch === "÷") { tokens.push({ type: "op", value: "/" }); i++; continue; }

        if ("+-*/%^".indexOf(ch) !== -1) { tokens.push({ type: "op", value: ch }); i++; continue; }
        if (ch === "(") { tokens.push({ type: "open" }); i++; continue; }
        if (ch === ")") { tokens.push({ type: "close" }); i++; continue; }
        if (ch === ",") { tokens.push({ type: "comma" }); i++; continue; }

        throw new Error("unexpected character");
    }

    return tokens;
}

// ---------------------------------------------------------------------------
// Step 2 — parse and evaluate in one pass (precedence climbing).
// `state` carries the token list, the read position, the bracket depth, and
// `didWork`, which is how we know the string was a CALCULATION and not just a
// number somebody typed.
// ---------------------------------------------------------------------------
function peek(state) {
    return state.index < state.tokens.length ? state.tokens[state.index] : null;
}

function parsePrimary(state) {
    var token = peek(state);
    if (!token)
        throw new Error("expression ended early");

    if (token.type === "op" && (token.value === "-" || token.value === "+")) {
        state.index++;
        var operand = parsePrimary(state);
        return token.value === "-" ? -operand : operand;
    }

    if (token.type === "number") {
        state.index++;
        return token.value;
    }

    if (token.type === "open") {
        state.index++;
        state.depth++;
        if (state.depth > MAX_DEPTH)
            throw new Error("too deeply nested");
        var inner = parseExpression(state, 1);
        if (!peek(state) || peek(state).type !== "close")
            throw new Error("missing closing bracket");
        state.index++;
        state.depth--;
        return inner;
    }

    if (token.type === "name") {
        var name = token.value;

        if (Object.prototype.hasOwnProperty.call(CONSTANTS, name)) {
            state.index++;
            return CONSTANTS[name];
        }

        if (Object.prototype.hasOwnProperty.call(FUNCTIONS, name)) {
            var fn = FUNCTIONS[name];
            state.index++;
            if (!peek(state) || peek(state).type !== "open")
                throw new Error("function without brackets");
            state.index++;
            state.depth++;
            if (state.depth > MAX_DEPTH)
                throw new Error("too deeply nested");

            var args = [];
            if (peek(state) && peek(state).type === "close") {
                throw new Error("function without arguments");
            }
            for (;;) {
                args.push(parseExpression(state, 1));
                var next = peek(state);
                if (next && next.type === "comma") {
                    state.index++;
                    continue;
                }
                break;
            }
            if (!peek(state) || peek(state).type !== "close")
                throw new Error("missing closing bracket");
            state.index++;
            state.depth--;

            if (fn.arity !== -1 && args.length !== fn.arity)
                throw new Error("wrong number of arguments");

            state.didWork = true;
            return fn.apply(args);
        }

        // Any other word is not a number and never becomes one. This is the
        // line that stops "kdenlive" from being treated as arithmetic.
        throw new Error("unknown name");
    }

    throw new Error("unexpected token");
}

function applyBinary(operator, left, right) {
    switch (operator) {
    case "+": return left + right;
    case "-": return left - right;
    case "*": return left * right;
    case "/": return left / right;
    case "%": return left % right;
    case "^": return Math.pow(left, right);
    }
    throw new Error("unknown operator");
}

function parseExpression(state, minimumPrecedence) {
    var left = parsePrimary(state);

    for (;;) {
        var token = peek(state);
        if (!token || token.type !== "op")
            break;
        var rule = BINARY[token.value];
        if (!rule || rule.precedence < minimumPrecedence)
            break;

        state.index++;
        var nextMinimum = rule.rightAssociative ? rule.precedence : rule.precedence + 1;
        var right = parseExpression(state, nextMinimum);
        left = applyBinary(token.value, left, right);
        state.didWork = true;
    }

    return left;
}

// ---------------------------------------------------------------------------
// Step 3 — print the answer the way a person would write it.
// ---------------------------------------------------------------------------
// Binary floating point says 0.1 + 0.2 is 0.30000000000000004. Nobody wants to
// read that in a search box, and nobody is doing accountancy in one either, so
// the answer is rounded to 12 significant figures — which hides the noise and
// keeps every number a person will actually type exact.
function format(value) {
    if (value === 0)
        return "0";

    var magnitude = Math.abs(value);
    if (magnitude >= 1e15 || magnitude < 1e-6)
        return String(Number(value.toExponential(8)));

    return String(Number(value.toPrecision(12)));
}

// ---------------------------------------------------------------------------
// The only function anything outside this file calls.
// ---------------------------------------------------------------------------
// Returns { ok, value, text, expression }. When ok is false the other fields
// are meaningless and the palette shows no calculator row at all.
function evaluate(source) {
    var result = { ok: false, value: 0, text: "", expression: "" };

    if (source === null || source === undefined)
        return result;

    var trimmed = String(source).trim();
    if (trimmed.length === 0)
        return result;

    try {
        var tokens = tokenize(trimmed);
        if (tokens.length === 0 || tokens.length > MAX_TOKENS)
            return result;

        var state = { tokens: tokens, index: 0, depth: 0, didWork: false };
        var value = parseExpression(state, 1);

        // Trailing rubbish means we did not understand the whole thing, and
        // half-understanding a sum is worse than not offering one.
        if (state.index !== tokens.length)
            return result;

        if (!state.didWork)
            return result;

        if (typeof value !== "number" || !isFinite(value))
            return result;

        result.ok = true;
        result.value = value;
        result.text = format(value);
        result.expression = trimmed;
        return result;
    } catch (error) {
        return result;
    }
}
