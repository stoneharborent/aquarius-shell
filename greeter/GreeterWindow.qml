// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// GreeterWindow — one full screen of login screen
// =============================================================================
// One of these is built per monitor. Every one of them shows the wallpaper, so
// that a second screen is never a black rectangle while you type; only the
// FIRST one carries the clock, the card and the keyboard, because there is one
// password box and it can only be in one place.
//
// -----------------------------------------------------------------------------
// WHY THIS IS A LAYER-SHELL PANEL AND NOT AN ORDINARY WINDOW
// -----------------------------------------------------------------------------
// A layer-shell surface can cover the whole screen with no title bar, no
// resizing and no way for anything to appear on top of it. That is exactly what
// a login screen is. An ordinary window would be a window: the compositor would
// draw a frame around it and, on a bad day, let something else in front.
//
// It also means the compositor underneath can be almost nothing at all — it
// only has to speak layer-shell. AquariusOS uses labwc, which it already ships.
//
// -----------------------------------------------------------------------------
// THE KEYBOARD
// -----------------------------------------------------------------------------
// A layer-shell surface gets no keyboard unless it asks. `focusable: true` is
// the portable way to ask, and it maps to OnDemand — "focus me if the system
// decides to". A login screen cannot live with "if": nobody has clicked
// anything, there is nothing else on screen, and a password box that does not
// take typing is a computer nobody can get into. So the first window upgrades
// itself to Exclusive, which means the keyboard comes here and stays here.
//
// The same guarded form the search palette uses, and for the same reason: the
// WlrLayershell attachment only exists when the window really is backed by
// layer-shell.
// =============================================================================
import QtQuick

import Quickshell
// Process, for the one file this window writes: the "the login screen has
// drawn" stamp the boot animation waits on. See announceReady() below.
import Quickshell.Io
import Quickshell.Wayland

import "."
import "../theme"

