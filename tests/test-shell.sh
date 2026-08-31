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
echo "=== 12. the dock's files exist ==="
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
echo "=== 13. every Theme.<something> a component asks for actually exists ==="
# ------------------------------------------------------------------------------
# This is the check the dock needed most, and it is worth having for everything.
#
# QML does not complain when you read a property that does not exist — it hands
# back `undefined`. `Theme.dockTileSize` misspelt as `Theme.dockTilesize` does
# not error; the tile silently comes out zero pixels wide and you are left
# hunting a layout bug that is really a typo. With no QML engine on this machine
# to catch it, a string comparison is the next best thing.
#
# It reads the property names declared in theme/Theme.qml and confirms that
# every `Theme.<name>` written anywhere else is one of them.

if python3 - <<'PYTHON'
import pathlib
import re
import sys

theme = pathlib.Path('theme/Theme.qml').read_text(encoding='utf-8')

# `property <type> <name>:` and `readonly property <type> <name>:`, plus
# functions and signals, which are reached the same way.
declared = set(re.findall(r'property\s+\w+(?:<\w+>)?\s+(\w+)\s*:', theme))
declared |= set(re.findall(r'function\s+(\w+)\s*\(', theme))
declared |= set(re.findall(r'signal\s+(\w+)\s*\(', theme))

bad = []
for path in sorted(pathlib.Path('.').rglob('*.qml')):
    if '.git' in path.parts or path == pathlib.Path('theme/Theme.qml'):
        continue
    text = path.read_text(encoding='utf-8')
    for line_number, line in enumerate(text.splitlines(), start=1):
        # Skip comment lines, which quote token names while explaining them.
        if line.lstrip().startswith('//'):
            continue
        for name in re.findall(r'\bTheme\.(\w+)', line):
            if name not in declared:
                bad.append((path, line_number, name))

if bad:
    for path, line_number, name in bad:
        print("  FAIL %s:%d uses Theme.%s, which Theme.qml does not declare"
              % (path, line_number, name))
    sys.exit(1)

print("  OK   every Theme.<name> in the repo is declared (%d available)"
      % len(declared))
PYTHON
then
    :
else
    fail "a component asks Theme for something it does not have (listed above)." \
         "QML would return undefined and draw nothing, without an error." \
         "Either fix the spelling, or add the token to Theme.qml — and if it" \
         "is a colour, to BOTH theme/Ice.qml and theme/Midnight.qml."
fi

# ------------------------------------------------------------------------------
echo ""
echo "=== 14. no Plasma or KDE leftovers ==="
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

if grep -rn --include='*.qml' \
        -E '(^|[^A-Za-z0-9_.])(Kirigami|PlasmaComponents[0-9]*|PlasmaCore|Plasmoid|TaskManagerApplet)\.|import +org\.kde\.|plasma\.applet\.' \
        . --exclude-dir=.git > /dev/null 2>&1; then
    grep -rn --include='*.qml' \
        -E '(^|[^A-Za-z0-9_.])(Kirigami|PlasmaComponents[0-9]*|PlasmaCore|Plasmoid|TaskManagerApplet)\.|import +org\.kde\.|plasma\.applet\.' \
        . --exclude-dir=.git || true
    fail "a QML file uses a Plasma-only type or import." \
         "This shell runs on any compositor and does not have Plasma." \
         "Whatever it was doing has a portable Quickshell or QtQuick answer."
else
    pass "no Plasma or KDE types"
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
