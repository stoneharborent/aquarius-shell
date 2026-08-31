#!/usr/bin/env bash
# =============================================================================
# install-session.sh — put the Aquarius Session on the login screen
# =============================================================================
# WHAT THIS DOES
#   Copies four things into place so that "Aquarius Session (experimental)"
#   appears as a choice at the login screen, next to GNOME:
#
#     1. the launcher      -> <prefix>/bin/aquarius-session
#     2. the compositor
#        configurations    -> <prefix>/share/aquarius-session/
#     3. the shell itself  -> <prefix>/share/aquarius-shell/
#     4. the session entry -> <prefix>/share/wayland-sessions/aquarius.desktop
#     5. the portal config -> ~/.config/xdg-desktop-portal/
#
#   The default prefix is /usr/local, and that choice is the important one.
#
# WHY /usr/local AND NOT /usr
#   AquariusOS is built on Bazzite, which is an "atomic" system: /usr is part of
#   the operating system image and is READ-ONLY. You cannot copy a file into
#   /usr/share, and you should not want to — the whole point of an atomic system
#   is that the OS is exactly the image and nothing else.
#
#   /usr/local is different. On these systems it is a link to /var/usrlocal,
#   which is ordinary writable storage that survives updates and is not part of
#   the image. And SDDM, the login screen Bazzite uses, looks for sessions in
#   BOTH /usr/local/share/wayland-sessions AND /usr/share/wayland-sessions by
#   default.
#
#   So: a new session can be added to a Bazzite machine without rebuilding or
#   modifying the OS image at all, and removed again by deleting five files.
#   That is the property this script is built around.
#
#   (Verified from SDDM's own source; the default SessionDir list for Wayland is
#   /usr/local/share/wayland-sessions,/usr/share/wayland-sessions. NOT verified
#   on a real machine — see docs/session.md, "what is unproven".)
#
# WHAT IT DOES NOT DO
#   It does not install packages, touch the OS image, change any system setting,
#   or alter your existing GNOME session in any way. GNOME stays exactly where
#   it is and stays the default.
#
# USAGE
#   ./session/install-session.sh                 install everything
#   ./session/install-session.sh --portals-only  just the portal config; no root
#   ./session/install-session.sh --link          symlink the shell instead of
#                                                copying, so edits are live
#   ./session/install-session.sh --uninstall     take it all back out
#   ./session/install-session.sh --prefix DIR    somewhere other than /usr/local
#
# Full walkthrough, written for a beginner: docs/session.md
# =============================================================================

set -euo pipefail

AQ_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AQ_SESSION_SRC="${AQ_REPO_ROOT}/session"

aq_prefix="/usr/local"
aq_mode="install"
aq_link=0

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)
            if [ "$#" -lt 2 ]; then
                echo "--prefix needs a directory after it." >&2
                exit 1
            fi
            aq_prefix="$2"
            shift 2
            ;;
        --portals-only) aq_mode="portals"; shift ;;
        --uninstall)    aq_mode="uninstall"; shift ;;
        --link)         aq_link=1; shift ;;
        -h|--help)
            sed -n '2,50p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option '$1'. Try --help." >&2
            exit 1
            ;;
    esac
done

aq_portal_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/xdg-desktop-portal"

# -----------------------------------------------------------------------------
# Refuse to run as root.
#
# Not squeamishness: this script writes ONE thing into your home directory (the
# portal configuration) and several into a system directory. Run the whole
# thing under sudo and the home-directory part lands in /root, where nothing
# will ever read it, and the failure is invisible.
#
# So it runs as you, and calls sudo itself for exactly the steps that need it,
# printing each privileged command before it runs.
# -----------------------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    echo ""
    echo "Do not run this with sudo."
    echo ""
    echo "It needs to write one file into YOUR home directory and several into"
    echo "a system directory. Under sudo, the home-directory one would land in"
    echo "/root and never be read, and you would not be told."
    echo ""
    echo "Run it as yourself:   ./session/install-session.sh"
    echo "It will ask for your password when it actually needs to."
    echo ""
    exit 1
fi

# `run_root` prints what it is about to do with root privileges, then does it.
# Nothing happens behind your back.
aq_run_root() {
    echo "    sudo $*"
    sudo "$@"
}

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------
if [ "${aq_mode}" = "uninstall" ]; then
    echo ""
    echo "=== Removing the Aquarius Session ==="
    aq_run_root rm -f "${aq_prefix}/share/wayland-sessions/aquarius.desktop"
    aq_run_root rm -f "${aq_prefix}/bin/aquarius-session"
    aq_run_root rm -rf "${aq_prefix}/share/aquarius-session"
    aq_run_root rm -rf "${aq_prefix}/share/aquarius-shell"
    rm -f "${aq_portal_dir}/aquarius-niri-portals.conf"
    rm -f "${aq_portal_dir}/aquarius-labwc-portals.conf"
    echo "    rm ${aq_portal_dir}/aquarius-*-portals.conf"
    echo ""
    echo "Done. The Aquarius Session is gone from the login screen."
    echo "Your GNOME session was never touched and is unchanged."
    echo ""
    exit 0
