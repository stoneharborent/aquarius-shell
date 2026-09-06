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
#   * every size in the theme goes through the one size knob (section 30), and
#     the dock stays deliberately larger than the rest of it (section 31)
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
    services/AppIdentity.qml \
    services/FocusState.qml \
    services/KeyProfile.qml \
    services/Overlays.qml \
    services/SettingsLauncher.qml \
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
    components/switcher/AppSwitcher.qml \
    components/switcher/SwitcherModel.qml \
    components/switcher/SwitcherTile.qml \
    components/switcher/SwitcherRow.qml \
    docs/app-switcher.md \
    tests/search-js-tests.mjs \
    components/notifications/NotificationLayer.qml \
    components/notifications/NotificationStore.qml \
    components/notifications/NotificationPanelWindow.qml \
    components/notifications/NotificationsPanel.qml \
    components/notifications/NotificationGroup.qml \
    components/notifications/NotificationRow.qml \
    components/notifications/ToastLayer.qml \
    components/notifications/Toast.qml \
    components/notifications/ProgressBar.qml \
    components/notifications/progress.js \
    tests/notifications-js-tests.mjs \
    components/notifications/IconChip.qml \
    components/notifications/ActionButtons.qml \
    components/notifications/InlineReply.qml \
    greeter/greeter.qml \
    greeter/qmldir \
    greeter/GreeterState.qml \
    greeter/GreeterWindow.qml \
    greeter/GreeterCard.qml \
    greeter/GreeterField.qml \
    greeter/GreeterAvatar.qml \
    greeter/GreeterStepArrow.qml \
    greeter/GreeterDesktopPill.qml \
    greeter/aquarius-greeter-info \
    docs/greeter.md \
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

if grep -rn --include='*.qml' -E '"#[0-9A-Fa-f]{3,8}"' components/ services/ greeter/ shell.qml > /dev/null 2>&1; then
    grep -rn --include='*.qml' -E '"#[0-9A-Fa-f]{3,8}"' components/ services/ greeter/ shell.qml || true
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
    'AppIdentity': declared('services/AppIdentity.qml'),
    'FocusState': declared('services/FocusState.qml'),
    'KeyProfile': declared('services/KeyProfile.qml'),
    'Overlays': declared('services/Overlays.qml'),
    'GreeterState': declared('greeter/GreeterState.qml'),
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
    session/labwc/menu.xml \
    session/labwc/themerc-override \
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
#
# ⚠️ ONE FILE IS EXEMPT, AND ONLY ONE: session/labwc/themerc-override.
#
# labwc draws two things the shell cannot — the desktop right-click menu and
# every window's title bar — and it is a C program reading a flat text file, so
# it cannot import QML. Until this repo owns window decoration itself, the only
# way those surfaces can look like Aquarius is for somebody to write the numbers
# out a second time. That was signed off on 2026-09-06, after the bench note
# "the right click menu does not have a design yet".
#
# The exemption is not a hole, because section 15b immediately below checks every
# colour in that file against theme/Ice.qml. It is excluded here so that 15b can
# be the one that speaks about it, with a message that actually helps.

if grep -rn -E '#[0-9A-Fa-f]{3,8}\b' \
        session/niri session/labwc session/portals \
        --exclude=themerc-override > /dev/null 2>&1; then
    grep -rn -E '#[0-9A-Fa-f]{3,8}\b' \
        session/niri session/labwc session/portals \
        --exclude=themerc-override || true
    fail "a session configuration contains what looks like a hex colour." \
         "Colour belongs in theme/Ice.qml and theme/Midnight.qml only." \
         "The single exception is session/labwc/themerc-override, which exists" \
         "because labwc cannot read QML — and every value in THAT file has to" \
         "appear in theme/Ice.qml (section 15b). Leave everything else at the" \
         "compositor's own defaults."
else
    pass "no colours in the compositor or portal configurations"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 15b. every colour in labwc's themerc came out of Ice ==="
# ------------------------------------------------------------------------------
# THE ONE SANCTIONED COPY OF THE PALETTE, AND THE CHECK THAT KEEPS IT HONEST.
#
# session/labwc/themerc-override gives labwc's own menu and title bars the
# Aquarius look. It is the only file outside theme/ allowed to hold a colour,
# because labwc reads a flat text file and cannot import QML.
#
# A second copy of a palette is a palette that drifts. Somebody adjusts Ice's
# surface colour, nobody remembers this file, and six months later the desktop
# menu is a slightly different white from every other card on screen — the exact
# failure the "colour lives in theme/ only" rule was written to prevent.
#
# So: pull every #rrggbb out of that file and require each one to appear, byte
# for byte, in theme/Ice.qml. Comparison is case-insensitive because a themerc is
# conventionally lower case and Ice writes its values upper case; the DIGITS are
# what must match.
#
# Translucent values are written labwc's way, #rrggbbaa, with the opacity last;
# QML writes the same colour #aarrggbb, with the opacity first. Only the six
# colour digits are compared, which is why each such line in that file names the
# Ice token and the percentage in a comment beside it — the alpha byte is checked
# by a person, not by this.

aq_themerc="session/labwc/themerc-override"

if [ -f "${aq_themerc}" ]; then
    pass "${aq_themerc}"

    # SETTING lines only — anything whose first character is '#' is a comment
    # and labwc never reads it. That matters for more than tidiness: the
    # comments in that file quote the QML spelling of each colour (#aarrggbb,
    # opacity first), and the first six digits of THOSE are the opacity plus
    # four colour digits — a string that means nothing and would be compared
    # against Ice as though it did. Check what labwc actually reads.
    aq_themerc_colours="$(grep -v '^[[:space:]]*#' "${aq_themerc}" \
        | grep -oE '#[0-9A-Fa-f]{6}' | sort -u)"

    if [ -z "${aq_themerc_colours}" ]; then
        fail "${aq_themerc} contains no colours at all." \
             "It exists to give labwc's menu and title bars the Ice palette." \
             "An empty one means the desktop menu is back to labwc's grey."
    else
        aq_themerc_drift=0
        while IFS= read -r aq_colour; do
            # Quoted, so a value can only match a WHOLE token in Ice. Without
            # the quotes, "#16273A" would also be found inside Ice's
            # "#1A16273A" — and a six-digit slice of an eight-digit value is
            # not the same colour, it is a coincidence.
            if grep -qiE "\"${aq_colour}\"" theme/Ice.qml; then
                pass "themerc ${aq_colour} is an Ice value"
            else
                fail "${aq_themerc} uses ${aq_colour}, which is not in" \
                     "theme/Ice.qml." \
                     "Every colour in that file is a COPY of an Ice token — not" \
                     "a new colour, not a nudged one, not one somebody" \
                     "eyeballed. If Ice needs a value it does not have, that is" \
                     "a design decision and it goes into theme/Ice.qml first." \
                     "(Translucent values are written #rrggbbaa there and" \
                     "#aarrggbb in QML; only the six colour digits are compared," \
                     "so this is complaining about the colour, not the opacity.)"
                aq_themerc_drift=1
            fi
        done <<< "${aq_themerc_colours}"

        if [ "${aq_themerc_drift}" -eq 0 ]; then
            pass "the themerc holds no colour Ice does not"
        fi
    fi

    # The file has to SAY that it is the exception and that a test watches it,
    # because the person who opens it is the only one who can keep it in step.
    for aq_needle in 'theme/Ice.qml' 'system_files/usr/share/aquarius/labwc/themerc-override'; do
        if grep -qF "${aq_needle}" "${aq_themerc}"; then
            pass "the themerc mentions ${aq_needle}"
        else
            fail "${aq_themerc} does not mention ${aq_needle}." \
                 "It must say where its colours come from, and that an" \
                 "installed machine reads the os-image copy rather than this" \
                 "one — the same change-one-change-both note menu.xml and" \
                 "autostart next to it already carry."
        fi
    done

    # Only Ice for now. The follow-up — a Midnight file plus a reconfigure — has
    # to be written down in the file, not remembered.
    if grep -qF 'labwc --reconfigure' "${aq_themerc}"; then
        pass "the themerc records the Midnight follow-up"
    else
        fail "${aq_themerc} does not record how a dark theme would work." \
             "It is Ice only, so on a dark desktop the menu and title bars stay" \
             "light. That needs a second file built from theme/Midnight.qml," \
             "something to swap them when SystemAppearance flips, and" \
             "'labwc --reconfigure' afterwards. Say so in the file."
    fi

    # labwc's themerc has no end-of-line comments: process_line() returns early
    # on a leading '#', and parse_config_line() takes everything after the first
    # colon as the value. So `key: value   # why` sets the value to
    # "value   # why", which parses as a colour of nothing and silently keeps
    # labwc's default. This is the single most likely way to break that file.
    if grep -nE '^[^#].*:.*#' "${aq_themerc}" \
            | grep -vE ':[[:space:]]*#[0-9A-Fa-f]{6,8}[[:space:]]*$' \
            > /dev/null 2>&1; then
        grep -nE '^[^#].*:.*#' "${aq_themerc}" \
            | grep -vE ':[[:space:]]*#[0-9A-Fa-f]{6,8}[[:space:]]*$' || true
        fail "${aq_themerc} has what looks like an end-of-line comment." \
             "labwc has none: it takes everything after the first colon as the" \
             "value, so the setting is silently ignored and the default stands." \
             "Put the comment on its own line, starting with #."
    else
        pass "the themerc has no end-of-line comments"
    fi
else
    fail "${aq_themerc} is missing." \
         "Without it labwc draws the desktop right-click menu and every window" \
         "title bar in its own default grey — the bench note of 2026-09-06," \
         "'the right click menu does not have a design yet'."
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
echo "=== 17b. what starts at login is written down in BOTH session files ==="
# ------------------------------------------------------------------------------
# labwc's autostart file is a shell script, and a typo in it does not produce an
# error anybody sees — it produces a login where the rest of the file never ran.
# So parse it, the same way check 17 parses the scripts.
#
# Then the drift check. Neither of our compositors reads /etc/xdg/autostart, so
# anything that must start at login is written down once per compositor. The
# failure that follows is nasty precisely because it is quiet: somebody adds a
# line to one file, the other session keeps starting perfectly, and the missing
# program is only noticed by whoever happened to be on the other compositor.
#
# The list below is the login-time extras, by the substring that must appear in
# both files. It is short on purpose — add to it when a new one is added, and
# remember the THIRD copy, the .desktop file in the os-image repo, which that
# repo's own build checks.

if bash -n session/labwc/autostart 2>/dev/null; then
    pass "session/labwc/autostart is valid shell"
else
    bash -n session/labwc/autostart || true
    fail "session/labwc/autostart is not valid shell." \
         "labwc runs this file at every login. A syntax error in it means" \
         "everything after the mistake silently never runs."
fi

aq_login_extras=(
    'aquarius-welcome --first-run'
)

