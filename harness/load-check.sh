#!/usr/bin/env bash
# =============================================================================
# load-check.sh — actually START the shell, on a machine with no screen
# =============================================================================
# WHAT THIS DOES, IN ONE SENTENCE
#   It opens an INVISIBLE desktop — a real window manager that draws to nothing
#   at all — starts the Aquarius Shell inside it, waits twenty seconds, and asks
#   one question: is it still alive, and did it complain on the way up?
#
# WHY THIS EXISTS
#   Everything else that checks this repository READS the files. `qmllint` reads
#   them very cleverly, and `tests/test-shell.sh` reads them with about forty
#   rules. Neither of them RUNS anything.
#
#   That gap has a cost, and we paid it twice in one day. On 6 September 2026 the
#   desktop refused to start on the bench machine — first with
#
#       Failed to load configuration
#         caused by @shell.qml[103:5]: LockLayer is not a type
#
#   and, once that was fixed, again with "GreeterAvatar is not a type". Both were
#   the same mistake: a folder had a `qmldir` file, and a `qmldir` file hides
#   everything it does not name. Both passed `qmllint`. Both passed
#   `tests/test-shell.sh`. The only thing on earth that finds a mistake like that
#   is a QML engine being asked to load the shell — which, until this script, had
#   never happened anywhere except on Royce's desk.
#
#   So this is the real gate. CI runs it on every push. A shell that will not
#   load now fails a build instead of failing a person.
#
# WHY IT NEEDS A WINDOW MANAGER AT ALL
#   The shell is a bar, a dock and a lock screen, and every one of those has to
#   ask a window manager for permission to be what it is (see harness/README.md
#   for the long version). With no window manager to ask, Quickshell does not
#   even get as far as reading our QML — so "just run qs" proves nothing.
#
#   A build machine has no screen, no graphics card and nobody sitting at it. So
#   we start a window manager in HEADLESS mode: it does all its real work, drives
#   a pretend monitor, and paints into memory that nobody ever looks at. The
#   shell cannot tell the difference.
#
# WHAT IT CHECKS, AND WHAT IT CANNOT
#   ✅ every QML file the shell reaches at start-up parses and its types resolve
#   ✅ every `import` finds a real module on the Quickshell that is installed
#   ✅ the shell survives its first twenty seconds instead of exiting
#   ✅ the same three times over: the desktop, the login screen, the lock screen
#
#   ❌ whether anything is in the RIGHT PLACE, the right colour, or the right
#      size. Nobody looks at the picture. This says "it loads", never "it looks
#      right".
#   ❌ anything that only goes wrong when a person touches it — a click handler
#      with a typo in it, a keyboard shortcut wired to nothing. Those are still
#      the bench's job.
#
# HOW TO RUN IT YOURSELF
#     ./harness/load-check.sh              # all three entry points
#     ./harness/load-check.sh shell        # just the desktop
#     ./harness/load-check.sh greeter lock # pick and choose
#
#   It needs Linux, `qs` (Quickshell 0.3.1 or newer) and one of `labwc`, `sway`
#   or `cage`. On a desktop machine, prefer harness/run-nested.sh — that one you
#   can SEE. This one is for machines with nobody in front of them.
#
# KNOBS (environment variables, all optional)
#     AQ_LOAD_TIMEOUT=20     seconds to let the shell live before judging it
#     AQ_LOAD_COMPOSITOR=    force one of: labwc, sway, cage
#     AQ_LOAD_KEEP_LOGS=1    leave the logs on disk and print where they are
#     AQ_LOAD_SHOW_LOG=1     print the whole log even when the check passes
#
# ⚠️ Two of the three entry points are KNOWN BROKEN today and do not fail the
#    build. They are still run and still printed. Search this file for
#    `aq_known_broken` — the note there says exactly what is wrong and why it is
#    not fixed here.
# =============================================================================

set -uo pipefail

# The shell lives in the folder above this script.
AQ_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AQ_LOAD_TIMEOUT="${AQ_LOAD_TIMEOUT:-20}"
AQ_LOAD_COMPOSITOR="${AQ_LOAD_COMPOSITOR:-}"
AQ_LOAD_KEEP_LOGS="${AQ_LOAD_KEEP_LOGS:-0}"
AQ_LOAD_SHOW_LOG="${AQ_LOAD_SHOW_LOG:-0}"