fi

# -----------------------------------------------------------------------------
# The portal configuration. No root needed — it goes in your own config folder,
# which xdg-desktop-portal searches BEFORE any system directory.
# -----------------------------------------------------------------------------
echo ""
echo "=== Portal configuration (no password needed) ==="
mkdir -p "${aq_portal_dir}"
cp -f "${AQ_SESSION_SRC}/portals/aquarius-niri-portals.conf"  "${aq_portal_dir}/"
cp -f "${AQ_SESSION_SRC}/portals/aquarius-labwc-portals.conf" "${aq_portal_dir}/"
echo "    installed into ${aq_portal_dir}"
echo "      aquarius-niri-portals.conf"
echo "      aquarius-labwc-portals.conf"

if [ "${aq_mode}" = "portals" ]; then
    echo ""
    echo "Portal configuration only, as asked. Nothing else was changed."
    echo ""
    echo "This is the right amount to install if you are using the nested"
    echo "harness (harness/run-nested.sh) rather than logging in."
    echo ""
    exit 0
fi

# -----------------------------------------------------------------------------
# Everything else needs root, because it goes into ${aq_prefix}.
# -----------------------------------------------------------------------------
if ! command -v sudo > /dev/null 2>&1; then
    echo ""
    echo "sudo is not installed, so the system parts cannot be installed."
    echo "The portal configuration above was still written."
    echo ""
    echo "You can install just that part with:"
    echo "  ./session/install-session.sh --portals-only"
    echo ""
    exit 1
fi

echo ""
echo "=== System files (you will be asked for your password) ==="

# 1. the launcher
aq_run_root install -Dm755 \
    "${AQ_SESSION_SRC}/aquarius-session" \
    "${aq_prefix}/bin/aquarius-session"

# 2. the compositor configurations
aq_run_root rm -rf "${aq_prefix}/share/aquarius-session"
aq_run_root mkdir -p "${aq_prefix}/share/aquarius-session"
aq_run_root cp -a \
    "${AQ_SESSION_SRC}/niri" \
    "${AQ_SESSION_SRC}/labwc" \
    "${aq_prefix}/share/aquarius-session/"

# 3. the shell itself
#
# Copied by default so that the installed session does not depend on a folder
# in your home directory still existing. --link symlinks the repo instead,
# which is what you want while developing: edit a .qml file, save, and the
# running shell reloads it.
aq_run_root rm -rf "${aq_prefix}/share/aquarius-shell"
if [ "${aq_link}" -eq 1 ]; then
    aq_run_root ln -s "${AQ_REPO_ROOT}" "${aq_prefix}/share/aquarius-shell"
    echo ""
    echo "    NOTE: the shell is a LINK to your working copy at"
    echo "          ${AQ_REPO_ROOT}"
    echo "          Move or delete that folder and the session stops working."
else
    aq_run_root mkdir -p "${aq_prefix}/share/aquarius-shell"
    aq_run_root cp -a \
        "${AQ_REPO_ROOT}/shell.qml" \
        "${AQ_REPO_ROOT}/theme" \
        "${AQ_REPO_ROOT}/components" \
        "${AQ_REPO_ROOT}/services" \
        "${AQ_REPO_ROOT}/assets" \
        "${aq_prefix}/share/aquarius-shell/"
fi

# 4. the login screen entry
#
# The shipped .desktop file names /usr/local/bin/aquarius-session. If a
# different prefix was asked for, rewrite those two lines rather than shipping
# a file with a placeholder in it that is broken until something substitutes it.
aq_tmp_desktop="$(mktemp)"
trap 'rm -f "${aq_tmp_desktop}"' EXIT
sed "s|/usr/local/bin/aquarius-session|${aq_prefix}/bin/aquarius-session|g" \
    "${AQ_SESSION_SRC}/aquarius.desktop" > "${aq_tmp_desktop}"
aq_run_root install -Dm644 \
    "${aq_tmp_desktop}" \
    "${aq_prefix}/share/wayland-sessions/aquarius.desktop"

# -----------------------------------------------------------------------------
# Done — and one honest warning about where sessions are read from.
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Installed."
echo "============================================================"
echo ""
echo "  Log out. At the login screen there is usually a small gear or"
echo "  a session name near the password box — that is the session"
echo "  chooser. Pick \"Aquarius Session (experimental)\"."
echo ""
echo "  If it is NOT in the list, the login screen is not reading"
echo "  ${aq_prefix}/share/wayland-sessions."
echo "  SDDM (Bazzite's login screen) reads it by default. GDM may"
echo "  not. See docs/session.md, 'the session does not appear'."
echo ""
echo "  Which compositor it starts:  niri (the default)"
echo "  To use labwc instead:"
echo "    mkdir -p ~/.config/aquarius-session"
echo "    echo labwc > ~/.config/aquarius-session/compositor"
echo ""
echo "  If it fails to start, the reason is in:"
echo "    ~/.local/state/aquarius-session/session.log"
echo ""
echo "  GNOME is untouched and is still the default. Nothing here"
echo "  can stop you logging in normally."
echo ""
