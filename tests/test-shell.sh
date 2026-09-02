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
#   * every capitalised `Name.something` is a name somebody probed on the
#     Quickshell build AquariusOS actually ships (section 28 — the one that
#     catches a module that IS installed and spells a name differently)
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
    components/bar/TrayItem.qml \
    services/qmldir \
    services/FocusState.qml \
    services/Overlays.qml \
    components/quicksettings/QuickSettingsPanel.qml \
    components/quicksettings/QuickSettingsPopup.qml \
    components/quicksettings/QsTile.qml \
    components/quicksettings/QsTileSlot.qml \
    components/quicksettings/QsSlider.qml \
    components/quicksettings/QsGlyph.qml \
    components/quicksettings/QsBatteryGlyph.qml \
    components/quicksettings/QsPlatform.qml \
    components/quicksettings/TileWifi.qml \
    components/quicksettings/TileBluetooth.qml \
    components/quicksettings/TileFocus.qml \
    components/quicksettings/TilePowerProfile.qml \
    components/quicksettings/TileGameMode.qml \
    components/quicksettings/SliderVolume.qml \
    components/quicksettings/SliderBrightness.qml \
    components/quicksettings/BatteryLine.qml \
    components/quicksettings/StatusGlyphNetwork.qml \
    components/quicksettings/StatusGlyphSound.qml \
    components/quicksettings/StatusGlyphBattery.qml \
    components/search/FlowSearch.qml \
    components/search/SearchEngine.qml \
    components/search/SearchField.qml \
    components/search/ResultRow.qml \
    components/search/fuzzy.js \
    components/search/calc.js \
    docs/flow-search.md \
    tests/search-js-tests.mjs \
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

if grep -rn --include='*.qml' -E '"#[0-9A-Fa-f]{3,8}"' components/ services/ shell.qml > /dev/null 2>&1; then
    grep -rn --include='*.qml' -E '"#[0-9A-Fa-f]{3,8}"' components/ services/ shell.qml || true
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
# The same check runs for FocusState and Overlays, for the same reason: they are
# the pieces of state that several different components have to agree about.

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
    'Overlays': declared('services/Overlays.qml'),
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

# ==============================================================================
# THE SESSION (session/) — checks 12 to 17
# ==============================================================================
# Everything below is about session/: the files that let a Linux box log INTO
# the Aquarius Shell rather than run it in a window. It is appended rather than
# folded into the checks above so that the original checks keep working exactly
# as they did.
#
# The same honesty applies here as everywhere: these confirm the files exist,
# parse, and obey the project's rules. They cannot confirm that a compositor
# starts, that a portal answers, or that the login screen shows the session.
# Only docs/session.md's bench walkthrough can do that.

# ------------------------------------------------------------------------------
echo ""
echo "=== 12. every file the session needs exists ==="
# ------------------------------------------------------------------------------
# A session that is missing one file does not half-start. It gives you a black
# screen and sends you back to the login prompt with no explanation, which is
# the least debuggable failure in this whole project.

for aq_file in \
    session/README.md \
    session/aquarius-session \
    session/aquarius.desktop \
    session/install-session.sh \
    session/niri/config.kdl \
    session/labwc/rc.xml \
    session/labwc/autostart \
    session/labwc/shutdown \
    session/labwc/environment \
    session/portals/aquarius-niri-portals.conf \
    session/portals/aquarius-labwc-portals.conf \
    services/SystemAppearance.qml \
    docs/session.md
do
    if [ -f "${aq_file}" ]; then
        pass "${aq_file}"
    else
        fail "${aq_file} is missing."
    fi
done

# ------------------------------------------------------------------------------
echo ""
echo "=== 13. the session's structured files parse ==="
# ------------------------------------------------------------------------------
# The labwc configuration is XML and the portal configurations are INI. Both
# fail SILENTLY when malformed — labwc falls back to its defaults, and
# xdg-desktop-portal simply picks a different back end — so a typo in either
# shows up as "screen recording does nothing" rather than as an error.

