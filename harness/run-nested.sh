#!/usr/bin/env bash
# =============================================================================
# run-nested.sh — run the Aquarius Shell in a window, on any Linux desktop
# =============================================================================
# WHAT THIS DOES, IN ONE SENTENCE
#   It opens a second, miniature desktop inside a normal window on the desktop
#   you are already using, and starts the Aquarius Shell inside that window.
#
# WHY IT HAS TO WORK THIS WAY
#   A bar has to ask the window manager for permission to be a bar. The request
#   is a published Wayland protocol called wlr-layer-shell. GNOME's window
#   manager does not implement it and has said for years that it will not. So on
#   a GNOME machine — which is what AquariusOS ships now — this shell CANNOT
#   appear as the real bar. It is not a bug in the shell and no amount of work on
#   the shell will change it.
#
#   The way around it is to run a small window manager that DOES implement it,
#   inside a window. Everything inside that window is a complete little desktop
#   with its own rules, and our bar is a real bar in there.
#
# WHAT YOU SEE WHEN IT WORKS
#   A window opens. Across the top of THAT WINDOW (not your screen) there is a
#   pale bar with the Aquarius mark on the left and the date and time on the
#   right. Open an app inside the window and its name appears next to the mark.
#
# HOW TO USE IT WHILE WORKING
#   Leave it running. Edit a .qml file, save it, and the bar reloads by itself
#   within a second — Quickshell watches the files. You do not restart anything.
#
# CLOSING IT
#   Close the window, or press Ctrl-C in this terminal.
#
# See README.md next to this script for install instructions and for what to do
# when something does not work.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Where the shell lives: the folder above this script.
# ---------------------------------------------------------------------------
AQ_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Which nested window manager to use. "niri" is the default; "labwc" is the
# other option the roadmap is considering. Override like this:
#     AQ_COMPOSITOR=labwc ./harness/run-nested.sh
AQ_COMPOSITOR="${AQ_COMPOSITOR:-niri}"

# ---------------------------------------------------------------------------
# Refuse to run where it cannot possibly work, with a useful sentence.
# ---------------------------------------------------------------------------
if [ "$(uname -s)" != "Linux" ]; then
    echo "This script only runs on Linux."
    echo ""
    echo "You appear to be on $(uname -s). The Aquarius Shell is a Wayland"
    echo "desktop shell — there is no Wayland on macOS, and no version of this"
    echo "will ever run there. Use the AquariusOS bench machine, a Linux PC, or"
    echo "a Fedora/Bazzite virtual machine on x86 hardware."
    exit 1
fi

aq_missing=0
aq_need() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo "  MISSING  $1 — $2"
        aq_missing=1
    else
        echo "  found    $1"
    fi
}

echo ""
echo "=== Checking what is installed ==="
aq_need qs "the Quickshell runtime. Install: sudo dnf install quickshell"
aq_need "${AQ_COMPOSITOR}" "the nested window manager. Install: sudo dnf install ${AQ_COMPOSITOR}"

if [ "${aq_missing}" -ne 0 ]; then
    echo ""
    echo "Something above is missing. harness/README.md has the install steps,"
    echo "including what to do on Bazzite, where dnf works differently."
    exit 1
fi

# ---------------------------------------------------------------------------
# We need a Wayland session to open a window ON.
# ---------------------------------------------------------------------------
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo ""
    echo "No Wayland session detected (WAYLAND_DISPLAY is not set)."
    echo ""
    echo "This script opens a window on your current desktop, so it needs one."
    echo "If you are logged into an X11 session, log out and pick a Wayland"
    echo "session at the login screen. If you are on a text console, there is"
    echo "nothing here to put a window on."
    exit 1
fi

echo ""
echo "=== Starting ==="
echo "  shell:      ${AQ_SHELL_DIR}"
echo "  running in: ${AQ_COMPOSITOR}, nested in a window on your current desktop"
echo ""
echo "  Edit any .qml file and save — the bar reloads on its own."
echo "  Close the window (or press Ctrl-C here) to stop."
echo ""

# ---------------------------------------------------------------------------
# Start the nested window manager, and have IT start the shell.
#
# Both of these window managers take a command to run once they are up. That is
# better than starting the shell separately, because a shell started outside the
# nested session would try to attach itself to YOUR desktop, where it cannot
# work.
#
#   qs -p <folder>   run the shell configuration in that folder
#                    (-p/--path is for configs outside ~/.config/quickshell)
# ---------------------------------------------------------------------------
case "${AQ_COMPOSITOR}" in
    niri)
        # Running `niri` from inside an existing Wayland session opens it as a
        # nested window automatically — that is its winit backend, and it is the
        # way niri's own developers work on it. Everything after `--` is the
        # command niri runs once it is up.
        #
        # We deliberately do NOT pass niri's --session flag. That flag pushes the
        # nested session's environment into systemd and D-Bus globally, and niri's
        # own help says not to use it for a nested window — it would confuse the
        # real desktop you are sitting in.
        exec niri -- qs -p "${AQ_SHELL_DIR}"
        ;;
    labwc)
        # labwc's -s/--startup takes a command to run once it is up. (There is
        # also -S/--session, which additionally shuts labwc down when that
        # command exits — not what we want, since closing the window should be
        # what ends the run.)
        exec labwc -s "qs -p ${AQ_SHELL_DIR}"
        ;;
    *)
        echo "Unknown compositor '${AQ_COMPOSITOR}'."
        echo "This script knows about 'niri' and 'labwc'."
        exit 1
        ;;
esac
