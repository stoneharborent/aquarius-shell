// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LockIdle — what happens when you walk away from the machine
// =============================================================================
// Three things, at three times, and they are the spec's defaults:
//
//    5 minutes   DIM       the screen goes dark but stays on. Touch anything
//                          and it comes straight back. Nothing is locked yet.
//   10 minutes   LOCK      the lock screen appears.
//   15 minutes   OFF       the monitor is put to sleep. Touch anything and it
//                          wakes into the lock screen's calm state.
//
// The numbers are Theme.lockIdleDimSeconds / lockIdleLockSeconds /
// lockIdleOffSeconds. They will get a Settings page in plain language later; for
// now that is where they are changed.
//
// -----------------------------------------------------------------------------
// HOW THE SHELL KNOWS YOU WALKED AWAY
// -----------------------------------------------------------------------------
// It does not count anything itself. It ASKS THE COMPOSITOR, through the
// standard `ext-idle-notify-v1` protocol, which is exactly the protocol every
// other Wayland idle daemon uses (`swayidle` is nothing but a command-line
// front end to it). Quickshell wraps it as `IdleMonitor`: you say how many
// seconds, and it tells you when that many have passed with nobody touching
// anything, and again the moment they do.
//
// Doing it this way rather than with our own timer matters, because the
// compositor knows things a timer cannot: it sees the keyboard and the mouse
// including in full-screen games, it knows about every screen, and it knows who
// has asked it to leave the machine alone.
//
// -----------------------------------------------------------------------------
// THE APPS THAT ASK TO BE LEFT ALONE — AND WHY THIS IS ONE LINE
// -----------------------------------------------------------------------------
// A video player, DaVinci Resolve exporting, OBS recording, a film playing in a
// browser: all of them tell the compositor "do not treat this machine as idle",
// through `idle-inhibit-unstable-v1`. That is what stops the screen locking in
// the middle of a two-hour export.
//
// `respectInhibitors: true` is how we honour it, and it is the DEFAULT — it is
// written out below anyway, because a thing this important should be visible
// in the file rather than inherited silently. It makes Quickshell ask the
// compositor for the ordinary kind of idle notification, which labwc suppresses
// while any inhibitor is alive (labwc 0.20, src/idle.c). Setting it to false
// would ask for the OTHER kind, which ignores inhibitors — and a lock screen
// that ignores "I am recording" is a lock screen that ruins a take.
//
// -----------------------------------------------------------------------------
// TURNING THE SCREEN OFF
// -----------------------------------------------------------------------------
// There is no Quickshell type for this, so it is one of the very few places in
// this shell that runs a command: `wlopm`, which speaks the standard
// wlr-output-power-management protocol that labwc implements. labwc's own
// documentation recommends exactly this tool and warns AGAINST the obvious
// alternative — `wlr-randr --off` — because that one re-arranges your windows
// on the way back. Ours does not, and neither does this.
//
// The `*` is not a shell wildcard, and there is no shell here to expand it:
// wlopm takes it as the literal word meaning "every output". That is why it is
// passed as its own word in the list and not wrapped in quotes.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Wayland

import "."
import "../theme"

Scope {
    id: root

    // A single switch for the whole thing. Off means the machine never locks or
    // dims by itself; Super+L and the menu still work. Nothing sets this to
    // false yet — the Settings page that will is not written.
    property bool enabled: true

    // ---- 5 minutes: dim ------------------------------------------------------
    IdleMonitor {
        id: dimWatch

        enabled: root.enabled
        timeout: Theme.lockIdleDimSeconds
        respectInhibitors: true
    }

    // ---- 10 minutes: lock ----------------------------------------------------
    IdleMonitor {
        id: lockWatch

        enabled: root.enabled
        timeout: Theme.lockIdleLockSeconds
        respectInhibitors: true

        onIsIdleChanged: {
            if (lockWatch.isIdle)
                LockState.lock();
        }
    }

    // ---- 15 minutes: screen off ----------------------------------------------
    IdleMonitor {
        id: offWatch

        enabled: root.enabled
        timeout: Theme.lockIdleOffSeconds
        respectInhibitors: true

        // ⚠️ ONLY TURN THE SCREEN BACK ON IF WE TURNED IT OFF.
        //
        // Without this, the shell would run `wlopm --on` once at every login,
        // because `isIdle` starts false and a QML property's change handler
        // fires when it settles. That is a subprocess and a message to the
        // compositor for no reason, at the busiest moment of the session — and
        // on a machine where somebody had deliberately switched a monitor off,
        // it would switch it back on as they logged in.
        property bool weTurnedItOff: false

        onIsIdleChanged: {
            // Two words that have to be in separate list entries: this does not
            // run in a shell, so nothing would split "--off *" for us.
            if (offWatch.isIdle) {
                offWatch.weTurnedItOff = true;
                Quickshell.execDetached(["wlopm", "--off", "*"]);
            } else if (offWatch.weTurnedItOff) {
                offWatch.weTurnedItOff = false;
                Quickshell.execDetached(["wlopm", "--on", "*"]);
            }
        }
    }

    // ==========================================================================
    // THE DIM ITSELF
    // ==========================================================================
    // A dark sheet over every screen, faded in over the same time the veil
    // takes. Not a backlight change: `brightnessctl` only reaches a laptop's
    // built-in panel, and this machine's screen is a 55-inch monitor on the end
    // of a cable. A sheet works on every screen a compositor has.
    //
    // ⚠️ IT MUST NOT SWALLOW CLICKS, and `mask: Region {}` is how that is asked
    // for: an empty input region means the compositor sends this window no
    // pointer events at all and they go to whatever is underneath. Without it,
    // the first click after five minutes would land on a sheet of glass and be
    // eaten.
    //
    // And if that ever turns out to be wrong on the bench, the failure is small
    // and self-healing rather than a frozen desktop: the compositor sees the
    // click whatever surface it lands on, so it stops calling the machine idle,
    // so `dimWatch.isIdle` goes false and the sheet disappears. The cost of
    // being wrong here is one lost click, not a machine you cannot use.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: sheet

            required property var modelData

            screen: sheet.modelData
            visible: root.enabled && dimWatch.isIdle

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // A dim must not push the bar or the dock around.
            exclusionMode: ExclusionMode.Ignore

            // Nothing is painted at the window level; the rectangle inside does
            // the painting, so that it can be animated.
            color: "transparent"

            // No keyboard, ever. This window is a piece of shading.
            focusable: false

            // See the ⚠️ above. An empty region is the whole point.
            mask: Region {}

            WlrLayershell.namespace: "aquarius-shell-dim"

            Rectangle {
                anchors.fill: parent
                color: Theme.dimInk
                opacity: sheet.visible ? Theme.lockDimWash : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.lockVeilFadeMs
                    }
                }
            }
        }
    }
}