for aq_login_extra in "${aq_login_extras[@]}"; do
    aq_missing_from=""
    for aq_session_file in session/labwc/autostart session/niri/config.kdl; do
        if ! grep -qF "${aq_login_extra}" "${aq_session_file}"; then
            aq_missing_from="${aq_missing_from} ${aq_session_file}"
        fi
    done
    if [ -z "${aq_missing_from}" ]; then
        pass "'${aq_login_extra}' is in both session files"
    else
        fail "'${aq_login_extra}' is missing from:${aq_missing_from}" \
             "Anything that has to run at login must be written down once per" \
             "compositor, because neither labwc nor niri reads /etc/xdg/autostart." \
             "See 'What else starts at login' in docs/session.md."
    fi
done

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

#
# components/notifications/progress.js joined them on 2026-09-04, when the
# "Make Editor-Ready" progress bar arrived. It reads two hints that come over
# D-Bus from ANY application on the machine, so most of what it does is decide
# what to make of rubbish — the sort of thing that must be executed to be
# believed.

if command -v node > /dev/null 2>&1; then
    if node tests/search-js-tests.mjs; then
        pass "the search matcher and calculator behave"
    else
        fail "the search logic tests failed (listed above)."
    fi

    if node tests/notifications-js-tests.mjs; then
        pass "the notification progress logic behaves"
    else
        fail "the notification progress tests failed (listed above)."
    fi
else
    echo "  SKIP node is not installed; the JavaScript logic tests cannot run."
    echo "       These are the only tests in this repo that execute real code —"
    echo "       install node and run them before trusting a change to fuzzy.js,"
    echo "       calc.js or components/notifications/progress.js."
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
for aq_js in components/search/fuzzy.js components/search/calc.js \
             components/notifications/progress.js; do
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
    pass "fuzzy.js, calc.js and progress.js are pure, testable JavaScript"
fi

# The brackets in the JavaScript, for the case where node is not installed and
# section 12 skipped. Same idea as section 2, same reason.
if python3 - components/search components/notifications <<'PYTHON'
import pathlib
import sys

roots = [pathlib.Path(a) for a in sys.argv[1:]]
bad = 0

pairs = {'}': '{', ')': '(', ']': '['}
openers = set(pairs.values())

for path in sorted(q for r in roots for q in r.rglob('*.js')):
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
# The dock's two menus joined this list on 2026-09-06. Both are PopupWindows with
# `grabFocus: true` — the very shape that caused defect 1 — and once there were
# two kinds of menu in one dock, "opening one closes the other" stopped being a
# nicety and became the same rule as everywhere else in the shell.
#
#   file : what registers it : what claims on open
aq_overlay_rows="components/search/FlowSearch.qml
components/quicksettings/QuickSettingsPopup.qml
components/notifications/NotificationLayer.qml
components/bar/LogoMenu.qml
components/dock/DockItem.qml
components/dock/DockDrive.qml
components/switcher/AppSwitcher.qml"

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
# three .pragma library JavaScript files (Fuzzy, Calc, Progress) — those are
# `import "x.js" as Name`, so they are our own code and cannot be missing from a
# Quickshell build.
aq_ns_ours="Theme FocusState Overlays SettingsLauncher SystemAppearance Fuzzy
Calc Progress GreeterState AppIdentity KeyProfile"

# Names Qt itself provides — globals, value types and attached types.
aq_ns_qt="Qt Math JSON Date Object Locale Accessible Component Keys Easing Font
Text TextInput Image Flickable Loader Layout Shape ShapePath"

# Quickshell's own. EVERY ONE OF THESE WAS PROBED under 0.2.1 git on 2026-09-02
# and answered "object". Do not add to this list from the documentation.
aq_ns_quickshell="Quickshell Networking DeviceType Edges DesktopEntries
SystemClock SystemTray Pipewire UPower UPowerDeviceState PowerProfiles
PowerProfile PerformanceDegradationReason Bluetooth BluetoothAdapterState
NotificationUrgency ExclusionMode WlrKeyboardFocus WlrLayershell
ToplevelManager Greetd GreetdState"

# ⚠️ Greetd and GreetdState were NOT probed the way the rest of that list was,
# and here is the honest reason. They belong to the login screen, and the login
# screen cannot be probed the way the desktop can: there is no greetd socket on
# a developer's machine and no session to run `qs` inside. What stands in for
# the probe is stronger. The image build compiles Quickshell itself and FAILS
# THE BUILD if SERVICE_GREETD is not ON in the finished program (os-image,
# build_files/stage-quickshell.sh). A build cache that says ON plus a build that
# finished is proof the module is compiled in.

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

for root in ('components', 'services', 'theme', 'greeter'):
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
echo "=== 29. the session can actually SEE the shell fail ==="
# ------------------------------------------------------------------------------
# THIS SECTION EXISTS BECAUSE OF THE FIRST REAL BOOT, 2026-09-02.
#
# The session started. niri came up on a 4K screen and ran for eighteen minutes.
# There was no bar, and the log held ONLY niri's output — not one line from the
# shell. Two blind spots, either of which alone would have hidden the problem:
#
#   1. The launcher's pre-flight asked `command -v qs`, which only answers "is
#      there a file with that name". There was. It could not start:
#      `qs: symbol lookup error: qs: undefined symbol: ...` — the layered
#      quickshell had been rebuilt against a newer Qt than the OS image's.
#      A program that dies before its first line of output passes `command -v`.
#
#   2. niri gives every program it starts /dev/null for stdin, stdout AND
#      stderr. Measured on niri 26.04 the same day: a spawned shell was asked
#      what its own three file descriptors pointed at, and answered /dev/null
#      three times. So the shell's error message went nowhere.
#
# Both fixes are cheap and both are easy to undo by accident, so both are
# checked here. Comments are stripped before matching, because all three files
# explain this at length and a check that passes on the explanation is worse
# than no check at all.

# --- the launcher must RUN qs, not just find it -------------------------------
aq_launcher_code="$(sed -E 's,^[[:space:]]*#.*,,' session/aquarius-session)"

if printf '%s' "${aq_launcher_code}" | grep -q 'qs --version'; then
    pass "the launcher runs 'qs --version' rather than only looking for the file"
else
    fail "session/aquarius-session no longer runs 'qs --version'." \
         "'command -v qs' passes for a binary that cannot start at all — which" \
         "is exactly what happened on 2026-09-02. The pre-flight has to START" \
         "the program. See docs/session.md, 'The Qt ABI trap'."
fi

# The die message is the whole value of the check: a person at a black login
# screen needs to be told what to do, not just that something failed.
if printf '%s' "${aq_launcher_code}" | grep -q 'symbol lookup error'; then
    pass "the launcher's failure message names the Qt-mismatch symptom"
else
    fail "session/aquarius-session no longer mentions 'symbol lookup error'." \
         "That is the exact wording the Qt mismatch prints, and the message" \
         "shown to the user is supposed to recognise it and say what to do."
fi

# --- the launcher must export the log path ------------------------------------
# The compositor configs append to \$AQ_LOG by name. If it stops being exported,
# they fall back to /dev/null and the shell goes silent again — quietly.
if printf '%s' "${aq_launcher_code}" | grep -qE '^\s*export AQ_LOG'; then
    pass "the launcher exports AQ_LOG for the compositor configs to append to"
else
    fail "session/aquarius-session does not export AQ_LOG." \
         "Both compositor configurations redirect the shell's output to" \
         "\"\${AQ_LOG}\". Without the export they silently write to /dev/null" \
         "and the shell's errors vanish, which is the 2026-09-02 failure again."
fi

# --- both compositors must route the shell's output somewhere -----------------
#   file : how comments start in it
aq_spawn_rows="session/niri/config.kdl://
session/labwc/autostart:#"

while IFS= read -r aq_row; do
    aq_spawn_file="${aq_row%%:*}"
    aq_spawn_comment="${aq_row##*:}"

    if [ "${aq_spawn_comment}" = "#" ]; then
        aq_spawn_code="$(sed -E 's,^[[:space:]]*#.*,,' "${aq_spawn_file}")"
    else
        aq_spawn_code="$(sed -E 's,//.*,,' "${aq_spawn_file}")"
    fi

    # The line that starts the shell has to carry a redirect to the log.
    if printf '%s' "${aq_spawn_code}" | grep -q 'qs' \
       && printf '%s' "${aq_spawn_code}" | grep -q '>>' \
       && printf '%s' "${aq_spawn_code}" | grep -q 'AQ_LOG'; then
        pass "${aq_spawn_file} appends the shell's output to \$AQ_LOG"
    else
        fail "${aq_spawn_file} starts the shell without capturing its output." \
             "A compositor hands its children /dev/null, so a bare 'qs' means" \
             "every QML error, every missing library and every crash is thrown" \
             "away. Start it through a shell and append to \"\${AQ_LOG}\"." \
             "This is the 2026-09-02 blind spot; see docs/session.md."
    fi

    # And the lines have to be tellable apart from the compositor's own.
    if printf '%s' "${aq_spawn_code}" | grep -qF '[shell]'; then
        pass "${aq_spawn_file} prefixes the shell's lines with [shell]"
    else
        fail "${aq_spawn_file} does not prefix the shell's log lines." \
             "One file holds both the compositor's output and the shell's." \
             "Without a prefix, reading it means guessing which is which."
    fi
done <<< "${aq_spawn_rows}"

# ------------------------------------------------------------------------------
echo ""
echo "=== 30. the size knob reaches every size ==="
# ------------------------------------------------------------------------------
# THIS SECTION EXISTS BECAUSE OF THE BENCH TEST, 2026-09-03.
#
# The shell drew correctly and read too small on a 55" 4K monitor. Part of that
# was the session running the output at scale 1.0; the rest was a design
# question only Royce could answer, and answering it meant trying 1.15, 1.25 and
# 1.5 on the real machine. AQ_UI_SCALE is how he did that: Theme.ui reads it,
# Theme.px() applies it, and every size token in theme/Theme.qml is written
# root.px(N).
#
# He answered it the same day — 1.25 for the shell, 1.5 for the dock — and those
# numbers are now the tokens themselves, so the knob sits at 1.0 again. This
# check outlived the question it was written for, because the knob did: the
# next monitor asks it again.
#
# A PARTIAL multiplier is worse than none. If one token stays a bare number, the
# bar grows and its icons do not, or the panel grows and its corners stay sharp,
# and the design comes apart at exactly the setting Royce was trying to judge.
# So: no bare numeric size token in Theme.qml, ever. The exemption list below is
# short and each entry says why it is not a size.

if python3 - <<'PYTHON'
import pathlib
import re
import sys

text = pathlib.Path('theme/Theme.qml').read_text(encoding='utf-8')

