#!/usr/bin/env bash
# =============================================================================
# Every check on the Aquarius Shell that can run WITHOUT a Linux machine
# =============================================================================
# This repo is written on a Mac and runs on Linux. That gap is the whole reason
# this file exists: without it, code would travel from the Mac to the bench
# machine with literally nothing having looked at it.
#
# WHAT THIS CAN CHECK
#   * every QML file's brackets balance
#   * the shell's imports are the ones we mean, and nothing compositor-specific
#     has crept in (the standardised-protocols law, enforced instead of trusted)
#   * no component contains a raw colour — colour belongs to theme/ only
#   * Ice and Midnight declare exactly the same set of colour roles
#   * the logo drawn in QML still matches the logo in the SVG file
#   * the singletons are all listed in theme/qmldir
#   * nothing points at a path on somebody's laptop
#   * the SVG assets are well-formed XML
#   * the CI workflow is valid YAML
#   * the shell scripts pass shellcheck (if shellcheck is installed)
#   * the search palette's JavaScript stays plain JavaScript
#   * the IPC summoning contract says the same thing everywhere it is written
#
# WHAT THIS CAN ACTUALLY RUN (added with the Flow Search palette)
#   Section 12 is different in kind from everything above it. The search
#   palette's two pieces of real logic — the fuzzy matcher and the calculator —
#   are deliberately written as plain `.pragma library` JavaScript rather than
#   as QML, which means `node` can load and EXECUTE them on a Mac.
#   tests/search-js-tests.mjs does exactly that: ~70 assertions about what the
#   matcher ranks first and what the calculator refuses to evaluate. Those are
#   not structural checks. They are the first tests in this repository that run
#   the actual code.
#
# WHAT THIS CANNOT CHECK, AND WHY
#   Whether the QML is CORRECT. The tool for that is `qmllint`, which ships with
#   Qt and needs Qt installed to resolve imports — and beyond that, whether the
#   BAR WORKS needs a Wayland compositor. Neither exists on macOS. So: cheap
#   structural checks here, `qmllint` in CI on a Fedora container once this repo
#   has a remote (.github/workflows/lint.yml), and the real answer on the bench
#   via harness/run-nested.sh.
#
#   Be clear-eyed about the size of that gap. Passing every check in this file
#   means the code is well-formed and internally consistent, and that the search
#   palette's matching and arithmetic behave. It does not mean it draws a bar,
#   opens a palette, or takes a single keystroke.
#
# Run it by hand with:  ./tests/test-shell.sh
# =============================================================================

set -euo pipefail

# Work from the repo root no matter where this was started from.
AQ_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${AQ_REPO_ROOT}"

aq_failures=0

fail() {
    echo "  FAIL $1"
    shift
    for aq_line in "$@"; do echo "       $aq_line"; done
    aq_failures=$((aq_failures + 1))
}

pass() {
    echo "  OK   $1"
}

# ------------------------------------------------------------------------------
echo ""
echo "=== 1. every file the shell needs exists ==="
# ------------------------------------------------------------------------------
# QML fails at the moment a missing file is asked for, which for a Loader is when
# the user clicks — the worst possible time to find out.

for aq_file in \
    shell.qml \
    theme/qmldir \
    theme/Theme.qml \
    theme/Ice.qml \
    theme/Midnight.qml \
    components/bar/TopBar.qml \
    components/bar/BarItem.qml \
    components/bar/LogoMark.qml \
    components/bar/ActiveAppName.qml \
    components/bar/BarClock.qml \
    components/bar/StatusCluster.qml \
    components/search/FlowSearch.qml \
    components/search/SearchEngine.qml \
    components/search/SearchField.qml \
    components/search/ResultRow.qml \
    components/search/fuzzy.js \
    components/search/calc.js \
    docs/flow-search.md \
    tests/search-js-tests.mjs \
    assets/logo.svg \
    assets/logo-mono.svg \
    harness/run-nested.sh \
    LICENSE
do
    if [ -f "${aq_file}" ]; then
        pass "${aq_file}"
    else
        fail "${aq_file} is missing."
    fi
done

# ------------------------------------------------------------------------------
echo ""
echo "=== 2. the QML brackets balance ==="
# ------------------------------------------------------------------------------
# Not a substitute for qmllint — see the note at the top. It is a substitute for
# nothing at all, which is what we would otherwise have. It counts { } ( ) and
# [ ] after throwing away comments and the insides of strings, so a brace in a
# comment or in a message cannot confuse it.
#
# This checker is lifted from ../os-image/tests/test-aquarius-plasmoid.sh, on
# purpose: the two repos should fail the same way for the same mistake.

