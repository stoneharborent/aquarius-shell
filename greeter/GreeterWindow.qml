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
import Quickshell.Wayland

import "."
import "../theme"

PanelWindow {
    id: root

    // True on the one screen that shows the card and holds the keyboard.
    property bool primary: false

    // Where the wallpaper comes from. Written as properties rather than
    // straight into the Image so that the harness can point them at something
    // else on a machine that is not AquariusOS.
    property string wallpaperLight: "/usr/share/backgrounds/aquarius/the-pour-ice-3840x2160.png"
    property string wallpaperDark: "/usr/share/backgrounds/aquarius/the-pour-midnight-3840x2160.png"

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

    onVisibleChanged: {
        if (root.primary && root.visible)
            Qt.callLater(card.field.takeFocus);
    }
}