if python3 -c "import xml.etree.ElementTree as e,sys; e.parse(sys.argv[1])" \
        session/labwc/rc.xml 2>/dev/null; then
    pass "session/labwc/rc.xml is well-formed XML"
else
    fail "session/labwc/rc.xml is not well-formed XML."
fi

if python3 - <<'PYTHON'
import configparser
import pathlib
import sys

bad = 0
for path in sorted(pathlib.Path('session/portals').glob('*-portals.conf')):
    parser = configparser.ConfigParser()
    # Portal keys are case-sensitive interface names like
    # org.freedesktop.impl.portal.ScreenCast. configparser lower-cases keys by
    # default, which would make this check pass on a file the portal cannot use.
    parser.optionxform = str
    try:
        parser.read_string(path.read_text(encoding='utf-8'))
    except Exception as exc:
        print("  FAIL %s: %s" % (path, exc))
        bad += 1
        continue

    if not parser.has_section('preferred'):
        print("  FAIL %s: no [preferred] section" % path)
        bad += 1
        continue

    if not parser.has_option('preferred', 'default'):
        print("  FAIL %s: [preferred] has no 'default' key" % path)
        bad += 1
        continue

    print("  OK   %s ([preferred] default=%s)"
          % (path, parser.get('preferred', 'default')))

sys.exit(1 if bad else 0)
PYTHON
then
    :
else
    fail "a portal configuration is malformed (listed above)."
fi

# The .desktop entry is also INI, and needs three specific keys or the login
# screen ignores it without comment.
if python3 - <<'PYTHON'
import configparser
import sys

parser = configparser.ConfigParser()
parser.optionxform = str
parser.read('session/aquarius.desktop', encoding='utf-8')

if not parser.has_section('Desktop Entry'):
    print("  FAIL session/aquarius.desktop: no [Desktop Entry] section")
    sys.exit(1)

missing = [k for k in ('Name', 'Exec', 'Type')
           if not parser.has_option('Desktop Entry', k)]
if missing:
    print("  FAIL session/aquarius.desktop: missing %s" % ", ".join(missing))
    sys.exit(1)

print("  OK   session/aquarius.desktop (%s -> %s)"
      % (parser.get('Desktop Entry', 'Name'),
         parser.get('Desktop Entry', 'Exec')))
PYTHON
then
    :
else
    fail "session/aquarius.desktop is not a usable desktop entry (above)."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 14. the niri configuration's braces balance ==="
# ------------------------------------------------------------------------------
# The niri config is KDL, and the real checker for it is `niri validate`, which
# needs niri and therefore Linux. This is the same trick as check 2: strip the
# comments and strings, then count the braces. It catches the one mistake that
# is easy to make and impossible to see.

if python3 - <<'PYTHON'
import pathlib
import re
import sys

text = pathlib.Path('session/niri/config.kdl').read_text(encoding='utf-8')

# KDL raw strings look like r#"...."#, and can contain anything including
# braces and quote marks. Remove them first, then ordinary strings, then
# comments — in that order, so a // inside a string is not mistaken for one.
text = re.sub(r'r#+"(?:.|\n)*?"#+', '""', text)
text = re.sub(r'"(?:[^"\\]|\\.)*"', '""', text)
text = re.sub(r'/\*(?:.|\n)*?\*/', '', text)
text = re.sub(r'//[^\n]*', '', text)

depth = 0
problem = None
for char in text:
    if char == '{':
        depth += 1
    elif char == '}':
        depth -= 1
        if depth < 0:
            problem = "an unexpected '}'"
            break

if problem is None and depth != 0:
    problem = "%d brace(s) never closed" % depth

if problem:
    print("  FAIL session/niri/config.kdl: %s" % problem)
    sys.exit(1)

print("  OK   session/niri/config.kdl")
PYTHON
then
    :
else
    fail "session/niri/config.kdl has unbalanced braces (listed above)." \
         "The real check is 'niri validate -c session/niri/config.kdl'," \
         "which needs a Linux machine with niri installed."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 15. the colour rule reaches the session files too ==="