# Things that are numbers but are NOT sizes, so must NOT be multiplied.
#   durFast/durMed  milliseconds. A taller bar must not animate more slowly.
#   uiScaleMin/Max  the clamp on the knob itself.
#   dockHoverScale  already a multiplier.
#   switcherOpenScale  the same: the fraction of its final size the app
#                   switcher's panel grows from. Scaling a scale would make the
#                   animation start from a different place on a bigger screen.
# dockDotOpacity/dockDotOpacityActive were here until 2026-09-04, when the dock
# dot stopped being a translucent accent and became two solid colour roles.
exempt = {'durFast', 'durMed', 'uiScaleMin', 'uiScaleMax', 'dockHoverScale',
          'switcherOpenScale'}

bad = 0
scaled = 0

for line in text.split('\n'):
    m = re.match(r'\s*readonly\s+property\s+(int|real)\s+(\w+)\s*:\s*(.+?)\s*(?://.*)?$', line)
    if not m:
        continue
    name, value = m.group(2), m.group(3)
    if name in exempt:
        continue
    if not re.match(r'^-?[\d.]+$', value):
        continue
    print("  FAIL %s is a bare number (%s). Write it root.px(%s)." % (name, value, value))
    bad += 1

for line in text.split('\n'):
    if 'root.px(' in line and 'function px' not in line:
        scaled += 1

# The knob's own machinery has to still be there and still do the two things it
# claims: read the environment variable, and multiply by it.
if 'Quickshell.env("AQ_UI_SCALE")' not in text:
    print("  FAIL Theme.ui no longer reads AQ_UI_SCALE from the environment.")
    bad += 1

if not re.search(r'function\s+px\s*\([^)]*\)[^{]*\{', text):
    print("  FAIL theme/Theme.qml has no px() function.")
    bad += 1
elif 'Math.round(n * root.ui)' not in text:
    print("  FAIL px() no longer multiplies by root.ui.")
    bad += 1

# One multiplier, in one place. If a second file starts doing its own scaling
# arithmetic the knob stops being one number and starts being a convention.
others = 0
for path in sorted(pathlib.Path('.').rglob('*.qml')):
    if '.git' in path.parts or path == pathlib.Path('theme/Theme.qml'):
        continue
    # Comments are stripped first: a file is allowed to EXPLAIN the knob, it is
    # just not allowed to read it. (StatusCluster.qml used to be the example
    # here; the placeholder box whose comment explained the knob was removed on
    # 2026-09-04. The stripping still matters — the next explainer will come.)
    code = path.read_text(encoding='utf-8')
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.S)
    code = re.sub(r'//[^\n]*', '', code)
    if 'AQ_UI_SCALE' in code:
        print("  FAIL %s reads AQ_UI_SCALE itself. Only Theme.qml may." % path)
        others += 1
bad += others

if bad == 0:
    print("  OK   %d size tokens all go through the one multiplier" % scaled)

sys.exit(1 if bad else 0)
PYTHON
then
    :
else
    fail "the AQ_UI_SCALE knob does not reach every size (listed above)." \
         "Every numeric size in theme/Theme.qml is written root.px(N) so that" \
         "one environment variable resizes the whole design at once. A token" \
         "left bare refuses to grow with the rest. See the SIZE KNOB block at" \
         "the top of theme/Theme.qml."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 31. the dock stays bigger than the rest of the shell ==="
# ------------------------------------------------------------------------------
# THIS SECTION EXISTS BECAUSE OF THE BENCH TEST, 2026-09-03.
#
# Royce looked at the shell on a 55" 4K monitor and gave two numbers, not one:
# the shell reads right at 1.25x its original artboard sizes, and the dock reads
# right at 1.5x. Those numbers are now baked into theme/Theme.qml, which means
# the dock is deliberately out of step with everything around it.
#
# Deliberate-but-odd is exactly the kind of decision that gets tidied away by a
# later, entirely reasonable change. "The bar is a touch tall, take it to 34" is
# a one-token edit that would quietly make the dock look oversized, and nobody
# would connect the two. So the RELATIONSHIP is what gets asserted, not either
# number: the dock's tile is meant to be roughly 1.75x the bar's height, and if
# that drifts far in either direction, somebody moved one without the other.
#
# The band is wide on purpose. This is a design guard, not a pixel test — it
# should survive rounding and small honest adjustments and only fire when the
# two have genuinely come apart. At the time of writing it is 66/38 = 1.74.
#
# The second check is the dock's own arithmetic, which the comment in Theme.qml
# claims and nothing else verifies: the running dot hangs BELOW its tile, and it
# has to still land inside the slab. dockDotGap + dockDotSize must fit within
# dockPaddingV, or the dot is drawn over the slab's edge.

if python3 - <<'PYTHON'
import pathlib
import re
import sys

text = pathlib.Path('theme/Theme.qml').read_text(encoding='utf-8')

def token(name):
    m = re.search(r'readonly\s+property\s+int\s+%s\s*:\s*root\.px\((\d+)\)' % name, text)
    if not m:
        print("  FAIL theme/Theme.qml has no token named %s." % name)
        return None
    return int(m.group(1))

bad = 0

# --- the dock is meant to read bigger than the bar ---------------------------
ratio_lo, ratio_hi = 1.60, 1.90

tile = token('dockTileSize')
bar = token('barHeight')
if tile is None or bar is None:
    bad += 1
else:
    ratio = tile / bar
    if not (ratio_lo <= ratio <= ratio_hi):
        print("  FAIL dockTileSize/barHeight is %.2f (%d/%d); expected %.2f-%.2f."
              % (ratio, tile, bar, ratio_lo, ratio_hi))
        print("       The dock is 1.5x the artboard and the bar is 1.25x, on")
        print("       Royce's call of 2026-09-03. Changing one without the")
        print("       other breaks that. See THE DOCK in theme/Theme.qml.")
        bad += 1
    else:
        print("  OK   dock tile %d is %.2fx the %dpx bar (band %.2f-%.2f)"
              % (tile, ratio, bar, ratio_lo, ratio_hi))

# --- the running dot has to fit inside the slab ------------------------------
gap = token('dockDotGap')
dot = token('dockDotSize')
padv = token('dockPaddingV')
if None in (gap, dot, padv):
    bad += 1
elif gap + dot > padv:
    print("  FAIL the running dot does not fit: dockDotGap(%d) + dockDotSize(%d)"
          " = %d, but dockPaddingV is only %d." % (gap, dot, gap + dot, padv))
    print("       The dot is drawn below its tile and would spill over the")
    print("       slab's bottom edge.")
    bad += 1
else:
    print("  OK   the running dot fits under its tile with %dpx to spare"
          % (padv - gap - dot))

sys.exit(1 if bad else 0)
PYTHON
then
    :
else
    fail "the dock's proportions have drifted (listed above)." \
         "The dock is deliberately larger than the rest of the shell —" \
         "1.5x the artboard where everything else is 1.25x — because Royce" \
         "judged it that way on a 55\" 4K on 2026-09-03. Read THE DOCK block" \
         "in theme/Theme.qml before changing either number."
fi

# ==============================================================================
# THE LOGIN SCREEN (greeter/) — check 32
# ==============================================================================

# ------------------------------------------------------------------------------
echo ""
echo "=== 32. the login screen holds together ==="
# ------------------------------------------------------------------------------
# The greeter is the one part of this repo that runs BEFORE anybody has logged
# in, which changes what a bug costs. A broken bar is a desktop with no bar. A
# broken login screen is a computer nobody can get into, and the way out is a
# text console and a command typed from memory.
#
# So the checks here are about the things that would do exactly that.

# --- it must not import a compositor's own module -----------------------------
# Section 3 already covers the whole repo. This is the same law said again where
# it is most tempting to break it: a greeter is the one place where "just use
# the compositor's IPC" looks harmless, and it is how the login screen would
# stop working the day the compositor underneath changes.
if grep -rn --include='*.qml' -E '^\s*import\s+Quickshell\.(Hyprland|I3)' greeter/ > /dev/null 2>&1; then
    fail "the login screen imports a compositor-specific module."
else
    pass "the login screen speaks only standard protocols"
fi

# --- the singleton has to be declared, twice ----------------------------------
# Same trap as theme/qmldir: `pragma Singleton` alone is not enough, and the
# failure message ("GreeterState is not a type") does not mention qmldir.
if grep -q '^singleton GreeterState .*GreeterState\.qml$' greeter/qmldir; then
    pass "greeter/qmldir declares GreeterState"
else
    fail "greeter/qmldir does not declare GreeterState." \
         "Add:  singleton GreeterState 1.0 GreeterState.qml"
fi
if grep -q '^pragma Singleton' greeter/GreeterState.qml; then
    pass "greeter/GreeterState.qml says 'pragma Singleton'"
else
    fail "greeter/GreeterState.qml is listed as a singleton but does not say" \
         "'pragma Singleton' at the top. Both are required."
fi

# --- the whole greetd conversation has to be answered -------------------------
# ⚠️ THIS IS THE CHECK THAT MATTERS MOST IN THIS SECTION.
#
# greetd's conversation is five steps and a login screen that forgets ONE of
# them does not fail — it hangs. You type your password, press Enter, and
# nothing happens, for ever, with no error anywhere. Every one of these has to
# be reached from somewhere in greeter/.
for aq_step in \
    'Greetd.createSession' \
    'Greetd.respond' \
    'Greetd.cancelSession' \
    'Greetd.launch' \
    'onAuthMessage' \
    'onAuthFailure' \
    'onReadyToLaunch'
do
    if grep -rq --include='*.qml' -F "${aq_step}" greeter/; then
        pass "the login screen handles ${aq_step}"
    else
        fail "nothing in greeter/ uses ${aq_step}." \
             "greetd's conversation is five steps and missing one does not" \
             "produce an error — it produces a login screen that hangs after" \
             "you press Enter. See the header of greeter/GreeterState.qml."
    fi
done

# --- a password must never be left sitting in the box -------------------------
if grep -q 'passwordField.clear()' greeter/GreeterCard.qml; then
    pass "the password box is emptied as soon as its contents are handed over"
else
    fail "greeter/GreeterCard.qml no longer clears the password box after" \
         "signing in. A password left in a text box is a password on a screen" \
         "anybody can walk up to."
fi

# --- the keyboard has to be taken, and taken exclusively ----------------------
# focusable:true alone maps to OnDemand — "focus me if the system decides to".
# On a screen where nobody has clicked anything, the system may decide not to,
# and then the password box does not take typing at all.
if grep -q 'WlrKeyboardFocus.Exclusive' greeter/GreeterWindow.qml; then
    pass "the login screen takes the keyboard exclusively"
else
    fail "greeter/GreeterWindow.qml no longer asks for exclusive keyboard" \
         "focus. Without it the password box may never receive a keystroke," \
         "which looks exactly like a frozen computer."
fi