# How long to wait for the invisible window manager to be ready before deciding
# it is never going to be. Ten seconds is generous; it normally takes under one.
AQ_COMPOSITOR_TIMEOUT="${AQ_COMPOSITOR_TIMEOUT:-10}"

aq_failures=0
aq_workdir=""

# Set while checking an entry point that is already known to be broken — see the
# known-broken list further down. It turns a FAIL into a note rather than a
# failure, and nothing else.
aq_expecting_failure=0

say()  { echo ""; echo "=== $* ==="; }
ok()   { echo "  OK   $*"; }
note() { echo "       $*"; }
bad()  {
    if [ "${aq_expecting_failure}" -eq 1 ]; then
        echo "  KNOWN  $*"
    else
        echo "  FAIL $*"
        aq_failures=$((aq_failures + 1))
    fi
}

# -----------------------------------------------------------------------------
# Refuse to run where it cannot possibly work, with a useful sentence.
# -----------------------------------------------------------------------------
if [ "$(uname -s)" != "Linux" ]; then
    echo "This script only runs on Linux."
    echo ""
    echo "You appear to be on $(uname -s). It starts a Wayland window manager,"
    echo "and there is no Wayland on macOS. Push the branch and let CI run it,"
    echo "or use the AquariusOS bench machine."
    exit 1
fi

# -----------------------------------------------------------------------------
# Which invisible window manager we are going to use
# -----------------------------------------------------------------------------
# labwc is FIRST because labwc is the real one — it is what AquariusOS ships and
# what the shell runs on in front of a person. Testing on the real thing is worth
# more than testing on a convenient thing.
#
# sway and cage are here as understudies, for two reasons. One, a build machine's
# package manager may not have labwc. Two, the headless mode of a window manager
# is a corner almost nobody exercises, and it has broken before (labwc issue #605
# was exactly this, years ago). If labwc ever cannot come up with no screen, this
# check should still run rather than going quiet — a check that switches itself
# off is worse than no check, because it looks green.
#
# All three are wlroots programs, so all three take the same instructions: build
# no real outputs, invent one pretend monitor, and paint with the CPU.
aq_compositors="labwc sway cage"
if [ -n "${AQ_LOAD_COMPOSITOR}" ]; then
    aq_compositors="${AQ_LOAD_COMPOSITOR}"
fi

say "What is installed"

if ! command -v qs > /dev/null 2>&1; then
    echo "  MISSING  qs — the Quickshell runtime, which runs the shell's QML."
    echo ""
    echo "  On Fedora:  sudo dnf install quickshell"
    echo "  ⚠️ AquariusOS builds its own Quickshell 0.3.1, because Fedora's is a"
    echo "     0.2.1 snapshot with no Quickshell.Networking and no"
    echo "     Quickshell.Bluetooth — the shell will not load on it at all."
    echo "     os-image/build_files/stage-quickshell.sh is how it is built."
    exit 1
fi
echo "  found    qs — $(qs --version 2>&1 | head -1)"

aq_available=""
for aq_c in ${aq_compositors}; do
    if command -v "${aq_c}" > /dev/null 2>&1; then
        echo "  found    ${aq_c}"
        aq_available="${aq_available} ${aq_c}"
    else
        echo "  absent   ${aq_c}"
    fi
done

if [ -z "${aq_available# }" ]; then
    echo ""
    echo "None of the window managers this script knows about are installed."
    echo "Install one:  sudo dnf install labwc      (the one AquariusOS ships)"
    echo "              sudo dnf install sway"
    echo "              sudo dnf install cage"
    exit 1
fi

# -----------------------------------------------------------------------------
# A private folder for everything this run makes
# -----------------------------------------------------------------------------
# XDG_RUNTIME_DIR is where Wayland puts its socket — the thing programs connect
# to in order to say "put a window on the screen". A build machine usually does
# not have one, and Wayland is fussy about its permissions, so we make our own.
aq_workdir="$(mktemp -d /tmp/aquarius-load-check.XXXXXX)"
mkdir -p "${aq_workdir}/run"
chmod 700 "${aq_workdir}/run"
export XDG_RUNTIME_DIR="${aq_workdir}/run"