# ------------------------------------------------------------------------------
# Check 4 keeps hex colours out of components/. The same rule applies to the
# compositor configurations, and the temptation there is stronger: both niri and
# labwc will happily take an Aquarius blue for their focus ring, and the moment
# one of them has it, "the Aquarius blue" lives in two places and starts to
# drift. The compositors' own chrome stays at their own defaults until the shell
# owns it.

if grep -rn -E '#[0-9A-Fa-f]{3,8}\b' \
        session/niri session/labwc session/portals > /dev/null 2>&1; then
    grep -rn -E '#[0-9A-Fa-f]{3,8}\b' \
        session/niri session/labwc session/portals || true
    fail "a session configuration contains what looks like a hex colour." \
         "Colour belongs in theme/Ice.qml and theme/Midnight.qml only." \
         "Leave the compositor's own chrome at the compositor's defaults."
else
    pass "no colours in the compositor or portal configurations"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 16. no machine-specific paths in the session files ==="
# ------------------------------------------------------------------------------
# Check 8 does this for .qml, .sh and .yml. The session adds four more file
# types, and they are exactly the ones where a stray path does the most damage:
# a compositor config naming somebody's home directory works on one laptop.
#
# The design that avoids it: no session config names the shell's location at
# all. They start it with a bare `qs`, and QS_CONFIG_PATH does the rest.

if grep -rn -E '(/Users/|/home/[a-z]|/private/tmp/|/var/folders/)' \
        session/niri session/labwc session/portals session/aquarius.desktop \
        > /dev/null 2>&1; then
    grep -rn -E '(/Users/|/home/[a-z]|/private/tmp/|/var/folders/)' \
        session/niri session/labwc session/portals session/aquarius.desktop || true
    fail "a session file contains an absolute path to somebody's machine."
else
    pass "no machine-specific paths in the session configurations"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 17. the session scripts hold up ==="
# ------------------------------------------------------------------------------
# aquarius-session has no .sh on the end, because it is a command a person
# types and the login screen runs — but it is still bash, and shellcheck reads
# the shebang.

for aq_sh in session/aquarius-session session/install-session.sh; do
    if bash -n "${aq_sh}" 2>/dev/null; then
        pass "${aq_sh} parses"
    else
        fail "${aq_sh} is not valid bash."
    fi
    if [ -x "${aq_sh}" ]; then
        pass "${aq_sh} is executable"
    else
        fail "${aq_sh} is not executable." \
             "The login screen cannot run a file it is not allowed to run." \
             "Run:  chmod +x ${aq_sh}"
    fi
done

if command -v shellcheck > /dev/null 2>&1; then
    if shellcheck session/aquarius-session session/install-session.sh; then
        pass "shellcheck is happy with the session scripts"
    else
        fail "shellcheck found problems in the session scripts (above)."
    fi
else
    echo "  SKIP shellcheck is not installed; skipping the session scripts."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 18. the dock's files exist ==="
# ------------------------------------------------------------------------------
# Same reasoning as check 1, for the second real piece of the shell. Kept as its
# own block rather than added to check 1's list so that the dock, the panels and
# the search box can each grow their own checks without three branches all
# editing the same twenty lines.

for aq_file in \
    components/dock/Dock.qml \
    components/dock/DockItem.qml \
    components/dock/DockAddTile.qml \
    components/dock/DockModel.qml \
    components/dock/DockConfig.qml \
    docs/dock.md
do
    if [ -f "${aq_file}" ]; then
        pass "${aq_file}"
    else
        fail "${aq_file} is missing."
    fi
done


# ------------------------------------------------------------------------------
echo ""
echo "=== 19. no Plasma or KDE leftovers ==="
# ------------------------------------------------------------------------------
# The dock is a re-write of AquariusOS's KDE dock widget, which was itself a
# fork of KDE's task manager. Porting from Plasma QML means Kirigami,
# PlasmaComponents, PlasmaCore, `Plasmoid.` and `plasma.applet.*` are all one
# careless paste away — and every one of them would tie this shell to Plasma,
# which is the exact dependency the whole track exists to avoid. None of them
# exist outside Plasma, so the shell would simply fail to start.
#
# (os-image's own build_files/dock-check.sh guards the KDE dock against the
# mirror-image mistake. This is the same idea pointed the other way.)