if python3 - . <<'PYTHON'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
bad = 0

def strip(text):
    """Remove comments and string contents, keeping everything else in place."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
        elif c == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                i += 1
            i += 2
        elif c in ('"', "'", '`'):
            quote = c
            i += 1
            while i < n and text[i] != quote:
                if text[i] == '\\':
                    i += 1
                i += 1
            i += 1
        else:
            out.append(c)
            i += 1
    return ''.join(out)

pairs = {'}': '{', ')': '(', ']': '['}
openers = set(pairs.values())

for path in sorted(root.rglob('*.qml')):
    if '.git' in path.parts:
        continue
    code = strip(path.read_text(encoding='utf-8'))
    stack = []
    problem = None
    for ch in code:
        if ch in openers:
            stack.append(ch)
        elif ch in pairs:
            if not stack or stack[-1] != pairs[ch]:
                problem = "an unexpected '%s'" % ch
                break
            stack.pop()
    if problem is None and stack:
        problem = "%d bracket(s) never closed" % len(stack)
    if problem:
        print("  FAIL %s: %s" % (path, problem))
        bad += 1
    else:
        print("  OK   %s" % path)

sys.exit(1 if bad else 0)
PYTHON
then
    : # every file balanced; the per-file OK lines were printed above
else
    fail "at least one QML file has unbalanced brackets (listed above)."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 3. the standardised-protocols law ==="
# ------------------------------------------------------------------------------
# This shell may only import the portable modules. Quickshell.Hyprland and
# Quickshell.I3 are real, useful modules — and importing either would tie the
# shell to one window manager, which is the single mistake the whole strategy
# exists to avoid. Catching it here is cheaper than catching it in two years.

if grep -rn --include='*.qml' -E '^\s*import\s+Quickshell\.(Hyprland|I3)' . > /dev/null 2>&1; then
    grep -rn --include='*.qml' -E '^\s*import\s+Quickshell\.(Hyprland|I3)' . || true
    fail "a QML file imports a compositor-specific Quickshell module." \
         "The shell must run on ANY compositor that speaks the standard" \
         "protocols. See README.md, 'The one architectural law'."
else
    pass "no compositor-specific imports"
fi

# The imports we DO expect, so a surprise new dependency is visible in review.
echo "  ---- imports actually used ----"
grep -rhn --include='*.qml' -E '^\s*import\s+' . \
    | sed -E 's/^[0-9]+:[[:space:]]*//' \
    | sort -u \
    | sed 's/^/       /'

# ------------------------------------------------------------------------------
echo ""
echo "=== 4. colour lives in theme/ and nowhere else ==="
# ------------------------------------------------------------------------------
# The rule from Theme.qml: no component may contain a colour value. The moment
# two components disagree about what "the quiet grey" is, the desktop stops
# looking designed and starts looking assembled.
#
# We look for hex colours outside theme/. "transparent" is allowed — it is the
# absence of a colour, not a choice of one.

if grep -rn --include='*.qml' -E '"#[0-9A-Fa-f]{3,8}"' components/ shell.qml > /dev/null 2>&1; then
    grep -rn --include='*.qml' -E '"#[0-9A-Fa-f]{3,8}"' components/ shell.qml || true
    fail "a component contains a raw colour value." \
         "Colour belongs in theme/Ice.qml and theme/Midnight.qml only." \
         "Add a role there, then use Theme.<role> here."
else
    pass "no raw colours outside theme/"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 5. Ice and Midnight agree on their roles ==="
# ------------------------------------------------------------------------------
# A role that exists in one palette and not the other is a crash waiting for the
# moment somebody switches theme — and it will happen on Royce's machine, not on
# the machine of whoever wrote it.

if python3 - <<'PYTHON'
import pathlib
import re
import sys

def roles(path):
    text = pathlib.Path(path).read_text(encoding='utf-8')
    # readonly property <type> <name>:
    found = re.findall(r'readonly\s+property\s+\w+\s+(\w+)\s*:', text)
    return set(found)

ice = roles('theme/Ice.qml')
midnight = roles('theme/Midnight.qml')

only_ice = sorted(ice - midnight)
only_mid = sorted(midnight - ice)

if only_ice or only_mid:
    for name in only_ice:
        print("  FAIL '%s' is in Ice but not in Midnight" % name)
    for name in only_mid:
        print("  FAIL '%s' is in Midnight but not in Ice" % name)
    sys.exit(1)

print("  OK   both palettes declare the same %d roles" % len(ice))
PYTHON
then
    :
else
    fail "Ice and Midnight declare different sets of roles (listed above)." \
         "Add the missing one(s) to the other palette in the same sitting."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 6. every theme singleton is listed in theme/qmldir ==="
# ------------------------------------------------------------------------------
# QML will not treat a file as a singleton on the strength of `pragma Singleton`
# alone — it also has to be named in qmldir. Forget that and the shell fails to
# start with "Ice is not a type", which is a confusing way to be told this.

for aq_name in Ice Midnight Theme; do
    if grep -q "^singleton ${aq_name} .*${aq_name}\.qml$" theme/qmldir; then
        pass "theme/qmldir declares ${aq_name}"
    else
        fail "theme/qmldir does not declare ${aq_name}." \
             "Add:  singleton ${aq_name} 1.0 ${aq_name}.qml"
    fi

    if grep -q '^pragma Singleton' "theme/${aq_name}.qml"; then
        pass "theme/${aq_name}.qml says 'pragma Singleton'"
    else
        fail "theme/${aq_name}.qml is listed as a singleton but does not say" \
             "'pragma Singleton' at the top. Both are required."
    fi
done

# ------------------------------------------------------------------------------
echo ""
echo "=== 7. the drawn logo still matches the logo file ==="
# ------------------------------------------------------------------------------
# LogoMark.qml re-draws the mark in QML rather than loading the SVG, because
# Qt's SVG renderer does not understand the file's `currentColor`. The price of
# that is two copies of the same artwork, so this check makes sure they have not
# drifted. If you change the logo, change the SVG first — this test then tells
# you to update LogoMark.qml.

aq_logo_ok=1
while IFS= read -r aq_path_data; do
    if ! grep -qF "${aq_path_data}" components/bar/LogoMark.qml; then
        fail "a path in assets/logo-mono.svg is not in LogoMark.qml:" \
             "  ${aq_path_data}" \
             "The drawn mark and the logo file have drifted apart."
        aq_logo_ok=0
    fi
done < <(python3 -c "
import re
svg = open('assets/logo-mono.svg', encoding='utf-8').read()
for match in re.findall(r'\bd=\"([^\"]+)\"', svg):
    print(match)
")

if [ "${aq_logo_ok}" -eq 1 ]; then
    pass "LogoMark.qml matches assets/logo-mono.svg"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 8. nothing points at somebody's laptop ==="
# ------------------------------------------------------------------------------
# A path like /Users/... in a shipped file means the shell works on one machine
# and nowhere else.
#
# This test file itself is excluded, for the obvious reason that it has to
# contain the patterns it is looking for.

if grep -rn --include='*.qml' --include='*.sh' --include='*.yml' \
        -E '(/Users/|/home/[a-z]|/private/tmp/|/var/folders/)' . \
        --exclude-dir=.git --exclude='test-shell.sh' > /dev/null 2>&1; then
    grep -rn --include='*.qml' --include='*.sh' --include='*.yml' \
        -E '(/Users/|/home/[a-z]|/private/tmp/|/var/folders/)' . \
        --exclude-dir=.git --exclude='test-shell.sh' || true
    fail "a file above contains an absolute path to somebody's own machine."
else
    pass "no machine-specific paths"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 9. the SVG assets are well-formed XML ==="
# ------------------------------------------------------------------------------
# A malformed SVG does not warn — it renders as nothing at all.

for aq_svg in assets/*.svg; do
    if python3 -c "import xml.etree.ElementTree as e,sys; e.parse(sys.argv[1])" "${aq_svg}" 2>/dev/null; then
        pass "${aq_svg}"
    else
        fail "${aq_svg} is not well-formed XML."
    fi
done

# ------------------------------------------------------------------------------
echo ""
echo "=== 10. the CI workflow is valid YAML ==="
# ------------------------------------------------------------------------------
# GitHub silently ignores a workflow it cannot parse, so a typo there means the
# checks quietly never run — which is worse than having no checks, because you
# think you have them.

if python3 -c "import yaml" 2>/dev/null; then
    for aq_yml in .github/workflows/*.yml; do
        if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "${aq_yml}" 2>/dev/null; then
            pass "${aq_yml}"
        else
            fail "${aq_yml} is not valid YAML."
        fi
    done
else
    echo "  SKIP python3 has no PyYAML installed; cannot parse-check the workflows."
    echo "       Install with: python3 -m pip install pyyaml"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 11. the shell scripts hold up ==="
# ------------------------------------------------------------------------------

for aq_sh in harness/run-nested.sh tests/test-shell.sh; do
    if bash -n "${aq_sh}" 2>/dev/null; then
        pass "${aq_sh} parses"
    else
        fail "${aq_sh} is not valid bash."
    fi
    if [ -x "${aq_sh}" ]; then
        pass "${aq_sh} is executable"
    else
        fail "${aq_sh} is not executable." \
             "Run:  chmod +x ${aq_sh}"
    fi
done

if command -v shellcheck > /dev/null 2>&1; then
    if shellcheck harness/run-nested.sh tests/test-shell.sh; then
        pass "shellcheck is happy"
    else
        fail "shellcheck found problems (listed above)."
    fi
else
    echo "  SKIP shellcheck is not installed; skipping the deeper script checks."
    echo "       Install with: brew install shellcheck"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 12. the search palette's logic actually runs ==="
# ------------------------------------------------------------------------------
# Everything above this line inspects text. This runs code.
#
# components/search/fuzzy.js and components/search/calc.js are plain JavaScript
# with one QML pragma at the top, which means node can execute them on a Mac.
# tests/search-js-tests.mjs asserts what the matcher puts first and — the part
# that matters most — every string the calculator must REFUSE, since it is fed
# whatever a person types into a box holding the whole desktop's keyboard.

if command -v node > /dev/null 2>&1; then
    if node tests/search-js-tests.mjs; then
        pass "the search matcher and calculator behave"
    else
        fail "the search logic tests failed (listed above)."
    fi
else
    echo "  SKIP node is not installed; the search logic tests cannot run."
    echo "       This is the only test in this repo that executes real code —"
    echo "       install node and run it before trusting a change to fuzzy.js"
    echo "       or calc.js."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 13. the search JavaScript stays plain JavaScript ==="
# ------------------------------------------------------------------------------
# The two .js libraries are testable ONLY because they are pure functions with
# no QML in them. The moment one reaches for Theme, Quickshell or qsTr, node can
# no longer load it and section 12 quietly stops testing anything real. This
# check is what stops that from happening silently.

aq_js_ok=1
for aq_js in components/search/fuzzy.js components/search/calc.js; do
    if ! grep -q '^\.pragma library' "${aq_js}"; then
        fail "${aq_js} is missing its '.pragma library' line." \
             "Without it QML gives every importer its own copy, and the" \
             "node test harness refuses to load it."
        aq_js_ok=0
    fi
    # Comments are blanked first — these files EXPLAIN why they must not touch
    # Quickshell, and a check that fails on its own rationale is a bad check.
    # (Line comments only; neither file uses /* */ and neither should start.)
    if sed -E 's,//.*,,' "${aq_js}" \
        | grep -nE '(^|[^A-Za-z_.])(Theme|Quickshell|qsTr|Qt)[.(]' > /dev/null 2>&1; then
        sed -E 's,//.*,,' "${aq_js}" \
            | grep -nE '(^|[^A-Za-z_.])(Theme|Quickshell|qsTr|Qt)[.(]' \
            | sed "s,^,       ${aq_js}:," || true
        fail "${aq_js} reaches into QML." \
             "These files must stay pure JavaScript so they can be executed" \
             "and tested on a Mac. Move the QML part into a .qml file."
        aq_js_ok=0
    fi
done

if [ "${aq_js_ok}" -eq 1 ]; then
    pass "fuzzy.js and calc.js are pure, testable JavaScript"
fi

# The brackets in the JavaScript, for the case where node is not installed and
# section 12 skipped. Same idea as section 2, same reason.
if python3 - components/search <<'PYTHON'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
bad = 0

pairs = {'}': '{', ')': '(', ']': '['}
openers = set(pairs.values())

for path in sorted(root.rglob('*.js')):
    text = path.read_text(encoding='utf-8')
    out = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
        elif c == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                i += 1
            i += 2
        elif c in ('"', "'", '`'):
            quote = c
            i += 1
            while i < n and text[i] != quote:
                if text[i] == '\\':
                    i += 1
                i += 1
            i += 1
        else:
            out.append(c)
            i += 1
    stack = []
    problem = None
    for ch in ''.join(out):
        if ch in openers:
            stack.append(ch)
        elif ch in pairs:
            if not stack or stack[-1] != pairs[ch]:
                problem = "an unexpected '%s'" % ch
                break
            stack.pop()
    if problem is None and stack:
        problem = "%d bracket(s) never closed" % len(stack)
    if problem:
        print("  FAIL %s: %s" % (path, problem))
        bad += 1
    else:
        print("  OK   %s" % path)

sys.exit(1 if bad else 0)
PYTHON
then
    :
else
    fail "at least one search JavaScript file has unbalanced brackets."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 14. the search palette can actually be summoned ==="
# ------------------------------------------------------------------------------
# A layer-shell client cannot bind a global key; the compositor does, and it
# reaches the shell through Quickshell's IPC. That makes the exact command
# string a CONTRACT between this repo and whoever writes the compositor config —
# and a contract written down in three places drifts unless something checks it.
#
# The pieces: the handler's target must be `search`, it must expose toggle/open/
# close, and the one command line must be spelled identically in the component,
# in shell.qml and in the documentation.

aq_ipc_call='qs ipc -c aquarius-shell call search toggle'

if grep -q 'target: "search"' components/search/FlowSearch.qml; then
    pass "the IPC handler's target is 'search'"
else
    fail "components/search/FlowSearch.qml no longer registers target \"search\"." \
         "The compositor keybind calls that name. Changing it silently breaks" \
         "the only way the palette can be opened from the keyboard."
fi

for aq_fn in toggle open close; do
    if grep -qE "function ${aq_fn}\(\):" components/search/FlowSearch.qml; then
        pass "the IPC handler exposes ${aq_fn}()"
    else
        fail "components/search/FlowSearch.qml no longer exposes ${aq_fn}()." \
             "Quickshell only registers handler functions whose argument and" \
             "return types are written out, so check the signature too."
    fi
done

for aq_doc in components/search/FlowSearch.qml shell.qml docs/flow-search.md; do
    if grep -qF "${aq_ipc_call}" "${aq_doc}"; then
        pass "${aq_doc} spells the summoning command the same way"
    else
        fail "${aq_doc} does not contain the exact summoning command:" \
             "  ${aq_ipc_call}" \
             "All three must agree, or somebody will bind a key to a line that" \
             "does nothing and spend an afternoon finding out why."
    fi
done

# The law again, from the other direction. Quickshell DOES ship a GlobalShortcut
# type — in Quickshell.Hyprland. Section 3 already fails on that import; this
# says out loud why the search palette does not use the obvious thing.
# Comments are blanked first, for the same reason as section 13: FlowSearch.qml
# has a long comment about why it does NOT use GlobalShortcut, and a check that
# fails on its own explanation would teach people to delete the explanation.
aq_shortcut_ok=1
while IFS= read -r aq_qml; do
    if sed -E 's,//.*,,' "${aq_qml}" | grep -n 'GlobalShortcut' > /dev/null 2>&1; then
        sed -E 's,//.*,,' "${aq_qml}" | grep -n 'GlobalShortcut' \
            | sed "s,^,       ${aq_qml}:," || true
        aq_shortcut_ok=0
    fi
done < <(find components shell.qml -name '*.qml')

if [ "${aq_shortcut_ok}" -eq 1 ]; then
    pass "no GlobalShortcut — summoning stays compositor-agnostic"
else
    fail "something uses GlobalShortcut." \
         "The only GlobalShortcut in Quickshell 0.3.1 is Hyprland's, and it" \
         "speaks a Hyprland-only protocol. Summoning goes through IpcHandler." \
         "See the note at the top of components/search/FlowSearch.qml."
fi

# ------------------------------------------------------------------------------
echo ""
if [ "${aq_failures}" -ne 0 ]; then
    echo "::error::${aq_failures} check(s) failed."
    exit 1
fi
echo "All checks passed."
echo ""
echo "Remember what that does and does not mean: no QML engine has parsed any"
echo "of this, and no compositor has drawn it. The first real test is"
echo "./harness/run-nested.sh on a Linux machine."