# Quickshell writes its own state and instance files under these. Keeping them
# inside the throwaway folder means one run can never confuse the next, and
# nothing is left behind on the machine.
export XDG_CACHE_HOME="${aq_workdir}/cache"
export XDG_STATE_HOME="${aq_workdir}/state"
export XDG_CONFIG_HOME="${aq_workdir}/config"
mkdir -p "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}" "${XDG_CONFIG_HOME}"

# -----------------------------------------------------------------------------
# A message bus of its own
# -----------------------------------------------------------------------------
# The shell IS this session's notification service, and it asks the session's
# message bus (D-Bus) for that job when it starts. A build machine has no message
# bus at all, so without this the shell spends its first second failing to reach
# something that is not there, and the log fills with noise that has nothing to
# do with our QML.
#
# One private bus, started here and shut down at the end, makes those questions
# get real answers. If dbus-daemon is not installed we carry on without it — the
# check still works, the log is just chattier.
aq_dbus_pid=""
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-daemon > /dev/null 2>&1; then
    aq_dbus_out="$(dbus-daemon --session --fork --print-address=1 --print-pid=3 3>"${aq_workdir}/dbus.pid" 2>/dev/null)"
    if [ -n "${aq_dbus_out}" ]; then
        export DBUS_SESSION_BUS_ADDRESS="${aq_dbus_out}"
        aq_dbus_pid="$(cat "${aq_workdir}/dbus.pid" 2>/dev/null || true)"
        echo "  started  a private message bus for this run"
    fi
fi

# -----------------------------------------------------------------------------
# Telling every piece of software to pretend it has a screen
# -----------------------------------------------------------------------------
# WLR_BACKENDS=headless     build no real outputs. This is the whole trick: the
#                           window manager runs completely normally and simply
#                           has no monitor attached to it.
# WLR_HEADLESS_OUTPUTS=1    ...except one pretend monitor, because a bar with no
#                           screen to sit on is not a test of anything. The shell
#                           draws one bar per screen; it needs at least one.
# WLR_RENDERER=pixman       paint with the processor instead of a graphics card,
#                           since there is no graphics card.
# WLR_LIBINPUT_NO_DEVICES=1 do not refuse to start over the absence of a keyboard
#                           and mouse.
export WLR_BACKENDS=headless
export WLR_HEADLESS_OUTPUTS=1
export WLR_RENDERER=pixman
export WLR_LIBINPUT_NO_DEVICES=1

# The same instruction, in Qt's language, for the shell itself.
#
# QT_QPA_PLATFORM=wayland   the shell is a Wayland program and nothing else. This
#                           is the same line the real session sets — see
#                           session/aquarius-session.
# QT_QUICK_BACKEND=software draw with the processor. Qt's normal path wants
#                           OpenGL and a graphics card.
# LIBGL_ALWAYS_SOFTWARE=1   and if anything reaches for OpenGL regardless, give
#                           it Mesa's software one rather than nothing.
export QT_QPA_PLATFORM=wayland
export QT_QUICK_BACKEND="${QT_QUICK_BACKEND:-software}"
export LIBGL_ALWAYS_SOFTWARE=1

# Quickshell colours its log for a person reading a terminal. We are reading it
# with grep, and colour codes get in the way of that.
export NO_COLOR=1

# -----------------------------------------------------------------------------
# Tidying up, however this ends
# -----------------------------------------------------------------------------
aq_cleanup() {
    [ -n "${aq_dbus_pid}" ] && kill "${aq_dbus_pid}" 2> /dev/null
    if [ "${AQ_LOAD_KEEP_LOGS}" != "0" ]; then
        echo ""
        echo "Logs kept in ${aq_workdir}"
    elif [ -n "${aq_workdir}" ] && [ -d "${aq_workdir}" ]; then
        rm -rf "${aq_workdir}"
    fi
}
trap aq_cleanup EXIT