# Comment lines are exempt: a comment SAYING "Kirigami.Icon did X and here is
# the portable answer" is exactly the provenance note we want ported files to
# carry, and it ties nothing to Plasma.
plasma_hits="$(grep -rn --include='*.qml' \
        -E '(^|[^A-Za-z0-9_.])(Kirigami|PlasmaComponents[0-9]*|PlasmaCore|Plasmoid|TaskManagerApplet)\.|import +org\.kde\.|plasma\.applet\.' \
        . --exclude-dir=.git 2>/dev/null | grep -Ev '^[^:]+:[0-9]+:[[:space:]]*//' || true)"
if [ -n "$plasma_hits" ]; then
    printf '%s\n' "$plasma_hits"
    fail "a QML file uses a Plasma-only type or import." \
         "This shell runs on any compositor and does not have Plasma." \
         "Whatever it was doing has a portable Quickshell or QtQuick answer."
else
    pass "no Plasma or KDE types"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 20. every glyph name asked for actually exists ==="
# ------------------------------------------------------------------------------
# QsGlyph draws its icons from a table of SVG path data keyed by name. A name
# that is not in that table draws NOTHING — silently, on a machine that is not
# this one. That is exactly the failure a cheap test should catch, and it is the
# reason the glyphs are named strings rather than an enum: an enum would be
# checked by the QML engine, which is not available here.

if python3 - <<'PYTHON'
import pathlib
import re
import sys

table = pathlib.Path('components/quicksettings/QsGlyph.qml').read_text(encoding='utf-8')

# The keys of the `art` object: lines of the shape   "wifi": {
known = set(re.findall(r'^\s*"([a-z0-9-]+)"\s*:\s*\{', table, re.M))
if not known:
    print("  FAIL could not find any glyph names in QsGlyph.qml's table.")
    print("       Has the shape of that file changed? This test reads it by hand.")
    sys.exit(1)

# Only the directories that draw with QsGlyph are checked. The search
# palette also has a property named `glyph:`, but there it means a literal
# character drawn as text ("⏻") — a different vocabulary, not a table lookup.
bad = 0
paths = sorted(pathlib.Path('components/quicksettings').rglob('*.qml')) \
      + sorted(pathlib.Path('components/bar').rglob('*.qml'))
for path in paths:
    if path.name == 'QsGlyph.qml':
        continue
    text = path.read_text(encoding='utf-8')
    # glyph: "name"   /   fallbackGlyph: "name"
    for match in re.finditer(r'\b(?:glyph|fallbackGlyph)\s*:\s*"([^"]*)"', text):
        name = match.group(1)
        if name == "":
            continue
        if name not in known:
            print("  FAIL %s asks for the glyph '%s', which QsGlyph.qml does not have."
                  % (path, name))
            bad += 1

if bad == 0:
    print("  OK   every glyph name used is in QsGlyph.qml (%d available)" % len(known))
sys.exit(1 if bad else 0)
PYTHON
then
    :
else
    fail "a component asks for a glyph that does not exist (listed above)." \
         "Add it to the table in components/quicksettings/QsGlyph.qml, or fix" \
         "the spelling."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 21. Focus is one switch, in one place ==="
# ------------------------------------------------------------------------------
# Focus (do-not-disturb) is shared between Quick Settings, which flips it, and
# the notification server, which obeys it. If either one keeps its own copy, the
# desktop ends up saying Focus is on while the toasts keep arriving — the single
# most common bug in do-not-disturb implementations.
#
# services/FocusState.qml is the one place it lives. This checks that it is
# properly declared as a singleton, and that nothing under components/ has
# quietly grown a second copy of the state.

if grep -q '^singleton FocusState .*FocusState\.qml$' services/qmldir; then
    pass "services/qmldir declares FocusState"
else
    fail "services/qmldir does not declare FocusState." \
         "Add:  singleton FocusState FocusState.qml"
fi

if grep -q '^pragma Singleton' services/FocusState.qml; then
    pass "services/FocusState.qml says 'pragma Singleton'"