# --- the helper has to be real Python and answer -------------------------------
if python3 -m py_compile greeter/aquarius-greeter-info 2>/dev/null; then
    pass "greeter/aquarius-greeter-info compiles"
    rm -rf greeter/__pycache__
else
    fail "greeter/aquarius-greeter-info does not compile."
fi
if [ -x greeter/aquarius-greeter-info ]; then
    pass "greeter/aquarius-greeter-info is executable"
else
    fail "greeter/aquarius-greeter-info is not executable." \
         "Run:  chmod +x greeter/aquarius-greeter-info"
fi

# Run it for real and check it prints usable JSON with both keys in it. On a Mac
# or a CI runner there are no wayland-sessions and possibly no ordinary users,
# so BOTH lists being empty is a correct answer — what is being checked is that
# it answers at all and answers in the shape the QML reads.
if python3 - <<'PYTHON'
import json
import subprocess
import sys

done = subprocess.run(["python3", "greeter/aquarius-greeter-info"],
                      capture_output=True, text=True)
if done.returncode != 0:
    print("  FAIL it exited %d: %s" % (done.returncode, done.stderr.strip()))
    sys.exit(1)
try:
    data = json.loads(done.stdout)
except ValueError as problem:
    print("  FAIL what it printed is not JSON: %s" % problem)
    sys.exit(1)
for key in ("people", "desktops"):
    if not isinstance(data.get(key), list):
        print("  FAIL its answer has no '%s' list in it" % key)
        sys.exit(1)
print("  OK   it prints JSON with a people list and a desktops list "
      "(%d and %d here)" % (len(data["people"]), len(data["desktops"])))
sys.exit(0)
PYTHON
then
    :
else
    fail "greeter/aquarius-greeter-info did not print the answer the login" \
         "screen reads (above). greeter/GreeterState.qml calls JSON.parse on" \
         "it and shows an error on the card if it cannot."
fi

# --- the command the operating system runs ------------------------------------
# Two repositories have to agree on one path, the same way they already agree on
# the search palette's summoning command. If they drift, greetd starts a program
# that is not there and the machine shows a black screen.
aq_greeter_helper='/usr/libexec/aquarius-greeter-info'
if grep -q "${aq_greeter_helper}" greeter/GreeterState.qml; then
    pass "the login screen calls ${aq_greeter_helper}"
else
    fail "greeter/GreeterState.qml no longer calls ${aq_greeter_helper}." \
         "The AquariusOS image installs the helper at exactly that path."
fi

# ==============================================================================
# THE LOGO MENU (components/bar/LogoMenu.qml) — checks 33
# ==============================================================================

# ------------------------------------------------------------------------------
echo ""
echo "=== 33. the Aquarius (logo) menu holds together ==="
# ------------------------------------------------------------------------------
# Clicking the Aquarius mark opens a shell-drawn dropdown (R6, 2026-09-06). It is
# a keyboard-navigable layer-shell overlay like Flow Search, so the same three
# things have to be true of it: its files are there, it obeys the one-overlay-at-
# a-time rule, and every item it offers names a real command. The last part is
# what a cheap check can genuinely protect — a menu item that launches the wrong
# thing, or a settings panel id that was renamed, is exactly the sort of typo
# that draws perfectly and does nothing.

for aq_file in \
    components/bar/LogoMenu.qml \
    components/bar/MenuRow.qml \
    docs/logo-menu.md
do
    if [ -f "${aq_file}" ]; then
        pass "${aq_file}"
    else
        fail "${aq_file} is missing."
    fi
done

# It is an exclusive overlay, so it must register/unregister/claim like the
# other three and import the services singleton. Comments are stripped first, the
# same way section 27 does, because the file explains all of this at length.
aq_logo_code="$(sed -E 's,//.*,,' components/bar/LogoMenu.qml)"

for aq_call in register unregister claim; do
    if printf '%s' "${aq_logo_code}" | grep -qF "Overlays.${aq_call}("; then
        pass "LogoMenu.qml calls Overlays.${aq_call}()"
    else
        fail "components/bar/LogoMenu.qml does not call Overlays.${aq_call}()." \
             "It takes the keyboard, so it has to close the other overlays and" \
             "be closable by them. See services/Overlays.qml."
    fi
done

if printf '%s' "${aq_logo_code}" | grep -qE '^\s*import\s+"\.\./\.\./services"'; then
    pass "LogoMenu.qml imports services/"
else
    fail "components/bar/LogoMenu.qml uses Overlays but does not import services/."
fi

if printf '%s' "${aq_logo_code}" | grep -qE '^\s*import\s+QtQuick'; then
    pass "LogoMenu.qml imports QtQuick (for Component.onCompleted)"
else
    fail "components/bar/LogoMenu.qml uses Component.onCompleted without QtQuick."
fi

# Every menu item, by the exact command it runs. The label a person reads and the
# command a click sends are declared in the same file; this checks the command,
# which is the half that can be silently wrong.
#
# The two Settings items no longer name a program at all: they call the shell's
# one Settings launcher, which is what puts `env XDG_CURRENT_DESKTOP=GNOME` in
# front of gnome-control-center so the app does not exit the instant it starts.
# Section 34b is the check that the launcher itself is right, and that nobody has
# quietly gone back to launching that program by hand from here.
#   description : the substring that must appear in LogoMenu.qml
aq_logo_actions=(
    'About This PC : SettingsLauncher.open("system", ["about"])'
    'System Settings : SettingsLauncher.open("")'
    'Check for Update : /usr/libexec/aquarius-updater'
    'Log Out : "loginctl", "terminate-session"'
    'Sleep : "systemctl", "suspend"'
    'Restart : "systemctl", "reboot"'
    'Power Off : "systemctl", "poweroff"'
)
for aq_row in "${aq_logo_actions[@]}"; do
    aq_desc="${aq_row%% : *}"
    aq_needle="${aq_row#* : }"
    if grep -qF "${aq_needle}" components/bar/LogoMenu.qml; then
        pass "the logo menu's '${aq_desc}' runs the right command"
    else
        fail "components/bar/LogoMenu.qml has no '${aq_desc}' action." \
             "Expected to find:  ${aq_needle}"
    fi
done

# ...and it must not build that command line itself again. Every Settings launch
# in the shell goes through the singleton, because the env prefix is the whole
# fix and a second copy of the launch is a second place to forget it.
if grep -qF 'gnome-control-center' components/bar/LogoMenu.qml; then
    fail "components/bar/LogoMenu.qml names gnome-control-center itself." \
         "The Settings launch belongs to services/SettingsLauncher.qml alone —" \
         "it is the only place that puts env XDG_CURRENT_DESKTOP=GNOME in front" \
         "of it, and without that prefix the app exits before it draws anything."
else
    pass "LogoMenu.qml leaves the Settings launch to the launcher"
fi

# The updater item is guarded: it is only offered when the file is executable, so
# the menu never launches something that is not installed.
if grep -qF '"test", "-x"' components/bar/LogoMenu.qml \
   && grep -q 'updaterAvailable' components/bar/LogoMenu.qml; then
    pass "the 'Check for Update' item is guarded by a [ -x ] probe"
else
    fail "components/bar/LogoMenu.qml no longer guards the updater with a" \
         "'test -x' probe and an updaterAvailable flag. Without it the menu can" \
         "offer to launch an updater that is not on the machine."
fi

# The IPC door, so a keybind or a script can open the Aquarius menu.
if grep -q 'target: "logomenu"' components/bar/LogoMenu.qml; then
    pass "LogoMenu.qml registers the IPC target 'logomenu'"
else
    fail "components/bar/LogoMenu.qml no longer registers IPC target \"logomenu\"."
fi

# The bar's mark opens the menu, not the search palette any more.
if grep -q 'logoMenu.toggle()' shell.qml; then
    pass "shell.qml opens the logo menu from the Aquarius mark"
else
    fail "shell.qml no longer wires the Aquarius mark to logoMenu.toggle()." \
         "Clicking the mark is meant to open the Aquarius menu (R6)."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 34. the Quick Settings tiles' detail arrows open the right panels ==="
# ------------------------------------------------------------------------------
# Wi-Fi, Bluetooth and Performance grew a small chevron (R6, 2026-09-06) that
# opens that thing's full page in Settings — a SEPARATE hit target from the
# switch. The failure a check can catch is the chevron opening the wrong panel,
# or a tile that should have one not having one.

# The shared machinery on QsTile.
for aq_bit in 'property bool hasDetail' 'signal detailRequested()' 'glyph: "chevron"'; do
    if grep -qF "${aq_bit}" components/quicksettings/QsTile.qml; then
        pass "QsTile.qml has: ${aq_bit}"
    else
        fail "components/quicksettings/QsTile.qml is missing: ${aq_bit}" \
             "The detail chevron is drawn by QsTile and opened by each tile."
    fi
done

# Each tile that has a page behind it, and the panel it opens.
#   file : the gnome-control-center panel id it must open
aq_detail_tiles=(
    'components/quicksettings/TileWifi.qml : SettingsLauncher.open("wifi")'
    'components/quicksettings/TileBluetooth.qml : SettingsLauncher.open("bluetooth")'
    'components/quicksettings/TilePowerProfile.qml : SettingsLauncher.open("power")'
)
for aq_row in "${aq_detail_tiles[@]}"; do
    aq_tile="${aq_row%% : *}"
    aq_panel="${aq_row#* : }"
    if grep -q 'hasDetail: true' "${aq_tile}" \
       && grep -qF "${aq_panel}" "${aq_tile}"; then
        pass "$(basename "${aq_tile}") opens its Settings panel"
    else
        fail "${aq_tile} does not set hasDetail:true and open ${aq_panel}." \
             "Its chevron is meant to open that gnome-control-center panel," \
             "through services/SettingsLauncher.qml — see section 34b for why" \
             "it may not run that program directly."
    fi

    # A tile that imports services/ is a tile that can reach the singleton. This
    # is the failure QML reports as "SettingsLauncher is not defined", at the
    # moment the chevron is clicked and not before.
    if grep -qE '^\s*import\s+"\.\./\.\./services"' "${aq_tile}"; then
        pass "$(basename "${aq_tile}") imports services/"
    else
        fail "${aq_tile} calls SettingsLauncher without importing services/."
    fi
done