# -----------------------------------------------------------------------------
# Starting one invisible window manager
# -----------------------------------------------------------------------------
# Writes the name of its Wayland socket into aq_socket, and its process id into
# aq_compositor_pid. Returns 1 if it never came up.
aq_socket=""
aq_compositor_pid=""

aq_start_compositor() {
    local name="$1" dir="$2" log="$3"

    case "${name}" in
        labwc)
            # -C points labwc at a configuration FOLDER. We give it an empty one
            # on purpose: labwc would otherwise read whatever is in the home
            # directory of whoever is running this, and a check whose result
            # depends on the tester's own settings is not a check.
            mkdir -p "${dir}/labwc"
            cat > "${dir}/labwc/rc.xml" <<'XML'
<?xml version="1.0"?>
<!-- The smallest labwc configuration that is still valid. Nothing in here is a
     design decision: this window manager is never looked at by anybody. The
     real one is session/labwc/. -->
<labwc_config>
  <core><gap>0</gap></core>
</labwc_config>
XML
            labwc -C "${dir}/labwc" > "${log}" 2>&1 &
            aq_compositor_pid=$!
            ;;
        sway)
            # sway insists on a configuration file and will not start without
            # one. An empty file is a legal one.
            : > "${dir}/sway.conf"
            sway -c "${dir}/sway.conf" > "${log}" 2>&1 &
            aq_compositor_pid=$!
            ;;
        cage)
            # cage always runs one program and closes when that program ends, so
            # it is given something that never ends. We start the shell
            # ourselves, separately, so that we hold its process and can watch it
            # die.
            cage -- sleep 3600 > "${log}" 2>&1 &
            aq_compositor_pid=$!
            ;;
        *)
            echo "  (this script does not know how to start '${name}')"
            return 1
            ;;
    esac

    # Wait for the socket to appear. That file appearing is the window manager
    # saying "I am ready for programs to connect to me"; there is no other
    # announcement that all three of these make in the same way.
    local waited=0
    while [ "${waited}" -lt "${AQ_COMPOSITOR_TIMEOUT}" ]; do
        if ! kill -0 "${aq_compositor_pid}" 2> /dev/null; then
            echo "  ${name} exited before it was ready. It said:"
            sed 's/^/         /' "${log}"
            return 1
        fi
        local found
        found="$(find "${XDG_RUNTIME_DIR}" -maxdepth 1 -name 'wayland-*' \
            -not -name '*.lock' -printf '%f\n' 2> /dev/null | head -1)"
        if [ -n "${found}" ]; then
            aq_socket="${found}"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done

    echo "  ${name} never opened a Wayland socket in ${AQ_COMPOSITOR_TIMEOUT}s. It said:"
    sed 's/^/         /' "${log}"
    kill "${aq_compositor_pid}" 2> /dev/null
    return 1
}

# -----------------------------------------------------------------------------
# Reading the shell's log and deciding whether it is happy
# -----------------------------------------------------------------------------
# THE TWO KINDS OF BAD NEWS
#
#   1. The shell exits. Quickshell calls exit(-1) when the root file will not
#      load, so a dead process IS the failure — we do not have to interpret
#      anything. This is what both 6 September faults looked like.
#
#   2. The shell survives, but something inside it did not load. A piece built
#      later — a panel that appears on a click — can fail on its own without
#      taking the whole shell down. Those show up only as a line in the log, so
#      the log is read as well.
#
# WHAT IS DELIBERATELY IGNORED, AND WHY
#   A build machine is not a computer anybody uses. It has no Wi-Fi, no battery,
#   no Bluetooth, no sound card, no login manager and no fonts to speak of, and
#   the shell asks all of those questions on the way up. Every one of those
#   answers is "there isn't one here", which is TRUE and not a fault. If those
#   counted, this check would be red forever and everybody would learn to ignore
#   it — which is the one way a check can do harm.
#
#   So the list below is the set of complaints we expect from a machine with
#   nothing attached to it. Each line says what it is. Anything NOT on the list
#   is treated as a real problem. Adding to this list is a decision, not
#   housekeeping: read the log line first and be sure it is about the empty
#   machine and not about our code.
aq_ignore_file=""