PanelWindow {
    id: root

    // True on the one screen that shows the card and holds the keyboard.
    property bool primary: false

    // Where the wallpaper comes from. Still properties, so the harness can
    // point them at something else on a machine that is not AquariusOS — but
    // their DEFAULTS come from Theme, which is the one place the two pictures
    // are named. The lock screen reads the same two. See the note beside
    // `wallpaperLight` in theme/Theme.qml.
    property string wallpaperLight: Theme.wallpaperLight
    property string wallpaperDark: Theme.wallpaperDark

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // A login screen covers everything, including any space something else
    // asked to reserve. There is nothing else, but saying so costs nothing.
    exclusionMode: ExclusionMode.Ignore

    // The ground under the wallpaper. Not transparent: if the picture is
    // missing or still loading, this is what is on screen, and it must be a
    // deliberate colour rather than whatever the compositor happens to paint.
    color: Theme.bg

    focusable: root.primary

    WlrLayershell.namespace: "aquarius-greeter"

    Component.onCompleted: {
        if (root.primary && this.WlrLayershell !== null)
            this.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive;
    }

    // =========================================================================
    // "THE LOGIN SCREEN HAS DRAWN" — the one thing the rest of the boot waits on
    // =========================================================================
    // WHY ANYTHING OUTSIDE THIS FILE CARES
    //
    //   A computer booting AquariusOS shows the Aquarius boot animation, drawn
    //   by a program called Plymouth. Somebody has to tell Plymouth to let go of
    //   the screen — and the moment to do it is not "when the login manager
    //   starts", it is "when the login screen has actually painted something".
    //   Let go any earlier and the screen goes to the text console for a second
    //   or two on the way, which is exactly the "no terminals or text during
    //   boot" Royce asked for the opposite of.
    //
    //   GNOME's own login screen does this, and this is the same handshake: the
    //   greeter touches a file when it has drawn, and the session watches for
    //   that file and then runs `plymouth quit --retain-splash`, which hands the
    //   screen over with the last frame of the animation still on it.
    //
    // THE FILE, AND WHY IT IS IN A FOLDER RATHER THAN LOOSE IN /run
    //
    //       /run/aquarius-greeter/ready
    //
    //   /run itself belongs to root, and the login screen does not run as root —
    //   it runs as greetd's own unprivileged user. So `greetd.service` makes
    //   /run/aquarius-greeter/ first, owned by that user, and this writes inside
    //   it. (An earlier draft of the contract used /run/aquarius-greeter-ready,
    //   loose in /run, which could never have been written. The watchdog accepts
    //   both; this writes the one that works.) The full contract is in the
    //   os-image repository, docs/restart/greeter-debug.md, and the plain
    //   version is in docs/greeter.md.
    //
    // WHEN IT IS WRITTEN
    //
    //   On the primary screen only — there is one login screen even on a desk
    //   with three monitors — one turn of the event loop after the window is
    //   really visible. That is the same pattern, and the same reason, as the
    //   keyboard grab above: the surface has to exist before anything can be
    //   said about it.
    //
    // IF IT FAILS, NOTHING BREAKS. Somebody running this shell on their own
    // desktop, or in the harness, has no /run/aquarius-greeter and cannot make
    // one; the touch fails, one sentence goes into the log, and the login screen
    // carries on exactly as before. The worst that happens on a real machine is
    // that the boot animation is dismissed by the watchdog's timeout instead of
    // by us — a second of plainness, not a failure to log in. A login screen may
    // never be taken down by a piece of housekeeping.
    readonly property string readyStamp:
        Quickshell.env("AQ_GREETER_READY_STAMP") || "/run/aquarius-greeter/ready"

    property bool readyAnnounced: false

    function announceReady(): void {
        if (root.readyAnnounced || !root.primary || root.readyStamp === "")
            return;
        root.readyAnnounced = true;
        readyProc.running = true;
    }

    // ⚠️ The stamp is announced from the ONE onVisibleChanged handler at the
    //   bottom of this file, not from a second one here. QML allows exactly one
    //   handler per signal on an object, and a second is not a warning — it is
    //   "Property value set multiple times" and the whole login screen fails to
    //   load. Found the moment this was written; see docs/greeter.md.

    Process {
        id: readyProc
        running: false
        command: ["touch", root.readyStamp]

        onExited: function (exitCode) {
            if (exitCode === 0)
                console.info("aquarius-greeter: drawn; touched "
                            + root.readyStamp + " so the boot animation can "
                            + "hand the screen over.");
            else
                console.info("aquarius-greeter: could not write "
                            + root.readyStamp + " (exit " + exitCode + "). The "
                            + "login screen is fine; the boot animation will "
                            + "be dismissed on a timer instead.");
        }
    }

    // ---- the wallpaper ------------------------------------------------------
    Image {
        anchors.fill: parent
        source: "file://" + (Theme.dark ? root.wallpaperDark : root.wallpaperLight)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        // The picture is 3840x2160 and the screen may not be. Telling Qt the
        // size to decode at means a laptop screen does not hold an 8-megapixel
        // image in memory to draw two million pixels of it.
        sourceSize.width: root.width
        sourceSize.height: root.height
        smooth: true
    }

    // ---- everything you interact with ---------------------------------------
    Column {
        id: middle

        visible: root.primary
        anchors.centerIn: parent
        spacing: Theme.greeterClockGap

        // ---- the clock ------------------------------------------------------
        // Above the card, on the wallpaper, the way a lock screen has one. It
        // is the cheapest possible signal that the computer is awake and
        // working rather than stuck.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.sp1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, root.timeFormat)
                color: Theme.ink
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fsHero
                font.weight: Font.Light
                textFormat: Text.PlainText
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale().toString(clock.date, "dddd d MMMM")
                color: Theme.inkSoft
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsSubhead
                textFormat: Text.PlainText
            }
        }

        // ---- the card -------------------------------------------------------
        GreeterCard {
            id: card

            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ---- what the keyboard does -----------------------------------------
        // Written out rather than assumed. This screen is keyboard-only for
        // anybody who arrives at it without a mouse plugged in, and a hint line
        // is the difference between "there is one account on this machine" and
        // "I did not know I could press Up".
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hintText
            color: Theme.inkMute
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsMonoSm
            textFormat: Text.PlainText
        }
    }

    // The clock ticks once a minute. Seconds would be sixty times the wake-ups
    // for information nobody logging in needs.
    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // 24-hour or am/pm, whichever this machine's language uses — without the
    // seconds that some countries' "short" format still carries. The same
    // trimming the bar clock does, for the same reason.
    readonly property string timeFormat: {
        const shortFormat = Qt.locale().timeFormat(Locale.ShortFormat);
        return String(shortFormat).replace(/[.:]?s+/g, "");
    }

    readonly property string hintText: {
        const parts = [qsTr("Enter to sign in"), qsTr("Esc to start over")];
        if (GreeterState.people.length > 1)
            parts.push(qsTr("↑ ↓ for another account"));
        if (GreeterState.desktops.length > 1)
            parts.push(qsTr("← → for another desktop"));
        return parts.join("   ·   ");
    }

    // ---- the keyboard always ends up in the password box ---------------------
    // Three moments need it and they are genuinely different:
    //
    //   the window appears        nothing has focus yet
    //   greetd asks a question    the box has just been emptied
    //   a password was wrong      the box has just been emptied, again
    //
    // Qt.callLater rather than a direct call, because on the first of those the
    // surface may not exist yet, and asking a window that is not on screen for
    // focus quietly does nothing.
    Connections {
        target: GreeterState
        enabled: root.primary

        function onAnswerWanted(): void {
            card.field.clear();
            Qt.callLater(card.field.takeFocus);
        }
    }

    // The one handler for this signal on this object, doing two things — see
    // the warning beside the ready stamp above. Both wait one turn of the event
    // loop, because the surface has to exist before anything can be said about
    // it or focused inside it.
    onVisibleChanged: {
        if (!root.visible)
            return;
        if (root.primary)
            Qt.callLater(card.field.takeFocus);
        // "The login screen has drawn" — what the boot animation waits for.
        Qt.callLater(() => root.announceReady());
    }
}