# ------------------------------------------------------------------------------
echo ""
echo "=== 34b. one place opens Settings, and it fixes XDG_CURRENT_DESKTOP ==="
# ------------------------------------------------------------------------------
# THIS SECTION EXISTS BECAUSE OF A BUG THAT MADE FIVE THINGS DO NOTHING AT ALL.
#
# Bench, 2026-09-06, Royce: "System Settings still doesn't open. Nor does its
# icon in the dock. About This PC also doesn't work. Quick settings arrows are
# there but don't open into settings."
#
# One cause behind all of them, and it is not in this repository.
# gnome-control-center checks which desktop it was started under
# (shell/cc-application.c, is_supported_desktop()): it reads XDG_CURRENT_DESKTOP,
# splits it on colons, and unless one of the names is GNOME or Unity it prints
#
#     Running gnome-control-center is only supported under GNOME and Unity,
#     exiting
#
# and exits 1. The Aquarius session sets that variable to
# aquarius-labwc:aquarius:wlroots on purpose — it is how xdg-desktop-portal finds
# the right portals.conf — so every launch died instantly and silently.
#
# The fix is per-launch: `env XDG_CURRENT_DESKTOP=GNOME gnome-control-center`,
# in ONE file, services/SettingsLauncher.qml. This section checks that the file
# still says that, and that no component has gone back to launching the program
# by hand — because a second copy of the launch is a second copy that can be
# missing the prefix, and that failure shows up as a click that does nothing.

if [ -f services/SettingsLauncher.qml ]; then
    pass "services/SettingsLauncher.qml"
else
    fail "services/SettingsLauncher.qml is missing." \
         "It is the shell's only door to the Settings app."
fi

# The prefix itself, in the exact three pieces execDetached is handed. Comments
# are stripped first: the file explains all of this at length and quotes the
# error message while doing it.
aq_launcher_code="$(sed -E 's,//.*,,' services/SettingsLauncher.qml)"

for aq_bit in '"env"' '"XDG_CURRENT_DESKTOP=GNOME"' '"gnome-control-center"'; do
    if printf '%s' "${aq_launcher_code}" | grep -qF "${aq_bit}"; then
        pass "SettingsLauncher.qml's launch argv contains ${aq_bit}"
    else
        fail "services/SettingsLauncher.qml no longer passes ${aq_bit}." \
             "The launch must be:  env XDG_CURRENT_DESKTOP=GNOME" \
             "gnome-control-center [panel]. Without the env prefix the app" \
             "exits before it draws anything, which is the bug this file exists" \
             "to fix."
    fi
done

if printf '%s' "${aq_launcher_code}" | grep -qF 'argvPrefix'; then
    pass "SettingsLauncher.qml keeps the prefix as one named property"
else
    fail "services/SettingsLauncher.qml no longer has an argvPrefix property." \
         "The prefix is the one fact this file holds; keep it named."
fi

if printf '%s' "${aq_launcher_code}" | grep -qF 'Quickshell.execDetached('; then
    pass "SettingsLauncher.qml launches with execDetached"
else
    fail "services/SettingsLauncher.qml no longer uses Quickshell.execDetached." \
         "A launched application must outlive a shell reload."
fi

if printf '%s' "${aq_launcher_code}" | grep -qE 'function\s+open\s*\('; then
    pass "SettingsLauncher.qml offers open(panel)"
else
    fail "services/SettingsLauncher.qml no longer offers an open(panel) function." \
         "Every caller in the shell calls it."
fi

# THE SECOND HALF OF THE SAME BENCH REPORT (2026-09-06). With the env prefix in,
# "About This PC" opened the Settings app — on the System panel's FRONT page,
# which is a list of rows one of which says About. Not what the item claims.
#
# gnome-control-center takes a page inside a panel as a further command-line
# word. Its own source, in three steps:
#
#   shell/cc-application.c, cc_application_command_line():
#       start_id = start_panels[0];                       <- word 0 is the panel
#       for (i = 1; start_panels[i] != NULL; i++)          <- words 1.. become
#           g_variant_builder_add (&builder, "v", ...);       "parameters"
#       cc_window_set_active_panel_from_id (self->window, start_id, parameters, &err)
#
#   shell/cc-window.c, set_active_panel_from_id():
#       g_object_set (G_OBJECT (self->current_panel), "parameters", parameters, NULL);
#
#   shell/cc-panel.c, cc_panel_set_property(), case PROP_PARAMETERS:
#       g_variant_get_child (parameters, 0, "v", &v);
#       if (g_variant_is_of_type (v, G_VARIANT_TYPE_STRING))
#           set_subpage (CC_PANEL (object), g_variant_get_string (v, NULL));
#
# and panels/system/cc-system-panel.c, cc_system_panel_init(), registers the
# names: about, datetime, region, remote-desktop, users. So the command form is
#
#     gnome-control-center system about
#
# and in this shell that is SettingsLauncher.open("system", ["about"]). These two
# checks are what stops the second argument being dropped again — losing it is
# not a crash, it is a menu item that quietly opens the wrong page.

if printf '%s' "${aq_launcher_code}" | grep -qE 'function\s+open\s*\(\s*panel[^)]*,'; then
    pass "SettingsLauncher.qml's open() takes parameters as well as a panel"
else
    fail "services/SettingsLauncher.qml's open() no longer takes a second" \
         "argument. It must be open(panel, parameters), where parameters are" \
         "the words gnome-control-center passes on to the panel — that is how" \
         "a page INSIDE a panel is asked for, and it is how About This PC" \
         "reaches the About page rather than the System panel's front page."
fi

if grep -qF 'SettingsLauncher.open("system", ["about"])' components/bar/LogoMenu.qml; then
    pass "About This PC opens the About page itself (system + about)"
else
    fail "components/bar/LogoMenu.qml no longer opens Settings on the About" \
         "page. Expected:  SettingsLauncher.open(\"system\", [\"about\"])" \
         "\"system\" on its own opens the System panel's front page, which is" \
         "a list of rows — the bench complaint of 2026-09-06. \"about\" is the" \
         "subpage name registered in panels/system/cc-system-panel.c."
fi

# THE GUARD THAT MATTERS MOST. No component may name that program. If one does,
# it is building its own launch, and the odds are it is building the bare one
# that dies. The session's labwc menu is the single documented exception and it
# is not under components/ — it is XML, drawn by the compositor, and cannot call
# into QML at all; section 36 checks that it carries its own copy of the prefix.
# Comments are stripped first, per file: several components explain this trap at
# length and have to be able to name the program while doing it. What may not
# appear is a line of CODE that names it.
aq_gcc_offenders=""
while IFS= read -r aq_qml; do
    if sed -E 's,//.*,,' "${aq_qml}" | grep -qF 'gnome-control-center'; then
        echo "       ${aq_qml}"
        aq_gcc_offenders="${aq_gcc_offenders} ${aq_qml}"
    fi
done < <(find components -name '*.qml' | sort)

if [ -n "${aq_gcc_offenders}" ]; then
    fail "a component names gnome-control-center itself." \
         "Every Settings launch goes through services/SettingsLauncher.qml," \
         "which is the only place that puts env XDG_CURRENT_DESKTOP=GNOME in" \
         "front of it. A bare execDetached([\"gnome-control-center\", ...]) is" \
         "exactly the bug that made five different clicks do nothing on" \
         "2026-09-06: the program starts, reads the wrong desktop name, and" \
         "exits before a window exists."
else
    pass "no component launches gnome-control-center by hand"
fi

# The .desktop-entry road to the same program. The dock and the search palette
# launch applications by running their desktop entry, and Settings' entry runs
# the very same command — so both ask the launcher first. Losing this is a
# Settings icon that flashes and does nothing, which is half of the bench report.
for aq_row in \
    'components/dock/DockItem.qml : the dock tile' \
    'components/search/SearchEngine.qml : the search palette'
do
    aq_file="${aq_row%% : *}"
    aq_what="${aq_row#* : }"
    if grep -qF 'SettingsLauncher.ownsDesktopEntry(' "${aq_file}"; then
        pass "${aq_what} asks the launcher before running a desktop entry"
    else
        fail "${aq_file} runs a .desktop entry without asking the launcher." \
             "Settings' own entry runs gnome-control-center, so launching it" \
             "the ordinary way opens nothing at all. Guard execute() with" \
             "SettingsLauncher.ownsDesktopEntry(entry)."
    fi
done

# ------------------------------------------------------------------------------
echo ""
echo "=== 35. the dock reads a live list of mounted drives ==="
# ------------------------------------------------------------------------------
# The dashed "+" at the end of the dock was replaced (R6, 2026-09-06) by a live
# list of the external drives that are mounted right now. This checks the files
# are there, that the list is read through a standard route rather than a
# compositor hack, that opening and unmounting go through the documented commands,
# and that the "+" tile is genuinely no longer instantiated.

for aq_file in \
    components/dock/DockDrives.qml \
    components/dock/DockDrive.qml
do
    if [ -f "${aq_file}" ]; then
        pass "${aq_file}"
    else
        fail "${aq_file} is missing."
    fi
done

# The list is read by watching the udisks2 mount root with a Qt FolderListModel —
# a standard, compositor-agnostic route (see the header of DockDrives.qml for why
# this rather than a D-Bus binding the shipped Quickshell does not have).
if grep -q 'FolderListModel' components/dock/DockDrives.qml \
   && grep -q '/run/media/' components/dock/DockDrives.qml; then
    pass "DockDrives.qml reads mounts from the udisks2 mount root"
else
    fail "components/dock/DockDrives.qml no longer reads the mount list." \
         "It is meant to watch /run/media/<user> with a FolderListModel."
fi

# Opening a drive goes to the file manager; unmounting takes the GVfs/GIO road,
# which is the one unmount that works from a mount path alone.
if grep -qF '"xdg-open"' components/dock/DockDrive.qml; then
    pass "DockDrive.qml opens a drive in the file manager"
else
    fail "components/dock/DockDrive.qml no longer opens the drive (xdg-open)."
fi
if grep -qF '"gio", "mount", "-u"' components/dock/DockDrive.qml; then
    pass "DockDrive.qml unmounts through GVfs/GIO"
else
    fail "components/dock/DockDrive.qml no longer unmounts with 'gio mount -u'."
fi

# The drive tile draws the drive glyph, which therefore has to exist in the
# glyph table (section 20 only scans quicksettings/ and bar/, so the dock's use
# of it is checked here instead).
if grep -q 'glyph: "drive"' components/dock/DockDrive.qml; then
    pass "DockDrive.qml uses the 'drive' glyph"
    if grep -qE '^\s*"drive"\s*:\s*\{' components/quicksettings/QsGlyph.qml; then
        pass "QsGlyph.qml has a 'drive' glyph"
    else
        fail "components/quicksettings/QsGlyph.qml has no 'drive' glyph," \
             "but DockDrive.qml asks for one."
    fi
fi

# The drives list is drawn where the "+" used to be, and the "+" is gone.
if grep -q 'DockDrives.qml' components/dock/Dock.qml; then
    pass "Dock.qml draws the drives list"
else
    fail "components/dock/Dock.qml no longer draws DockDrives."
fi
if grep -qE '^\s*DockAddTile\s*\{' components/dock/Dock.qml; then
    fail "components/dock/Dock.qml still instantiates DockAddTile." \
         "The '+' was replaced by the drives list; the file stays in the repo" \
         "(section 18 still lists it) but the dock must not draw it any more."
else
    pass "Dock.qml no longer instantiates the '+' tile"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 35b. the drives list can never list the wrong directory ==="