aq_write_ignore_list() {
    aq_ignore_file="${aq_workdir}/ignore.txt"
    cat > "${aq_ignore_file}" <<'IGNORE'
NetworkManager
Networking
org.freedesktop.NetworkManager
bluez
Bluetooth
UPower
upower
PipeWire
Pipewire
pipewire
Greetd
greetd
GREETD_SOCK
polkit
Polkit
PolicyKit
xdg-desktop-portal
portal
StatusNotifier
SystemTray
brightness
backlight
/sys/class
pam_
aquarius-lock
Failed to open PAM
No such file or directory: /etc/pam.d
icon theme
Icon theme
QIconLoader
Populating font family aliases
fontconfig
Fontconfig
qt.qpa.fonts
qt.svg
Cursor theme
cursor-theme
XCURSOR
libinput
IGNORE
}

# ⚠️ TWO LISTS, AND THE DIFFERENCE BETWEEN THEM IS THE WHOLE POINT.
#
# HARD — these are never ignored, whatever else is on the line. Every one of them
# is a sentence a QML engine only ever says about our code. "is not a type" is
# not something a machine with no Wi-Fi says. Filtering these through the list
# above would be a hole big enough to drive the original bug through: the ignore
# list contains the word "Bluetooth", and a real failure in TileBluetooth.qml has
# that word in its file path.
#
# They are checked at ANY severity, because a type failing to resolve inside a
# piece the shell builds later comes through as a warning rather than an error —
# and is still fatal to the thing it was supposed to build.
aq_hard_patterns=(
    'Failed to load configuration'
    'is not a type'
    'is not installed'
    'is not a namespace'
    'Type .* unavailable'
    'Cannot assign'
    'Unable to assign'
    'Non-existent attached object'
    'Invalid property assignment'
    'Invalid attached property'
    'Duplicate signal name'
    'Duplicate property name'
    'Duplicate method name'
    'Expected token'
    'Unexpected token'
    'Syntax error'
    'Could not open config file'
)

# SOFT — real problems in our JavaScript, but also the shape of complaint a
# machine with no battery and no Wi-Fi genuinely produces when a reading it
# expected is not there. These ARE filtered through the ignore list.
aq_soft_patterns=(
    'ReferenceError'
    'TypeError'
    'is not defined'
    'is not a function'
    'Cannot read property'
)

aq_scan_log() {
    local log="$1" label="$2" problems=0

    # The shell says this line before it reads a single one of our files. If it
    # is missing, we are not looking at a shell that started at all.
    if ! grep -q 'Launching config' "${log}"; then
        bad "${label}: Quickshell never said 'Launching config' — it did not get as far as our QML."
        problems=1
    fi

    local pattern hits
    for pattern in "${aq_hard_patterns[@]}"; do
        hits="$(grep -E -- "${pattern}" "${log}" || true)"
        if [ -n "${hits}" ]; then
            bad "${label}: the QML did not load —"
            echo "${hits}" | head -20 | sed 's/^/         /'
            problems=1
        fi
    done

    for pattern in "${aq_soft_patterns[@]}"; do
        hits="$(grep -E -- "${pattern}" "${log}" | grep -v -F -f "${aq_ignore_file}" || true)"
        if [ -n "${hits}" ]; then
            bad "${label}: something in the shell's JavaScript went wrong —"
            echo "${hits}" | head -20 | sed 's/^/         /'
            problems=1
        fi
    done

    # And the catch-all: anything Quickshell itself called an ERROR that is not
    # on the "this machine has nothing attached to it" list.
    hits="$(grep -E '^\s*ERROR' "${log}" | grep -v -F -f "${aq_ignore_file}" || true)"
    if [ -n "${hits}" ]; then
        bad "${label}: Quickshell logged an error —"
        echo "${hits}" | head -20 | sed 's/^/         /'
        problems=1
    fi

    return "${problems}"
}

