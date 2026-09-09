#!/usr/bin/env bash
# =============================================================================
# wallpaper-check.sh — does the shell really tell the session to swap the
#                      wallpaper when the machine goes dark?
# =============================================================================
# WHAT THIS ANSWERS, IN ONE SENTENCE
#   When light/dark flips, does the shell run the program named in
#   $AQ_WALLPAPER_SETTER, with the right word — and does it correctly do
#   NOTHING when that variable is not set?
#
# WHY IT EXISTS AND WHY IT IS NOT `load-check.sh`
#   load-check.sh answers one question: does the shell start at all. It is a
#   gate, not a microscope, and adding behaviour to it would blur what a red
#   build means.
#
#   This is a different kind of check and the first of its kind in this
#   repository: it starts the real shell and then makes something HAPPEN to it,
#   and reads what the shell did about it. tests/test-shell.sh runs it when the
#   machine it is on can (Linux, `qs`, and a window manager); everywhere else
#   that section says so and skips.
#
# WHY THE WALLPAPER NEEDED A CHECK OF ITS OWN
#   Because it is the one part of "the desktop follows the theme" that the shell
#   does not draw. `swaybg` puts the picture up, started once by the session at
#   login, and nothing re-runs it — so a machine flipped to dark had a navy bar,
#   a navy dock and a pale picture behind them. On the bench, twice, that read
#   as "the flip to dark didn't carry over". The fix is a contract with the
#   session (docs/session.md); this proves the shell's half of it.
#
# -----------------------------------------------------------------------------
# THE TWO FAKES, AND WHY FAKING IS THE HONEST THING TO DO HERE
# -----------------------------------------------------------------------------
# 1. A FAKE WALLPAPER SETTER. A shell script on the PATH that writes down what
#    it was called with and exits. It is the whole point: we are not testing
#    that swaybg works, we are testing that the shell asks for the right thing.
#
# 2. A FAKE gdbus. This is the interesting one. The shell asks the appearance
#    portal whether the machine is light or dark by running `gdbus`, and it
#    hears about CHANGES by leaving a `gdbus monitor` running and reading its
#    output a line at a time. A build machine has no portal at all, and even
#    this bench PC has only one, belonging to a person who is using it — so
#    flipping the real setting to run a test would change the desktop somebody
#    is sitting at.
#
#    So `gdbus` is replaced with a script of our own that answers "light" once,
#    and then, three seconds later, prints exactly the line a real
#    `gdbus monitor` prints when somebody turns the machine dark. Everything
#    after that is the real shell doing the real thing.
#
#    ⚠️ THAT MAKES THIS A TEST OF THE PARSER TOO, and deliberately. The line the
#    fake prints was copied from a real `gdbus monitor` on the bench, colons,
#    quotes, brackets and all. If somebody ever changes how that line is read,
#    this check goes red — which is what nearly happened for real: "the shell is
#    not hearing the change" was one of the two suspects on 2026-09-08 and there
#    was no way to test it.
#
# HOW TO RUN IT
#     ./harness/wallpaper-check.sh
#
#   It needs Linux, `qs`, and one of `labwc`, `sway` or `cage` — the same three
#   as load-check.sh, and for the same reason: the shell is a bar, and a bar has
#   to ask a window manager for permission to be one.
#
#   AQ_WALLPAPER_TIMEOUT=25   how long to give the shell before judging it
#   AQ_WALLPAPER_KEEP_LOGS=1  leave the logs on disk and print where they are
# =============================================================================

set -uo pipefail

AQ_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AQ_WALLPAPER_TIMEOUT="${AQ_WALLPAPER_TIMEOUT:-25}"
AQ_WALLPAPER_KEEP_LOGS="${AQ_WALLPAPER_KEEP_LOGS:-0}"

aq_failures=0
aq_workdir=""

say()  { echo ""; echo "=== $* ==="; }
ok()   { echo "  OK   $*"; }
note() { echo "       $*"; }
bad()  {
    echo "  FAIL $1"
    shift
    for aq_line in "$@"; do echo "       $aq_line"; done
    aq_failures=$((aq_failures + 1))
}

if [ "$(uname -s)" != "Linux" ]; then
    echo "This script only runs on Linux. It starts a Wayland window manager,"
    echo "and there is no Wayland on macOS."
    exit 1
fi

if ! command -v qs > /dev/null 2>&1; then
    echo "MISSING qs — the Quickshell runtime. See harness/README.md."
    exit 1
fi

aq_compositor=""
for aq_c in labwc sway cage; do
    if command -v "${aq_c}" > /dev/null 2>&1; then
        aq_compositor="${aq_c}"
        break
    fi
done
if [ -z "${aq_compositor}" ]; then
    echo "MISSING a window manager — one of labwc, sway or cage."
    exit 1
fi