# ------------------------------------------------------------------------------
# THIS SECTION EXISTS BECAUSE OF A BUG THAT PUT THIRTY WRONG TILES IN THE DOCK.
#
# Bench, 2026-09-06: with nothing plugged into the machine, the right end of the
# dock drew "a bunch of random folders instead of external drives" — they were
# the folders in the user's home directory.
#
# The cause is in Qt, in qquickfolderlistmodel.cpp, componentComplete():
#
#     QString localPath = QQmlFile::urlToLocalFileOrQrc(d->currentDir);
#     if (localPath.isEmpty() || !QDir(localPath).exists())
#         setFolder(QUrl::fromLocalFile(QDir::currentPath()));
#
# When the folder does not exist AT CREATION, FolderListModel does not go empty —
# it silently lists the process's working directory instead, which for the shell
# is the user's home. And /run/media/<user> does not exist most of the time:
# udisks2 makes it on the first mount and removes it after the last unmount.
#
# So the rule this section enforces is: the shell may only point a
# FolderListModel at a directory it has just seen exist. DockDrives.qml does that
# with a chain — /run (always there) tells it whether /run/media exists, which
# tells it whether /run/media/<user> exists — with each level created by a Loader
# and destroyed when its directory goes, plus a read-back health check on each
# created model as the net underneath the reasoning.
#
# These are grep-level checks, like the rest of this file. They cannot prove the
# chain works; they can prove nobody has quietly put the constant-bound model
# back, which is the shape of the bug.

aq_drives_code="$(sed -E 's,//.*,,' components/dock/DockDrives.qml)"

# The always-present root is watched unguarded; the two below it are not. These
# two checks read the FILE, not the comment-stripped copy above: a file:// URL
# contains "//" and the comment stripper would cut the path in half. They match
# the property declarations rather than a loose mention, so a path named in prose
# cannot stand in for the real thing.
if grep -qE 'runRoot:[[:space:]]*"file:///run"' components/dock/DockDrives.qml; then
    pass "DockDrives.qml starts from /run, which always exists"
else
    fail "components/dock/DockDrives.qml no longer watches file:///run." \
         "That is the one directory a FolderListModel may be pointed at" \
         "unconditionally, and the whole chain hangs off what it sees."
fi

if grep -qE 'mediaBase:[[:space:]]*"file:///run/media"' \
        components/dock/DockDrives.qml; then
    pass "DockDrives.qml watches the mount root as its own level"
else
    fail "components/dock/DockDrives.qml no longer names file:///run/media as a" \
         "level of its own. /run/media is created by udisks2 on the first mount" \
         "and removed after the last unmount, so it has to be watched rather" \
         "than assumed."
fi

# The two lower models are built from Components by Loaders, which is the only
# way to have a FolderListModel that does not exist yet: the type has no switch
# for "do not list anything", so not creating it is the switch.
if printf '%s' "${aq_drives_code}" | grep -qF 'sourceComponent:'; then
    pass "DockDrives.qml creates its lower models from Components"
else
    fail "components/dock/DockDrives.qml no longer creates its models from" \
         "Components. A FolderListModel that is simply declared is created at" \
         "start-up, before any drive is plugged in, which is the whole bug."
fi

# Two Loaders, two levels: /run/media and /run/media/<user>. One Loader means a
# level is being created unguarded again.
aq_drive_loaders="$(printf '%s' "${aq_drives_code}" \
    | grep -cE '^[[:space:]]*Loader[[:space:]]*\{' || true)"
if [ "${aq_drive_loaders}" -ge 2 ]; then
    pass "DockDrives.qml builds the nested watch (${aq_drive_loaders} Loaders)"
else
    fail "components/dock/DockDrives.qml has ${aq_drive_loaders} Loader(s)," \
         "and the nested watch needs two: one for /run/media and one for" \
         "/run/media/<user>. Each level must be created only while its own" \
         "directory exists and torn down when it goes."
fi

# Each created model checks, once it is complete, that `folder` reads back as
# the directory that was asked for. That is a direct question about whether Qt's
# fallback fired, because the fallback works by writing into that property.
if printf '%s' "${aq_drives_code}" | grep -qF '.folder' \
   && printf '%s' "${aq_drives_code}" | grep -qF 'healthy'; then
    pass "DockDrives.qml reads its folder back and marks the model healthy or not"
else
    fail "components/dock/DockDrives.qml no longer reads model.folder back." \
         "That read-back is the belt to the chain's braces: if Qt substituted" \
         "the working directory, the folder property is where it says so."
fi

if printf '%s' "${aq_drives_code}" | grep -qF 'console.warn'; then
    pass "DockDrives.qml says so out loud when the listing is not trusted"
else
    fail "components/dock/DockDrives.qml no longer warns when its model is" \
         "listing a directory nobody asked for. A silently empty dock is how" \
         "this bug hid for a day."
fi

# hasDrives is what Dock.qml believes. An unhealthy model must make it false, so
# a distrusted listing draws no separator and no tiles.
if printf '%s' "${aq_drives_code}" | grep -A6 'property bool hasDrives' \
        | grep -qF 'healthy'; then
    pass "hasDrives is false unless the model passed its health check"
else
    fail "components/dock/DockDrives.qml computes hasDrives without consulting" \
         "the health check. A model that fell back to the home directory would" \
         "report drives, which is exactly what the dock drew on 2026-09-06."
fi

# THE RULE ITSELF, stated as a grep: no FolderListModel anywhere in the shell may
# have its folder bound to a path that was not just verified. In practice that
# means the only literal folder assignments allowed are the /run ones and a
# property built from them, and every other one has to come from a checked
# property. Anything pointing straight into a home directory is the old bug.
if grep -rn --include='*.qml' -E 'folder\s*:\s*"file:///(home|Users)' . \
        > /dev/null 2>&1; then
    grep -rn --include='*.qml' -E 'folder\s*:\s*"file:///(home|Users)' . || true
    fail "a QML file points a folder model straight at a home directory." \
         "The shell only lists directories it has verified exist, and it never" \
         "lists somebody's home. See the header of DockDrives.qml."
else
    pass "no folder model is pointed at a home directory"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 36. the desktop right-click menu is wired up ==="
# ------------------------------------------------------------------------------
# Right-clicking the empty desktop opens the Aquarius menu, drawn by labwc from
# menu.xml and bound in rc.xml (R6, 2026-09-06). menu.xml fails SILENTLY when
# malformed — labwc just shows nothing — so it is parsed here the same way rc.xml
# is, and its items are checked.

if python3 -c "import xml.etree.ElementTree as e,sys; e.parse(sys.argv[1])" \
        session/labwc/menu.xml 2>/dev/null; then
    pass "session/labwc/menu.xml is well-formed XML"
else
    fail "session/labwc/menu.xml is not well-formed XML."
fi

if grep -q 'id="root-menu"' session/labwc/menu.xml; then
    pass "menu.xml defines the root menu"
else
    fail "session/labwc/menu.xml does not define a menu with id=\"root-menu\"." \
         "rc.xml binds right-click to ShowMenu menu=\"root-menu\"; the names must" \
         "match or the menu is empty."
fi

# The items the menu must offer, by the command each runs.
#
# The two Settings lines carry `env XDG_CURRENT_DESKTOP=GNOME` in front of the
# program, and that prefix is not decoration: gnome-control-center reads that
# variable and exits immediately unless it names GNOME, which in an Aquarius
# session it deliberately does not (section 34b has the whole story). This menu
# is XML drawn by labwc and cannot call into the shell's launcher, so it is the
# one place that spells the prefix out by hand — which is exactly why it needs
# checking. Take the prefix off and the item goes back to doing nothing.
#   description : substring that must be in menu.xml
aq_menu_items=(
    'Search : qs ipc call search toggle'
    'System Settings : <command>env XDG_CURRENT_DESKTOP=GNOME gnome-control-center</command>'
    'Change Wallpaper : env XDG_CURRENT_DESKTOP=GNOME gnome-control-center background'
    'Sleep : systemctl suspend'
    'Restart : systemctl reboot'
    'Power Off : systemctl poweroff'
)
for aq_row in "${aq_menu_items[@]}"; do
    aq_desc="${aq_row%% : *}"
    aq_needle="${aq_row#* : }"
    if grep -qF "${aq_needle}" session/labwc/menu.xml; then
        pass "the desktop menu offers '${aq_desc}'"
    else
        fail "session/labwc/menu.xml has no '${aq_desc}' item." \
             "Expected to find:  ${aq_needle}"
    fi
done

# Log Out reuses labwc's own Exit — the same teardown as Super+Shift+E — rather
# than a second one invented here.
if grep -q 'name="Exit"' session/labwc/menu.xml; then
    pass "the desktop menu's Log Out uses labwc's own Exit"
else
    fail "session/labwc/menu.xml no longer offers Log Out via labwc's Exit."
fi

# This file has a twin in the os-image repo — what an installed machine actually
# reads is system_files/usr/share/aquarius/labwc/menu.xml — and the two drift
# apart silently. The file has to SAY so, the same way the autostart file next to
# it does, because the person editing it is the only one who can keep them equal.
if grep -qF 'system_files/usr/share/aquarius/labwc/menu.xml' \
        session/labwc/menu.xml; then
    pass "menu.xml points at its os-image copy (change one, change both)"
else
    fail "session/labwc/menu.xml does not mention its os-image twin at" \
         "system_files/usr/share/aquarius/labwc/menu.xml. An installed machine" \
         "reads that copy, not this one, so a fix made here alone never ships." \
         "Say it in the file, as the autostart file does."
fi

# rc.xml has to actually bind a right-click to it, and keep labwc's own mouse
# defaults so window dragging still works.
if grep -q 'ShowMenu' session/labwc/rc.xml \
   && grep -q 'menu="root-menu"' session/labwc/rc.xml; then
    pass "rc.xml binds a click to the root menu"
else
    fail "session/labwc/rc.xml does not bind anything to ShowMenu root-menu." \
         "Without it the menu.xml is never shown."
fi
if grep -Pzoq '(?s)<mouse>.*<default\s*/>.*</mouse>' session/labwc/rc.xml \
   2>/dev/null || grep -A3 '<mouse>' session/labwc/rc.xml | grep -q '<default'; then
    pass "rc.xml keeps labwc's default mouse bindings"
else
    fail "session/labwc/rc.xml defines <mouse> bindings without <default />." \
         "That throws away window dragging, edge-resize and click-to-focus." \
         "Add <default /> at the top of the <mouse> section."
fi