# -----------------------------------------------------------------------------
# One entry point: start it, wait, judge it
# -----------------------------------------------------------------------------
aq_check_entry() {
    local label="$1" target="$2"
    local dir="${aq_workdir}/${label}"
    local wm_log="${dir}/compositor.log"
    local qs_log="${dir}/quickshell.log"
    mkdir -p "${dir}"

    say "${label} — ${target}"

    if [ ! -e "${target}" ]; then
        bad "${label}: ${target} does not exist"
        return 1
    fi

    # Start a fresh window manager for each entry point. They are not meant to
    # run at the same time — two of them both want to be the notification
    # service, and the lock screen genuinely locks the session it is in.
    aq_socket=""
    aq_compositor_pid=""
    local started=""
    for aq_c in ${aq_available}; do
        if aq_start_compositor "${aq_c}" "${dir}" "${wm_log}"; then
            started="${aq_c}"
            break
        fi
        echo "  (${aq_c} would not start headless — trying the next one)"
    done

    if [ -z "${started}" ]; then
        bad "${label}: no window manager would start with no screen attached"
        return 1
    fi

    export WAYLAND_DISPLAY="${aq_socket}"
    echo "  running under ${started}, headless, on ${WAYLAND_DISPLAY}"

    # Start the shell. Foreground is Quickshell's default, so this is our process
    # and we can tell the difference between "still going" and "gave up".
    qs --no-color --log-times -p "${target}" > "${qs_log}" 2>&1 &
    local qs_pid=$!

    # Watch it for the agreed number of seconds. If it dies in that window, that
    # IS the answer and there is no point waiting out the rest.
    local waited=0 died=0
    while [ "${waited}" -lt "${AQ_LOAD_TIMEOUT}" ]; do
        if ! kill -0 "${qs_pid}" 2> /dev/null; then
            died=1
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done

    local qs_status=0
    if [ "${died}" -eq 1 ]; then
        wait "${qs_pid}"
        qs_status=$?
    else
        kill "${qs_pid}" 2> /dev/null
        wait "${qs_pid}" 2> /dev/null
    fi

    kill "${aq_compositor_pid}" 2> /dev/null
    wait "${aq_compositor_pid}" 2> /dev/null
    unset WAYLAND_DISPLAY

    local verdict=0

    if [ "${died}" -eq 1 ]; then
        bad "${label}: the shell exited after ${waited}s (exit code ${qs_status}) instead of staying up."
        note "Quickshell exits when the file it was asked to load will not load."
        verdict=1
    fi

    if ! aq_scan_log "${qs_log}" "${label}"; then
        verdict=1
    fi

    if [ "${verdict}" -ne 0 ] || [ "${AQ_LOAD_SHOW_LOG}" != "0" ]; then
        echo ""
        echo "  ---- what ${label} actually said ----"
        sed 's/^/  | /' "${qs_log}"
        echo "  ---- end ----"
        if [ -s "${wm_log}" ]; then
            echo "  ---- and what ${started} said ----"
            sed 's/^/  | /' "${wm_log}"
            echo "  ---- end ----"
        fi
    fi

    if [ "${verdict}" -eq 0 ]; then
        ok "${label}: loaded, and was still running ${AQ_LOAD_TIMEOUT}s later"
    fi

    return "${verdict}"
}