else
    fail "services/FocusState.qml is a singleton but does not say" \
         "'pragma Singleton' at the top. Both are required."
fi

if grep -rn --include='*.qml' -E 'property\s+bool\s+(focusEnabled|dndEnabled|doNotDisturb|notificationsInhibited)' \
        components/ > /dev/null 2>&1; then
    grep -rn --include='*.qml' -E 'property\s+bool\s+(focusEnabled|dndEnabled|doNotDisturb|notificationsInhibited)' \
        components/ || true
    fail "a component keeps its own copy of the Focus state." \
         "Focus lives in services/FocusState.qml and nowhere else. Read it," \
         "call toggle(), and do not cache 'enabled'."
else
    pass "no component duplicates the Focus state"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 22. shelling out happens only where it is documented ==="
# ------------------------------------------------------------------------------
# Almost everything in this shell reaches the system through a Quickshell
# service speaking a published protocol. Exactly two places run a command-line
# program instead, and both are deliberate, documented, and quarantined:
#
#   SliderBrightness.qml  runs `brightnessctl`, because Quickshell has no
#                         brightness service and QML has no generic D-Bus type.
#                         INTERIM — see the header of that file.
#   TileGameMode.qml      hands off to the OS's own session-switching command.
#                         That is the seam; Game Mode is not the shell's to
#                         implement.
#
# A third one appearing without a conversation is how a portable shell quietly
# turns into a pile of scripts. If you are adding one, add it here too and write
# down why in docs/quick-settings.md.

#   SearchEngine.qml      runs `loginctl` / `systemctl` for the palette's
#                         session actions (Quickshell 0.3.1 has no logind
#                         binding). INTERIM — see docs/flow-search.md.

aq_allowed_shellers="components/quicksettings/SliderBrightness.qml components/quicksettings/TileGameMode.qml components/search/SearchEngine.qml"

aq_shell_out_ok=1
while IFS= read -r aq_file; do
    case " ${aq_allowed_shellers} " in
        *" ${aq_file} "*) ;;
        *)
            fail "${aq_file} builds a command line." \
                 "Only these files may: ${aq_allowed_shellers}." \
                 "Everything else goes through a Quickshell service."
            aq_shell_out_ok=0
            ;;
    esac
done < <(grep -rl --include='*.qml' -E '(^|[^A-Za-z])command\s*[:=]\s*\[' components/ \
         | sed 's|^\./||' | sort -u)

if [ "${aq_shell_out_ok}" -eq 1 ]; then
    pass "only the two documented files run a command"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 23. the search palette's logic actually runs ==="
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
echo "=== 24. the search JavaScript stays plain JavaScript ==="
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
echo "=== 25. the search palette can actually be summoned ==="
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
echo "=== 26. no id shadows a property every QML object already has ==="
# ------------------------------------------------------------------------------
# THIS SECTION EXISTS BECAUSE OF A BUG THAT COST THREE FEATURES SILENTLY.
#
# The search overlay used `id: palette`. Every QML Item ALSO has a built-in
# `palette` property — Qt 6's colour-group API. When a child object looks up a
# name, its own properties are found before the enclosing file's ids, so inside
# a delegate `palette.selectedIndex` did not mean the window with that id. It
# meant `Item.palette.selectedIndex`, which is undefined.
#
# Nothing failed loudly: `index === undefined` is just false. The selected row
# was never drawn, its Enter hint never appeared, and the confirm-twice guard on
# destructive actions never armed — for the entire life of the file. See the
# comment at the PanelWindow in components/search/FlowSearch.qml.
#
# Renaming an id is free. Debugging this is not. So: no id may be spelled like a
# property that EVERY object has.
#
# The list below is deliberately limited to those universals. Names like `icon`,
# `footer`, `popup` and `background` are properties of particular types only
# (Controls, ListView), so they are safe on a plain Item and are not flagged —
# but if you use one as an id inside a Control, you are playing the same game.
aq_reserved_ids="palette data children parent state states anchors clip opacity
visible enabled focus activeFocus layer scale rotation transform transitions
smooth antialiasing width height implicitWidth implicitHeight x y z objectName
baselineOffset childrenRect containmentMask"