# THE MENU'S FONT IS IN rc.xml, NOT IN THE THEMERC. labwc splits one look across
# two files: colours come from themerc-override, fonts come from rc.xml's
# <theme> section. Lose these and the desktop menu is drawn in "sans" while the
# shell menu two inches above it is drawn in Inter — the same menu in two
# typefaces, which is worse than either on its own.
#
# Inter is what theme/Theme.qml picks as `fontBody`, and labwc's <size> is in
# pixels (labwc-config(5): "Font size in pixels"), the same unit Theme uses, so
# 19 here is literally Theme.fsBody.
if python3 - "$(printf '%s' session/labwc/rc.xml)" <<'AQ_PY'
import sys, xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
wanted = {"MenuItem", "MenuHeader", "ActiveWindow", "InactiveWindow"}
found = set()

for theme in root.iter("theme"):
    for font in theme.iter("font"):
        place = font.get("place")
        name = font.findtext("name") or font.get("name") or ""
        size = font.findtext("size") or font.get("size") or ""
        if place in wanted and name.strip() == "Inter" and size.strip().isdigit():
            found.add(place)

sys.exit(0 if found == wanted else 1)
AQ_PY
then
    pass "rc.xml draws labwc's menu and title bars in the shell's own font"
else
    fail "session/labwc/rc.xml does not set Inter for all four <theme><font>" \
         "places (MenuItem, MenuHeader, ActiveWindow, InactiveWindow)." \
         "labwc takes colours from themerc-override and FONTS from here, so" \
         "without these the desktop menu is drawn in whatever 'sans' resolves" \
         "to while the shell's own menu is drawn in Inter."
fi

# The two copies of rc.xml — this one and the os-image's — are meant to differ
# only in their comments, and the shell's is deliberately the superset. The
# terminal keybind is the line that was only in the OS's copy until 2026-09-06.
# On a machine with no ptyxis it is inert; what it buys is that `diff` between
# the two files stops showing a real difference.
if grep -qF '<command>ptyxis</command>' session/labwc/rc.xml \
   && grep -qF 'key="W-Return"' session/labwc/rc.xml; then
    pass "rc.xml binds a terminal on Super+Return, as the os-image copy does"
else
    fail "session/labwc/rc.xml has no W-Return keybind running ptyxis." \
         "The os-image copy has one, and this file is meant to be the superset" \
         "so the two can be kept content-identical apart from comments." \
         "On a machine without ptyxis the keybind is simply inert."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 37. right-clicking an app in the dock opens a menu ==="
# ------------------------------------------------------------------------------
# Bench, 2026-09-06, Royce: "right click on the apps does nothing." The drives at
# the other end of the same dock already had a menu; the app tiles ignored the
# right button entirely.
#
# The menu is DockItem's, drawn the way DockDrive's is — a PopupWindow with
# grabFocus, hanging above the tile — out of the same MenuRow the Aquarius menu
# uses, so the shell's three menus are one design. These are grep-level checks:
# they confirm the wiring is present and named the way the rest of the shell
# names it. Whether it draws, and whether Esc reaches it through a compositor
# grab, is bench work.

aq_dock_item="components/dock/DockItem.qml"
aq_dock_item_code="$(sed -E 's,//.*,,' "${aq_dock_item}")"

# The right button has to be accepted at all. This is the whole bug in one line:
# before this change the MouseArea took Left and Middle and nothing else, so the
# click never reached any code.
if printf '%s' "${aq_dock_item_code}" | grep -qF 'Qt.RightButton'; then
    pass "the dock tile accepts a right-click"
else
    fail "${aq_dock_item} does not accept Qt.RightButton." \
         "Its MouseArea must list it in acceptedButtons AND act on it —" \
         "without both, right-clicking an app tile does nothing at all, which" \
         "is the bench report of 2026-09-06."
fi

# Drawn by the shell, in the shell's own menu row, anchored above the tile —
# the same three decisions DockDrive made.
for aq_bit in 'PopupWindow' 'grabFocus: true' 'MenuRow' 'edges: Edges.Top'; do
    if printf '%s' "${aq_dock_item_code}" | grep -qF "${aq_bit}"; then
        pass "the dock menu uses: ${aq_bit}"
    else
        fail "${aq_dock_item} no longer has '${aq_bit}'." \
             "The app menu reuses DockDrive.qml's pattern exactly: a" \
             "PopupWindow with grabFocus, anchored above the tile, with" \
             "MenuRow drawing the rows so it matches the Aquarius menu."
    fi
done

# Esc, and the import that MenuRow needs. A dock file reaching into components/bar
# is not an accident — MenuRow lives there because the logo menu owns it.
if printf '%s' "${aq_dock_item_code}" | grep -qF 'Keys.onEscapePressed'; then
    pass "the dock menu closes on Esc"
else
    fail "${aq_dock_item} does not handle Escape." \
         "Every menu in this shell closes on Esc."
fi

if grep -qE '^\s*import\s+"\.\./bar"' "${aq_dock_item}"; then
    pass "${aq_dock_item} imports ../bar for MenuRow"
else
    fail "${aq_dock_item} uses MenuRow without importing \"../bar\"." \
         "QML fails at load with 'MenuRow is not a type'."
fi

# The three actions, by what each one calls. Losing any of them is a menu row
# that opens and does nothing.
#   description : what must appear in DockItem.qml
aq_dock_menu_actions=(
    'Open / New Window : root.launch()'
    'Keep in Dock : root.config.pin(root.pinId)'
    'Remove from Dock : root.config.unpin(root.pinId)'
    'Quit : root.quitAll()'
)
for aq_row in "${aq_dock_menu_actions[@]}"; do
    aq_desc="${aq_row%% : *}"
    aq_needle="${aq_row#* : }"
    if printf '%s' "${aq_dock_item_code}" | grep -qF "${aq_needle}"; then
        pass "the dock menu's '${aq_desc}' does something"
    else
        fail "${aq_dock_item} has no '${aq_desc}' action." \
             "Expected to find:  ${aq_needle}"
    fi
done

# QUIT, AND THE DELETE-WHILE-ITERATING TRAP. Closing a window makes the
# compositor drop it from ToplevelManager, which rebuilds the very list the loop
# is walking — so iterating the live list skips windows, and a five-window app
# ends up with two still open. That reads as Quit being unreliable rather than as
# a bug in a loop, which is the worst kind of bug to have. slice() first.
if printf '%s' "${aq_dock_item_code}" | grep -qE 'root\.windows\.slice\(\)'; then
    pass "Quit copies the window list before closing anything"
else
    fail "${aq_dock_item}'s quitAll() walks root.windows directly." \
         "close() makes the compositor drop the window, which rebuilds that" \
         "list mid-loop and skips the ones after it. Take a copy first:" \
         "const open = root.windows.slice();"
fi

if printf '%s' "${aq_dock_item_code}" | grep -qE '\.close\(\)'; then
    pass "Quit closes through the Wayland toplevel handle"
else
    fail "${aq_dock_item} does not call close() on its toplevels." \
         "Quit goes through the standard wlr-foreign-toplevel handle, like" \
         "activate() and minimized next to it — never a compositor-specific" \
         "back door."
fi

# The tile must be HANDED the config. DockConfig is not a singleton (there is one
# for the whole shell, in Dock.qml), so a delegate cannot see it by id. If this
# line goes, the pin rows quietly stop being offered — `canPin` goes false and
# the menu simply has two items instead of three, with nothing said anywhere.
if grep -qF 'config: dockConfig' components/dock/Dock.qml; then
    pass "Dock.qml hands each tile the shared DockConfig"
else
    fail "components/dock/Dock.qml no longer passes config: dockConfig to" \
         "DockItem. Without it root.canPin is false and the Keep in Dock /" \
         "Remove from Dock rows silently vanish from the menu."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 37b. the dock can write the pinned list, carefully ==="
# ------------------------------------------------------------------------------
# DockConfig was read-only until 2026-09-06, and its header said so at length:
# the shell must not create files nobody asked for. That rule is intact — the
# only thing that writes is a person clicking "Keep in Dock" — but there is now a
# write, and it has two traps worth checking.

aq_dock_config="components/dock/DockConfig.qml"
aq_dock_config_code="$(sed -E 's,//.*,,' "${aq_dock_config}")"

for aq_fn in 'function pin(' 'function unpin(' 'function isPinned('; do
    if printf '%s' "${aq_dock_config_code}" | grep -qF "${aq_fn}"; then
        pass "DockConfig.qml offers ${aq_fn})"
    else
        fail "${aq_dock_config} no longer offers ${aq_fn})." \
             "The dock tile's right-click menu calls all three."
    fi
done

# writeAdapter(), not setText(). The adapter already holds the list in the exact
# shape the file wants; building JSON by hand here would be a second opinion
# about the format living three lines from the first.
if printf '%s' "${aq_dock_config_code}" | grep -qF 'writeAdapter()'; then
    pass "DockConfig.qml saves through the JsonAdapter"
else
    fail "${aq_dock_config} does not call writeAdapter()." \
         "The adapter holds the list already; serialising JSON by hand here" \
         "would be a second opinion about the format."
fi

# TRAP 1: reassignment, not push. Pushing onto the adapter's array changes it
# without the property system noticing, so the dock does not redraw until
# something unrelated happens to touch the binding.
if printf '%s' "${aq_dock_config_code}" | grep -qE 'adapter\.pinned\s*='; then
    pass "DockConfig.qml reassigns the list rather than mutating it"
else
    fail "${aq_dock_config} never assigns to adapter.pinned." \
         "Pushing onto the existing array changes it without notifying QML," \
         "so the dock would not redraw until something else touched it."
fi

# TRAP 2: the parent directory. FileView writes a file; it does not create the
# folder above it, and ~/.config/aquarius-shell/ does not exist on a machine
# where nobody has hand-edited the file. So the FIRST pin on a fresh install
# fails, and it fails silently unless something is listening.
if printf '%s' "${aq_dock_config_code}" | grep -qF 'onSaveFailed'; then
    pass "DockConfig.qml notices a failed save"
else
    fail "${aq_dock_config} does not handle onSaveFailed." \
         "FileView does not create the folder above the file, so the first" \
         "pin on a fresh machine fails — silently, unless this is here."
fi

if printf '%s' "${aq_dock_config_code}" | grep -qF '"mkdir", "-p"'; then
    pass "a failed save creates the folder and retries"
else
    fail "${aq_dock_config} does not create ~/.config/aquarius-shell on a" \
         "failed save. Without it the first pin on every fresh install is lost" \
         "the moment the shell restarts."
fi

# ...but only once. A second failure is a real problem — a read-only home, a full
# disk — and a retry loop would hide it behind a spinning shell.
if printf '%s' "${aq_dock_config_code}" | grep -qF 'triedCreatingFolder'; then
    pass "the folder is only created once per session"
else
    fail "${aq_dock_config} retries a failed save without a guard." \
         "One mkdir, one retry. A second failure means something real is" \
         "wrong and must be allowed to be reported, not retried forever."
fi

