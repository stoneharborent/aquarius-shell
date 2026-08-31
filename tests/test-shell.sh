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
#   means the code is well-formed and internally consistent. It does not mean it
#   draws a bar.
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
    services/qmldir \
    services/FocusState.qml \
    components/notifications/NotificationLayer.qml \
    components/notifications/NotificationStore.qml \
    components/notifications/NotificationPanelWindow.qml \
    components/notifications/NotificationsPanel.qml \
    components/notifications/NotificationGroup.qml \
    components/notifications/NotificationRow.qml \
    components/notifications/ToastLayer.qml \
    components/notifications/Toast.qml \
    components/notifications/IconChip.qml \
    components/notifications/ActionButtons.qml \
    components/notifications/InlineReply.qml \
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
echo "=== 6b. every service singleton is listed in services/qmldir ==="
# ------------------------------------------------------------------------------
# Exactly the same rule as theme/qmldir, one directory over. services/ holds the
# shell's shared state — the things there is meant to be precisely one of. A
# singleton that is not declared here is not a singleton; it silently becomes a
# separate copy per importer, which for something like Focus means Quick Settings
# and the notification server disagreeing about whether you are to be disturbed.

for aq_service in services/*.qml; do
    aq_name="$(basename "${aq_service}" .qml)"

    if ! grep -q '^pragma Singleton' "${aq_service}"; then
        # Not every file in services/ has to be a singleton.
        continue
    fi

    if grep -q "^singleton ${aq_name} .*${aq_name}\.qml$" services/qmldir; then
        pass "services/qmldir declares ${aq_name}"
    else
        fail "services/${aq_name}.qml says 'pragma Singleton' but services/qmldir" \
             "does not declare it. Add:  singleton ${aq_name} 1.0 ${aq_name}.qml"
    fi
done

# ------------------------------------------------------------------------------
echo ""
echo "=== 6c. every Theme.<name> a component uses actually exists ==="
# ------------------------------------------------------------------------------
# The single most common way to break this shell is to type `Theme.fsTiny` for a
# token called `fsMicro`. QML does not fail at start-up for that — the binding
# quietly evaluates to undefined, and a piece of text renders at size 0, or a
# rectangle renders in the default white, somewhere nobody is looking.
#
# The same check runs for FocusState, for the same reason: it is the one piece of
# state two different components have to agree about.

if python3 - <<'PYTHON'
import pathlib
import re
import sys


def declared(path):
    """Every property, function and signal a QML file exposes by name."""
    text = pathlib.Path(path).read_text(encoding='utf-8')
    names = set()
    names.update(re.findall(r'(?:readonly\s+)?property\s+[\w<>]+\s+(\w+)', text))
    names.update(re.findall(r'property\s+alias\s+(\w+)', text))
    names.update(re.findall(r'function\s+(\w+)\s*\(', text))
    names.update(re.findall(r'signal\s+(\w+)', text))
    return names


def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


singletons = {
    'Theme': declared('theme/Theme.qml'),
    'FocusState': declared('services/FocusState.qml'),
}

bad = 0
for path in sorted(pathlib.Path('.').rglob('*.qml')):
    if '.git' in path.parts:
        continue
    if path.parts[0] in ('theme', 'services'):
        continue
    code = strip_comments(path.read_text(encoding='utf-8'))
    for singleton, names in singletons.items():
        for used in sorted(set(re.findall(singleton + r'\.(\w+)', code))):
            if used not in names:
                print("  FAIL %s uses %s.%s, which does not exist" % (path, singleton, used))
                bad += 1

if bad == 0:
    print("  OK   every Theme.* and FocusState.* reference resolves")

sys.exit(1 if bad else 0)
PYTHON
then
    :
else
    fail "a component refers to a token or a function that is not there (above)." \
         "Add it to theme/Theme.qml (and to BOTH palettes if it is a colour)," \
         "or fix the spelling."
fi

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
if [ "${aq_failures}" -ne 0 ]; then
    echo "::error::${aq_failures} check(s) failed."
    exit 1
fi
echo "All checks passed."
echo ""
echo "Remember what that does and does not mean: no QML engine has parsed any"
echo "of this, and no compositor has drawn it. The first real test is"
echo "./harness/run-nested.sh on a Linux machine."