aq_ids_ok=1
while IFS= read -r aq_qml; do
    while IFS= read -r aq_id; do
        for aq_reserved in ${aq_reserved_ids}; do
            if [ "${aq_id}" = "${aq_reserved}" ]; then
                echo "       ${aq_qml}: id: ${aq_id}"
                aq_ids_ok=0
            fi
        done
    done < <(sed -E 's,//.*,,' "${aq_qml}" \
                | grep -oE '^[[:space:]]*id:[[:space:]]*[A-Za-z_][A-Za-z0-9_]*' \
                | sed -E 's,.*id:[[:space:]]*,,')
done < <(find components shell.qml theme services -name '*.qml' 2> /dev/null)

if [ "${aq_ids_ok}" -eq 1 ]; then
    pass "no id collides with a built-in property name"
else
    fail "an id above is spelled like a property every QML object has." \
         "Inside a child object that name resolves to the OBJECT'S property," \
         "not to your id, and the expression silently evaluates to undefined." \
         "Rename the id. This is exactly the bug that made the search palette's" \
         "selected row, its Enter hint and its confirm-twice guard all vanish."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 27. only one overlay can own the keyboard ==="
# ------------------------------------------------------------------------------
# THIS SECTION EXISTS BECAUSE OF DEFECT 1 FROM THE FIRST RUN ON HARDWARE.
#
# Quick Settings is a PopupWindow with `grabFocus: true` — a compositor INPUT
# GRAB, which is exclusive. Open it, then open the search palette: the palette
# draws, dims the desktop and blinks a cursor, and receives nothing. Neither
# component can fix that alone, so the shell has a rule instead:
#
#   ONE EXCLUSIVE OVERLAY AT A TIME. Opening Flow Search, Quick Settings or the
#   notifications panel closes the other two.
#
# services/Overlays.qml holds the rule. This checks the wiring is still there,
# because the failure mode if somebody removes one `claim()` is silent: the
# overlay opens and looks perfect and simply cannot be typed into.
#
# Comments are blanked before matching, for the same reason as sections 13 and
# 25: all three files explain this at length, and a check that passed on the
# explanation rather than on the code would be worse than no check at all.

if [ -f services/Overlays.qml ]; then
    for aq_fn in register unregister claim; do
        if grep -qE "function ${aq_fn}\(" services/Overlays.qml; then
            pass "services/Overlays.qml exposes ${aq_fn}()"
        else
            fail "services/Overlays.qml no longer exposes ${aq_fn}()." \
                 "The three overlays call it by that name."
        fi
    done
fi

# Every overlay must do BOTH halves: register a way to be closed, and claim on
# the way open. One without the other is the bug half-fixed.
#
#   file : what registers it : what claims on open
aq_overlay_rows="components/search/FlowSearch.qml
components/quicksettings/QuickSettingsPopup.qml
components/notifications/NotificationLayer.qml"

while IFS= read -r aq_overlay; do
    aq_code="$(sed -E 's,//.*,,' "${aq_overlay}")"

    if printf '%s' "${aq_code}" | grep -q 'Overlays\.register('; then
        pass "${aq_overlay} registers with Overlays"
    else
        fail "${aq_overlay} does not call Overlays.register()." \
             "Without it, the other overlays cannot close this one, and two" \
             "surfaces end up both believing they have the keyboard."
    fi

    if printf '%s' "${aq_code}" | grep -q 'Overlays\.unregister('; then
        pass "${aq_overlay} unregisters when destroyed"
    else
        fail "${aq_overlay} does not call Overlays.unregister()." \
             "Variants destroys a screen's windows when a monitor is unplugged;" \
             "a closer left behind would be called on a destroyed object."
    fi

    if printf '%s' "${aq_code}" | grep -q 'Overlays\.claim('; then
        pass "${aq_overlay} claims the keyboard on its open path"
    else
        fail "${aq_overlay} does not call Overlays.claim() when it opens." \
             "This is exactly defect 1 in docs/first-run-on-hardware.md: the" \
             "overlay appears, and every keystroke goes to somebody else's grab."
    fi

    if printf '%s' "${aq_code}" | grep -qE '^\s*import\s+"\.\./\.\./services"'; then
        pass "${aq_overlay} imports services/"
    else
        fail "${aq_overlay} uses Overlays but does not import \"../../services\"." \
             "QML fails at load with 'Overlays is not defined'."
    fi

    # `Component.onCompleted` is an ATTACHED type and it arrives with QtQuick.
    # A file that registers without importing QtQuick is refused ENTIRELY, with
    # "Non-existent attached object" and no mention of imports. Found by running
    # it on 2026-09-01; NotificationLayer.qml drew nothing and so had no reason
    # to import QtQuick until it gained a Component.onCompleted.
    if printf '%s' "${aq_code}" | grep -qE '^\s*import\s+QtQuick'; then
        pass "${aq_overlay} imports QtQuick, so Component.onCompleted exists"
    else
        fail "${aq_overlay} uses Component.onCompleted without importing QtQuick." \
             "The Component attached type comes from QtQuick. Without it the" \
             "whole file is refused with 'Non-existent attached object'."
    fi