# -----------------------------------------------------------------------------
# A private everything, so this can never touch the machine it runs on
# -----------------------------------------------------------------------------
aq_workdir="$(mktemp -d /tmp/aquarius-wallpaper-check.XXXXXX)"
mkdir -p "${aq_workdir}/run" "${aq_workdir}/bin" "${aq_workdir}/said"
chmod 700 "${aq_workdir}/run"

aq_cleanup() {
    [ -n "${aq_qs_pid:-}" ] && kill "${aq_qs_pid}" 2> /dev/null
    [ -n "${aq_wm_pid:-}" ] && kill "${aq_wm_pid}" 2> /dev/null
    if [ "${AQ_WALLPAPER_KEEP_LOGS}" != "0" ]; then
        echo ""
        echo "Logs kept in ${aq_workdir}"
    else
        rm -rf "${aq_workdir}"
    fi
}
trap aq_cleanup EXIT

export XDG_RUNTIME_DIR="${aq_workdir}/run"
export XDG_CACHE_HOME="${aq_workdir}/cache"
export XDG_STATE_HOME="${aq_workdir}/state"
mkdir -p "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}"

# ⚠️ Quickshell reads QS_CONFIG_PATH, and on a real Aquarius session that
#   variable is in the environment and points at the INSTALLED shell. Left set,
#   every `qs` below would drive the shell the person is looking at instead of
#   the one in this folder.
unset QS_CONFIG_PATH QS_CONFIG_NAME

export WLR_BACKENDS=headless
export WLR_HEADLESS_OUTPUTS=1
export WLR_RENDERER=pixman
export WLR_LIBINPUT_NO_DEVICES=1
export QT_QPA_PLATFORM=wayland
export QT_QUICK_BACKEND=software
export LIBGL_ALWAYS_SOFTWARE=1
export NO_COLOR=1

# -----------------------------------------------------------------------------
# Fake 1: the wallpaper setter. It writes down what it was asked for.
# -----------------------------------------------------------------------------
cat > "${aq_workdir}/bin/aquarius-wallpaper" <<EOF
#!/usr/bin/env bash
# Stands in for /usr/libexec/aquarius-wallpaper. Writes down every word it was
# called with, one call per line, and does nothing else.
echo "\$*" >> "${aq_workdir}/said/wallpaper"
exit 0
EOF
chmod +x "${aq_workdir}/bin/aquarius-wallpaper"

# -----------------------------------------------------------------------------
# Fake 2: gdbus. Answers "light", then says the machine went dark.
# -----------------------------------------------------------------------------
# The shell calls this twice, in two quite different ways, and this script has
# to be both:
#
#   gdbus call    ... ReadOne org.freedesktop.appearance color-scheme
#                 -> print one answer and exit. `(<uint32 2>,)` is "prefer
#                    light", which is what a real portal prints.
#
#   gdbus monitor ... --object-path /org/freedesktop/portal/desktop
#                 -> stay alive and print one line per signal. After three
#                    seconds it prints the SettingChanged line a real one prints
#                    when somebody turns the machine dark, then waits to be
#                    killed rather than exiting (a monitor that exits tells the
#                    shell the watching has stopped).
#
# The SettingChanged line below is copied from a real `gdbus monitor` and must
# stay that way — see the note at the top of this file.
cat > "${aq_workdir}/bin/gdbus" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    call)
        echo "(<uint32 2>,)"
        ;;
    monitor)
        sleep 3
        printf '%s\n' "/org/freedesktop/portal/desktop: org.freedesktop.portal.Settings.SettingChanged ('org.freedesktop.appearance', 'color-scheme', <uint32 1>)"
        sleep 3600
        ;;
    *)
        exit 1
        ;;
esac
EOF
chmod +x "${aq_workdir}/bin/gdbus"

export PATH="${aq_workdir}/bin:${PATH}"

# -----------------------------------------------------------------------------
# One invisible window manager
# -----------------------------------------------------------------------------
aq_start_wm() {
    case "${aq_compositor}" in
        labwc)
            mkdir -p "${aq_workdir}/wm"
            cat > "${aq_workdir}/wm/rc.xml" <<'XML'
<?xml version="1.0"?>
<labwc_config>
  <core><gap>0</gap></core>
</labwc_config>
XML
            labwc -C "${aq_workdir}/wm" > "${aq_workdir}/wm.log" 2>&1 &
            ;;
        sway)
            : > "${aq_workdir}/sway.conf"
            sway -c "${aq_workdir}/sway.conf" > "${aq_workdir}/wm.log" 2>&1 &
            ;;
        cage)
            cage -- sleep 3600 > "${aq_workdir}/wm.log" 2>&1 &
            ;;
    esac
    aq_wm_pid=$!

    local waited=0
    while [ "${waited}" -lt 10 ]; do
        if ! kill -0 "${aq_wm_pid}" 2> /dev/null; then
            echo "  ${aq_compositor} exited before it was ready. It said:"
            sed 's/^/         /' "${aq_workdir}/wm.log"
            return 1
        fi
        local found
        found="$(find "${XDG_RUNTIME_DIR}" -maxdepth 1 -name 'wayland-*' \
            -not -name '*.lock' -printf '%f\n' 2> /dev/null | head -1)"
        if [ -n "${found}" ]; then
            export WAYLAND_DISPLAY="${found}"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    echo "  ${aq_compositor} never opened a Wayland socket."
    return 1
}