# AND NOTHING IS WRITTEN UNPROMPTED. The original rule — no file appears unless a
# person asked for one — is the reason this file was read-only for as long as it
# was, and it must survive the arrival of a write. A save call anywhere in a
# start-up path would break it.
if printf '%s' "${aq_dock_config_code}" \
        | grep -qE 'Component\.onCompleted.*(writeAdapter|save\()'; then
    fail "${aq_dock_config} writes the file at start-up." \
         "Nothing is written unless somebody clicks Keep in Dock or Remove" \
         "from Dock. A shell that creates files you did not ask for is a shell" \
         "you cannot predict — that is why this file was read-only until there" \
         "was a gesture that changed something."
else
    pass "DockConfig.qml never writes unless asked"
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 38. the app switcher is wired up end to end ==="
# ------------------------------------------------------------------------------
# The app switcher is the first feature in this shell whose behaviour depends on
# something OUTSIDE the shell being right: the five keybinds in labwc's rc.xml,
# and the fact that labwc's own switcher is switched off. Neither of those is
# QML, neither is checked by any other section, and both exist TWICE — once here
# and once in the os-image repository, which has its own copy of every labwc
# file. Getting one of the two wrong is the exact fault that cost two bench
# sessions on 6 September 2026.
#
# So this section checks the whole chain, in the order a keystroke travels it:
#
#   the key   -> rc.xml binds it, and to the right IPC line
#   the door  -> AppSwitcher.qml declares that IPC function
#   the panel -> it asks for the keyboard, which is how it sees the key COME UP
#   the list  -> it comes from the shared window protocol, not a private one
#   the docs  -> the release mechanism is written down, because it is the one
#                part of this nobody will guess from the code

aq_switcher="components/switcher/AppSwitcher.qml"
aq_switcher_model="components/switcher/SwitcherModel.qml"
aq_switcher_rc="session/labwc/rc.xml"

if [ ! -f "${aq_switcher}" ] || [ ! -f "${aq_switcher_rc}" ]; then
    fail "the app switcher's files are missing; skipping the rest of section 38."
else
    aq_switcher_code="$(sed -E 's,//.*,,' "${aq_switcher}")"

    # -- the IPC door ----------------------------------------------------------
    # Every function a keybind or a person can call. If one of these is renamed
    # without rc.xml being changed, the key silently does nothing — Quickshell
    # does not complain about a call to a function that is not there.
    for aq_fn in next prev down up go cancel cycle isOpen; do
        if printf '%s' "${aq_switcher_code}" | grep -qE "function ${aq_fn}\(\)"; then
            pass "AppSwitcher.qml answers 'switcher ${aq_fn}'"
        else
            fail "${aq_switcher} has no IpcHandler function ${aq_fn}()." \
                 "docs/app-switcher.md tells people to run" \
                 "'qs ipc call switcher ${aq_fn}', and rc.xml may bind it."
        fi
    done

    if printf '%s' "${aq_switcher_code}" | grep -qE 'target:\s*"switcher"'; then
        pass "AppSwitcher.qml's IpcHandler is called 'switcher'"
    else
        fail "${aq_switcher} does not declare 'target: \"switcher\"'." \
             "That name is the 'switcher' in 'qs ipc call switcher next', and" \
             "rc.xml has it written down five times."
    fi

    # -- the keyboard, which is the whole mechanism ----------------------------
    # This is not decoration. Exclusive keyboard interactivity is what makes
    # labwc hand this surface the keyboard, and holding the keyboard is the ONLY
    # reason the release of Command ever reaches the shell. Read the top of
    # AppSwitcher.qml, or docs/app-switcher.md, before touching either line.
    if printf '%s' "${aq_switcher_code}" | grep -q 'WlrKeyboardFocus.Exclusive'; then
        pass "AppSwitcher.qml asks for the keyboard exclusively"
    else
        fail "${aq_switcher} no longer asks for WlrKeyboardFocus.Exclusive." \
             "Without the keyboard it cannot see the modifier being released," \
             "and the panel would never commit — it would just sit there."
    fi

    if printf '%s' "${aq_switcher_code}" | grep -q 'Keys.onReleased'; then
        pass "AppSwitcher.qml watches for the modifier coming up"
    else
        fail "${aq_switcher} has no Keys.onReleased handler." \
             "That handler IS the feature: it is what 'let go of Command to go" \
             "to the app you picked' is made of."
    fi

    # Both profiles' modifiers, by every name Qt might report them under.
    for aq_key in Qt.Key_Meta Qt.Key_Super_L Qt.Key_Super_R Qt.Key_Alt; do
        if printf '%s' "${aq_switcher_code}" | grep -qF "${aq_key}"; then
            pass "AppSwitcher.qml commits on ${aq_key}"
        else
            fail "${aq_switcher} does not handle ${aq_key} being released." \
                 "Which name Qt reports depends on the keymap, and Alt is the" \
                 "Windows profile's modifier, so all four are listed on purpose."
        fi
    done

    # -- what it lists ---------------------------------------------------------
    if grep -q 'ToplevelManager' "${aq_switcher_model}"; then
        pass "SwitcherModel.qml lists windows from ToplevelManager"
    else
        fail "${aq_switcher_model} does not use ToplevelManager." \
             "The switcher and the dock must agree about what is running, and" \
             "the standardised wlr-foreign-toplevel protocol is how they do."
    fi

    # The dock, the switcher and the top bar must agree about which application
    # a window belongs to, and there is one file that decides. A second copy of
    # that logic is how a window ends up on one tile in the dock and a different
    # tile in the switcher.
    if grep -q 'AppIdentity' "${aq_switcher_model}"; then
        pass "SwitcherModel.qml identifies apps through AppIdentity"
    else
        fail "${aq_switcher_model} does not use services/AppIdentity.qml." \
             "Matching a window to an application is answered in one place." \
             "Read the header of that file before adding a second answer."
    fi

    if grep -qE 'heuristicLookup' "${aq_switcher_model}" \
            || grep -qE 'heuristicLookup' "${aq_switcher}"; then
        fail "the switcher looks applications up itself." \
             "services/AppIdentity.qml is the one place that does that, for the" \
             "dock and the top bar as well. Call it instead."
    else
        pass "the switcher does not carry its own copy of the app lookup"
    fi

    # -- the profile -----------------------------------------------------------
    # One question, asked once at first login. A second setting just for the
    # switcher would be a second thing to keep in step with the first.
    if printf '%s' "${aq_switcher_code}" | grep -q 'KeyProfile'; then
        pass "AppSwitcher.qml takes Mac-or-Windows from KeyProfile"
    else
        fail "${aq_switcher} does not read services/KeyProfile.qml." \
             "Mac style groups windows into applications and Windows style does" \
             "not. That answer belongs to 'aq keys', not to a second setting."
    fi

    # KeyProfile READS the file. `aq keys` WRITES it. Two writers of one settings
    # file is two programs that can disagree about what the setting is — the
    # os-image build already refuses that for the welcome screen, and the same
    # rule applies here.
    if grep -qE '(setText|writeAdapter|execDetached)' services/KeyProfile.qml; then
        fail "services/KeyProfile.qml writes something." \
             "'aq keys' owns ~/.config/aquarius/keys.conf, start to finish." \
             "The shell reads it and never writes it."
    else
        pass "KeyProfile.qml only ever reads keys.conf"
    fi

    if grep -q 'watchChanges' services/KeyProfile.qml; then
        pass "KeyProfile.qml notices 'aq keys' without a restart"
    else
        fail "services/KeyProfile.qml does not watch the file for changes." \
             "Running 'aq keys windows' has to change what the switcher lists" \
             "immediately; asking somebody to log out is not the deal."
    fi

    # -- the keybinds ----------------------------------------------------------
    # Five keys, and each one has to reach the right function. Checked as whole
    # command strings, because 'next' and 'prev' pointing at each other's
    # functions is a bug nobody would find by reading.
    aq_switcher_binds="W-Tab:next
W-S-Tab:prev
W-grave:cycle
A-Tab:next
A-S-Tab:prev"

    while IFS=: read -r aq_key aq_fn; do
        [ -n "${aq_key}" ] || continue
        if grep -qF "key=\"${aq_key}\"" "${aq_switcher_rc}"; then
            pass "rc.xml binds ${aq_key}"
        else
            fail "${aq_switcher_rc} does not bind ${aq_key}." \
                 "Both keyboard profiles are bound all the time, so that no key" \
                 "has to be rebound when somebody runs 'aq keys'."
        fi
        if grep -qF "qs ipc call switcher ${aq_fn}" "${aq_switcher_rc}"; then
            pass "rc.xml calls 'switcher ${aq_fn}'"
        else
            fail "${aq_switcher_rc} never calls 'qs ipc call switcher ${aq_fn}'." \
                 "That is the command ${aq_key} is supposed to run."
        fi
    done <<< "${aq_switcher_binds}"

    # labwc's own switcher, off. If it ever came back, two switchers would draw
    # at once and a screenshot would be very confusing to read.
    if python3 - "${aq_switcher_rc}" <<'PYTHON'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
osd = root.find('./windowSwitcher/osd')
if osd is None:
    print("       no <windowSwitcher><osd /> element at all")
    sys.exit(1)
if (osd.get('show') or '').lower() not in ('no', 'false'):
    print('       <osd show="%s"> — expected "no"' % osd.get('show'))
    sys.exit(1)
sys.exit(0)
PYTHON
    then
        pass "rc.xml switches labwc's own window switcher off"
    else
        fail "${aq_switcher_rc} does not switch labwc's own switcher off." \
             "It wants <windowSwitcher><osd show=\"no\" /></windowSwitcher>." \
             "Without it, a stray NextWindow binding would put a second" \
             "switcher on screen beside ours."
    fi

    # The one binding that must NEVER exist. Binding a modifier on its own makes
    # labwc swallow its press, and a swallowed press means a swallowed release —
    # which is the single event this whole feature is built on.
    if grep -qE 'key="(Super_L|Super_R|Alt_L|Alt_R)"' "${aq_switcher_rc}"; then
        fail "${aq_switcher_rc} binds a modifier key on its own." \
             "labwc does not forward the release of a key whose press it" \
             "swallowed, so this would stop the switcher ever committing." \
             "See docs/app-switcher.md."
    else
        pass "rc.xml leaves the bare modifier keys unbound, as it must"
    fi

    # -- the write-up ----------------------------------------------------------
    # The release mechanism is the one part of this that nobody will work out
    # from the code, and the spec asked for the two rejected approaches to be
    # written down as well as the chosen one.
    for aq_word in onRelease xremap Exclusive; do
        if grep -q "${aq_word}" docs/app-switcher.md; then
            pass "docs/app-switcher.md explains ${aq_word}"
        else
            fail "docs/app-switcher.md does not mention ${aq_word}." \
                 "All three approaches to seeing the modifier released — the" \
                 "two rejected and the one built — are meant to be written" \
                 "down, with what was checked to decide each."
        fi
    done
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