done <<< "${aq_overlay_rows}"

# The rule has to be written down where a person looking at either overlay will
# find it, not only in the singleton nobody opens.
for aq_doc in docs/quick-settings.md docs/flow-search.md; do
    if grep -q 'Overlays' "${aq_doc}"; then
        pass "${aq_doc} documents the one-overlay-at-a-time rule"
    else
        fail "${aq_doc} does not mention Overlays." \
             "The exclusivity rule is shared behaviour; both pages have to say" \
             "what happens when the other overlay is already open."
    fi
done

# ------------------------------------------------------------------------------
echo ""
echo "=== 28. every enum namespace is one the shipped build actually has ==="
# ------------------------------------------------------------------------------
# THIS SECTION EXISTS BECAUSE OF A BUG THE LOADER PATTERN COULD NOT CATCH.
#
# components/quicksettings/TileWifi.qml said:
#
#     if (root.wifiDevice.state === ConnectionState.Connecting)
#
# `ConnectionState` is the name Quickshell 0.3.x gives that enum. On the build
# AquariusOS ships — Fedora's quickshell-0.2.1^git20260209.dacfa9d, Qt 6.11 —
# the same five variants live under `DeviceConnectionState`. The module loads,
# the file loads, the tile draws, and then the FIRST TIME that line is reached
# QML throws:
#
#     TileWifi.qml[100]: ReferenceError: ConnectionState is not defined
#
# and the binding that touched it dies. Not the file, not the panel: one
# binding, in a log nobody is reading. It survived the bench run only because
# the bench PC has no Wi-Fi adapter, so the subtitle returns "No adapter" four
# lines earlier and never gets there.
#
# QsTileSlot.qml cannot help with this. A Loader catches a module that is not
# INSTALLED. This is a module that is installed and spells one name differently.
#
# So: every capitalised name used as `Name.something` in this repo's QML has to
# be in the register below, which says where it comes from and — for the
# Quickshell ones — that it was PROBED on the shipped build, not read off the
# 0.3.1 documentation. Adding a name you have not checked is the whole failure
# mode, so adding a name to this list is the thing that makes you check.
#
# How to check one. In the aq-shell distrobox, with a throwaway shell.qml:
#
#     ShellRoot { Component.onCompleted: console.warn(typeof TheName) }
#     QT_QPA_PLATFORM=offscreen qs -p .
#
# "object" means it is there. "undefined" means it is not, and `typeof` is safe
# either way — it answers rather than throwing, which is what makes the guarded
# form below work.
#
# Reading the module's .qmltypes is NOT sufficient and was misleading here: that
# file only lists the C++-registered types, so `ToplevelManager` and
# `PerformanceDegradationReason` are absent from it and present in the engine.
# Run the probe.

# Names that come from this repo. Singletons in theme/ and services/, and the
# two .pragma library JavaScript files.
aq_ns_ours="Theme FocusState Overlays SystemAppearance Fuzzy Calc"