# -----------------------------------------------------------------------------
# One run of the shell, with the wallpaper setter set or not
# -----------------------------------------------------------------------------
# Returns whatever the fake setter was called with, one call per line, in
# ${aq_said}.
aq_said=""

aq_run_shell() {
    local label="$1" setter="$2"

    : > "${aq_workdir}/said/wallpaper"

    if [ -n "${setter}" ]; then
        export AQ_WALLPAPER_SETTER="${setter}"
    else
        unset AQ_WALLPAPER_SETTER
    fi

    # AQ_FRAME_GENERATOR is deliberately left unset: the window frames are a
    # different half of the same story and rebuilding them here would run a
    # Python program for no reason.
    unset AQ_FRAME_GENERATOR

    qs -p "${AQ_SHELL_DIR}" > "${aq_workdir}/${label}.log" 2>&1 &
    aq_qs_pid=$!

    local waited=0
    while [ "${waited}" -lt "${AQ_WALLPAPER_TIMEOUT}" ]; do
        if ! kill -0 "${aq_qs_pid}" 2> /dev/null; then
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done

    kill "${aq_qs_pid}" 2> /dev/null
    wait "${aq_qs_pid}" 2> /dev/null
    aq_qs_pid=""

    aq_said="$(tr -d '\r' < "${aq_workdir}/said/wallpaper")"
}

# -----------------------------------------------------------------------------
say "What is installed"
echo "  found    qs — $(qs --version 2>&1 | head -1)"
echo "  found    ${aq_compositor}"
echo "  faked    gdbus (answers light, then says dark after 3s)"
echo "  faked    aquarius-wallpaper (writes down what it was asked for)"

if ! aq_start_wm; then
    exit 1
fi
echo "  running  under ${aq_compositor}, headless, on ${WAYLAND_DISPLAY}"

# -----------------------------------------------------------------------------
say "1. With AQ_WALLPAPER_SETTER set, a flip to dark asks for midnight"
aq_run_shell "with-setter" "${aq_workdir}/bin/aquarius-wallpaper"

if [ -z "${aq_said}" ]; then
    bad "the wallpaper setter was never called." \
        "The shell heard the machine go dark and did not tell the session," \
        "so the desktop keeps the light picture behind a dark bar. That is" \
        "the bench finding this check exists for. What the shell said:" \
        "$(grep -a 'appearance\|wallpaper' "${aq_workdir}/with-setter.log" | head -5)"
else
    ok "the setter was called"
    note "it was asked for: ${aq_said}"

    if [ "${aq_said}" = "midnight" ]; then
        ok "  and asked for exactly 'midnight', which is the dark palette's name"
    else
        bad "the setter was called with '${aq_said}', not 'midnight'." \
            "The word has to be the palette's own name — the same two words" \
            "generate-theme --scheme takes — or the session cannot know which" \
            "picture to put up."
    fi

    if [ "$(printf '%s\n' "${aq_said}" | grep -c .)" -eq 1 ]; then
        ok "  and only once, so the desktop does not blink at login"
    else
        bad "the setter was called $(printf '%s\n' "${aq_said}" | grep -c .) times." \
            "It runs on a FLIP, not on the portal's first answer: the session" \
            "has already put the right picture up before the shell starts," \
            "and restarting swaybg for nothing makes the desktop blink."
    fi
fi

# -----------------------------------------------------------------------------
say "2. With AQ_WALLPAPER_SETTER unset, nothing is run at all"
aq_run_shell "no-setter" ""

if [ -z "${aq_said}" ]; then
    ok "nothing was run, which is right"
    note "an unset variable means there is no Aquarius wallpaper to swap —"
    note "the harness, somebody's own desktop, or an image whose session half"
    note "of the contract has not landed yet."
else
    bad "something was run even with AQ_WALLPAPER_SETTER unset: ${aq_said}." \
        "On a machine with no wallpaper setter this must do nothing at all." \
        "Calling a program that is not there would be a failure logged on" \
        "every flip, for ever."
fi

# -----------------------------------------------------------------------------
echo ""
if [ "${aq_failures}" -ne 0 ]; then
    echo "::error::${aq_failures} check(s) failed."
    exit 1
fi
echo "The shell tells the session to swap the wallpaper, with the right word,"
echo "once per flip — and says nothing at all when there is nobody to tell."
echo ""
echo "What this does NOT prove: that the picture actually changes. That is"
echo "/usr/libexec/aquarius-wallpaper's job, it lives in the os-image"
echo "repository, and it is the bench's to look at. See docs/session.md."