# -----------------------------------------------------------------------------
# The three entry points this repository has
# -----------------------------------------------------------------------------
# shell    the desktop: the bar, the dock, search, notifications, the lock layer
# greeter  the login screen, which greetd starts before anybody is logged in
# lock     the lock screen on its own, the way a designer looks at it
#
# All three are things a real machine runs, and all three have failed to load
# before. Checking only the desktop would have missed nothing on 6 September —
# but the greeter is the one nobody can see fail, because when it fails the
# screen is black and there is no way in.
# -----------------------------------------------------------------------------
# ⚠️ TWO OF THE THREE ARE BROKEN TODAY, AND THIS SAYS SO OUT LOUD
# -----------------------------------------------------------------------------
# They are still RUN, and what they say is still printed in full. They just do
# not turn the build red, because the fault is not in any change this check
# arrived with — it is a design question about how the login screen is started,
# and it needs Royce and a change to the os-image repository at the same time.
#
# WHAT IS WRONG (found 7 September 2026, the first day this script ran)
#
#     Failed to load configuration
#       caused by @GreeterCard.qml[65:13]: LogoMark is not a type
#
# Quickshell treats the folder of the file it is given as the CONFIG FOLDER, and
# it deliberately throws away every import that points outside it — the phrase in
# its own source is "blackhole any import resolution outside of the config
# folder" (src/core/qsintercept.cpp). The login screen is started as
#
#     qs -p .../shell/greeter/greeter.qml
#
# by /usr/libexec/aquarius-greeter-shell in the image, so its config folder is
# `greeter/`, and `import "../components/bar"` in GreeterCard.qml resolves to
# nothing at all. No qmldir fixes this — it is thrown away before a qmldir is
# consulted. `qs -p lock/lock.qml` fails the same way through LockSurface.qml.
#
# ⚠️ ON A REAL MACHINE THIS IS A LOGIN SCREEN THAT NEVER DRAWS — a black screen
# with no way in. That is the exact failure /usr/libexec/aquarius-greeter-watchdog
# was written to catch, and it is worth checking whether it is the same one.
#
# THE TWO WAYS OUT, neither of which belongs in this change:
#   1. Move the entry FILE to the top of the repo (greeter.qml beside shell.qml,
#      keeping greeter/ for its pieces). Then the config folder is the whole
#      shell and every import resolves. It costs one path change in the image's
#      aquarius-greeter-shell, and the two repositories must move together.
#   2. Stop importing across: give the login screen its own copy of the mark.
#      Cheaper, and a second copy of a logo to keep in step forever.
#
# ⚠️ IF ONE OF THESE STARTS PASSING, THE BUILD FAILS. That is on purpose. A
# known-broken list that nobody ever takes anything off is how a project ends up
# with checks that mean nothing.
aq_known_broken="greeter lock"

aq_is_known_broken() {
    case " ${aq_known_broken} " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

aq_write_ignore_list

aq_wanted="${*:-shell greeter lock}"

for aq_entry in ${aq_wanted}; do
    aq_expecting_failure=0
    if aq_is_known_broken "${aq_entry}"; then
        aq_expecting_failure=1
    fi

    case "${aq_entry}" in
        shell)   aq_check_entry shell   "${AQ_SHELL_DIR}" ;;
        greeter) aq_check_entry greeter "${AQ_SHELL_DIR}/greeter/greeter.qml" ;;
        lock)    aq_check_entry lock    "${AQ_SHELL_DIR}/lock/lock.qml" ;;
        *)
            echo "Unknown entry point '${aq_entry}'."
            echo "This script knows about: shell, greeter, lock"
            exit 1
            ;;
    esac
    aq_entry_result=$?

    if [ "${aq_expecting_failure}" -eq 1 ]; then
        if [ "${aq_entry_result}" -eq 0 ]; then
            aq_expecting_failure=0
            bad "${aq_entry} LOADS NOW — somebody fixed it."
            note "Take '${aq_entry}' out of aq_known_broken in this script, and"
            note "delete the paragraph above it that explains why it was there."
        else
            echo "  (${aq_entry} is on the known-broken list, so this does not fail the build —"
            echo "   read the note beside aq_known_broken in this script for why)"
        fi
    fi
done

echo ""
if [ "${aq_failures}" -ne 0 ]; then
    echo "::error::${aq_failures} entry point(s) would not load."
    echo ""
    echo "The log above is the whole story — the line that matters is usually the"
    echo "one that says 'caused by'. A type that 'is not a type' is nearly always"
    echo "a folder with a qmldir file that does not name it: see lock/qmldir and"
    echo "greeter/qmldir for the two we have already been bitten by."
    exit 1
fi

echo "Every entry point that is expected to load, loaded."
if [ -n "${aq_known_broken}" ]; then
    echo "(Still known-broken, and not counted: ${aq_known_broken}. See the note"
    echo " beside aq_known_broken in this script — the login screen is one of them.)"
fi
echo ""
echo "What that means: a real QML engine read every file the shell touches on"
echo "the way up, resolved every type and every import, and the shell was still"
echo "running afterwards. What it does NOT mean: that anything is in the right"
echo "place or the right colour. Nobody looked at the picture. That is still the"
echo "bench's job — docs/RESUME-ON-BENCH.md."