# Names Qt itself provides — globals, value types and attached types.
aq_ns_qt="Qt Math JSON Date Object Locale Accessible Component Keys Easing Font
Text TextInput Image Flickable Loader Layout Shape ShapePath"

# Quickshell's own. EVERY ONE OF THESE WAS PROBED under 0.2.1 git on 2026-09-02
# and answered "object". Do not add to this list from the documentation.
aq_ns_quickshell="Quickshell Networking DeviceType Edges DesktopEntries
SystemClock SystemTray Pipewire UPower UPowerDeviceState PowerProfiles
PowerProfile PerformanceDegradationReason Bluetooth BluetoothAdapterState
NotificationUrgency ExclusionMode WlrKeyboardFocus WlrLayershell
ToplevelManager"

# Names that exist on ONE build and not the other. Mentioning one is fine —
# reaching through one for a variant is the bug above.
aq_ns_guarded="ConnectionState DeviceConnectionState"

if python3 - "${aq_ns_ours} ${aq_ns_qt} ${aq_ns_quickshell}" "${aq_ns_guarded}" <<'PYTHON'
import pathlib
import re
import sys

known = set(sys.argv[1].split())
guarded = set(sys.argv[2].split())

# Comments and string literals are stripped first. Both matter here: the files
# EXPLAIN this problem at length and name both spellings while doing it, and the
# tile sources ("TileWifi.qml") and SVG path data ("M12.5 3") are strings full of
# capital letters followed by dots.
def strip(text):
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

member = re.compile(r'(?:^|[^A-Za-z0-9_.$])([A-Z][A-Za-z0-9_]*)\s*\.\s*[A-Za-z_]')
bad = 0

for root in ('components', 'services', 'theme'):
    paths = sorted(pathlib.Path(root).rglob('*.qml'))
    for path in paths + ([pathlib.Path('shell.qml')] if root == 'components' else []):
        code = strip(path.read_text(encoding='utf-8'))
        # `import Quickshell.Services.UPower` is not a member access.
        code = '\n'.join(l for l in code.split('\n')
                         if not l.lstrip().startswith('import '))
        for name in sorted(set(member.findall(code))):
            # Note what is and is not flagged. The regex only finds a name used
            # as `Name.member`. A build-dependent name may still be MENTIONED —
            # `typeof ConnectionState !== "undefined" ? ConnectionState : ...` is
            # the whole point — because a bare mention cannot throw and a member
            # access can. So: reaching THROUGH one of these names is the bug.
            if name in guarded:
                print("  FAIL %s reads %s.<variant> directly." % (path, name))
                print("       That namespace exists on one Quickshell build and"
                      " not the other,")
                print("       and naming the missing one is a ReferenceError"
                      " that kills the")
                print("       binding. Look it up once with typeof — the way"
                      " TileWifi.qml's")
                print("       `connState` does — and read the variant off that.")
                bad += 1
            elif name not in known:
                print("  FAIL %s names %s, which is not in section 28's register."
                      % (path, name))
                print("       Probe it on the shipped build and add it, or fix"
                      " the spelling.")
                bad += 1

sys.exit(1 if bad else 0)
PYTHON
then
    pass "every enum namespace used is one that was checked on the shipped build"
else
    fail "a QML file names something the shipped Quickshell may not have." \
         "This is the ConnectionState bug: the file loads, the tile draws, and" \
         "one binding dies with a ReferenceError nobody sees. The register and" \
         "the probe command are in the comment above this check."
fi
# ------------------------------------------------------------------------------
echo ""
if [ "${aq_failures}" -ne 0 ]; then
    echo "::error::${aq_failures} check(s) failed."
    exit 1
fi
echo "All checks passed."
echo ""
echo "Remember what that does and does not mean. These checks read the files;"
echo "they do not run them. Every failure found on 2026-09-01 — the day this"
echo "shell first ran on real hardware — passed every check on this page first:"
echo "a missing import, a property named after a signal, a property the local"
echo "Qt does not have, an anchor a Row will not accept. A QML engine found all"
echo "four in about a minute."
echo ""
echo "So this is the cheap gate, not the real one. The real one is"
echo "./harness/run-nested.sh on a Linux machine, with the log in front of you."
