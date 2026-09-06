// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LockSurface — one screen's worth of lock screen
// =============================================================================
// One of these is built PER MONITOR, by the WlSessionLock in LockLayer.qml,
// the moment the machine locks. Every one of them shows the veil, the clock and
// the Aquarius mark, because a second screen must never be a black rectangle
// while somebody is typing a password into the first one.
//
// -----------------------------------------------------------------------------
// THE THREE STATES, DRAWN
// -----------------------------------------------------------------------------
//   CALM       the clock, big, in the middle of the screen. A pill saying how
//              many notifications are waiting, and one line telling you that
//              you can just start typing.
//   PASSWORD   the clock rises to near the top and halves in size; the card
//              slides up twenty-four pixels and fades in under it.
//   WRONG      the same card. The box shakes once and grows a danger ring, and
//              the line under it says so. Nothing else moves.
//
// -----------------------------------------------------------------------------
// WHICH SCREEN GETS THE CARD, AND WHY EVERY SCREEN CAN STILL BE TYPED INTO
// -----------------------------------------------------------------------------
// The card is drawn on the screen the mouse pointer is on — that is the design,
// and it is the right one: on a two-monitor desk the card should be where you
// are looking, not always on the left-hand one.
//
// But WHICH SURFACE THE KEYBOARD GOES TO IS NOT OURS TO CHOOSE. Under the
// session-lock protocol the compositor hands the keyboard to a lock surface of
// its own choosing, and labwc picks the first one that appears and keeps it
// (labwc 0.20, src/session-lock.c). On a two-monitor machine that is very
// likely NOT the screen the pointer is on.
//
// So the card exists on EVERY screen, and on the ones that are not showing it,
// it sits at zero opacity. An item at zero opacity is still there and can still
// hold the keyboard — unlike an invisible one, which cannot — so whichever
// surface the compositor chose is quietly collecting the keystrokes, and the
// text they produce lives in LockState, which the visible card is reading. You
// type on one screen and the dots appear on the other, and it looks like
// nothing at all is happening, which is exactly right.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Wayland

import "."
import "../theme"
import "../components/bar"

WlSessionLockSurface {
    id: root

    // The ground under the veil. NOT left at its default, which is white: if
    // the wallpaper is missing or still decoding, this is what is on screen for
    // a moment, and it must be a deliberate colour rather than a flash of white
    // in the middle of the night.
    color: Theme.bg

    // Which screen this is. `screen` is filled in by the WlSessionLock.
    readonly property string screenName: root.screen !== null ? root.screen.name : ""

    // Is this the screen that draws the card?
    readonly property bool showsCard: LockState.pointerScreen.length > 0
        ? LockState.pointerScreen === root.screenName
        : root.firstScreen

    // The fallback for "nobody has moved the mouse yet": the first screen the
    // system lists, which is the same one the login screen puts its card on.
    readonly property bool firstScreen: Quickshell.screens.length > 0
        && Quickshell.screens[0].name === root.screenName

    // Is the card up? Only ever true on the screen drawing it, so that the
    // clock on the OTHER screens stays big and centred instead of sliding up
    // to make room for a card that is not there.
    readonly property bool typing: root.showsCard && LockState.phase !== LockState.calm

    // ---- the veil -------------------------------------------------------------
    LockVeil {
        id: veil

        anchors.fill: parent

        // Fades in as the screen locks. There is no matching fade out: when
        // LockState unlocks, the whole surface is destroyed by the compositor
        // in one step, and an animation on a thing being destroyed is an
        // animation nobody sees.
        opacity: 0
        Component.onCompleted: veil.opacity = 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.lockVeilFadeMs
            }
        }
    }

    // ---- anything at all wakes the screen ---------------------------------------
    // A click anywhere. It deliberately does NOT take focus — the password box
    // keeps that — so clicking the wallpaper brings the card up without also
    // taking the keyboard away from it.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // This is how the card knows which screen to be on: the pointer is over
        // exactly one surface at a time, and this is that surface saying so.
        onContainsMouseChanged: {
            if (containsMouse)
                LockState.pointerOn(root.screenName);
        }

        onClicked: LockState.wake()
    }

    // ---- the mark, at the top ----------------------------------------------------
    // Small, quiet, and on every screen. It is the only thing that says whose
    // computer this is while it is locked.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.sp7
        spacing: Theme.greeterLogoGap

        LogoMark {
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.lockMarkSize
            color: Theme.inkSoft
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "AquariusOS"
            color: Theme.inkSoft
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lockWordmarkSize
            font.weight: Font.DemiBold
            textFormat: Text.PlainText
        }
    }

    // ---- the clock ----------------------------------------------------------------
    // Centred while nothing is being typed; up near the top and half the size
    // once the card is out. Both the position and the size are animated, which
    // is the whole of the movement on this screen.
    Column {
        id: clockColumn

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.sp1

        y: root.typing
            ? Math.round(root.height * Theme.lockClockTopFraction)
            : Math.round((root.height - clockColumn.implicitHeight) / 2)

        Behavior on y {
            NumberAnimation {
                duration: Theme.durMed
                easing.type: Easing.OutCubic
            }
        }

        Text {
            id: time

            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, root.timeFormat)
            color: Theme.ink
            font.family: Theme.fontDisplay
            font.pixelSize: root.typing ? Theme.lockClockTyping : Theme.lockClockCalm
            font.weight: Font.Light
            textFormat: Text.PlainText

            Behavior on font.pixelSize {
                NumberAnimation {
                    duration: Theme.durMed
                    easing.type: Easing.OutCubic
                }
            }
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

    // ---- the card ------------------------------------------------------------------
    // ⚠️ IT IS ALWAYS HERE, ON EVERY SCREEN. Read the note at the top of this
    // file: an item at zero opacity still holds the keyboard, and that is what
    // makes typing work on a two-monitor machine whatever the compositor
    // decided about focus.
    LockCard {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter

        y: clockColumn.y + clockColumn.height + Theme.greeterClockGap
           + (root.typing ? 0 : Theme.lockCardRise)

        opacity: root.typing ? 1 : 0

        Behavior on y {
            NumberAnimation {
                duration: Theme.durMed
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durMed
            }
        }
    }

    // ---- the foot --------------------------------------------------------------------
    // Two different things live down here, one per state, and they cross-fade.
    // They are stacked in the same place rather than in a Column so that the
    // one going away does not push the one arriving around as it fades.
    Item {
        id: foot

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.sp7
        width: parent.width
        height: calmFoot.implicitHeight

        // ---- CALM -------------------------------------------------------------
        Column {
            id: calmFoot

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: Theme.greeterHintGap

            opacity: root.typing ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.durMed } }

            // ---- how many, and NOTHING else ----------------------------------
            // ⚠️ A COUNT. Never a title, never a sender, never an app name,
            // never a preview. The whole point of a lock screen is that the
            // person who walks past your desk learns nothing, and "3 messages
            // from the bank" is something. Even the count can be switched off.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter

                visible: LockState.showNotificationCount
                         && LockState.notificationCount > 0

                implicitWidth: pillText.implicitWidth + Theme.greeterPillPaddingH * 2
                implicitHeight: pillText.implicitHeight + Theme.greeterPillPaddingV * 2

                radius: Theme.greeterPillRadius
                color: Theme.surfaceAlt
                border.width: Theme.hairline
                border.color: Theme.line

                Text {
                    id: pillText

                    anchors.centerIn: parent
                    text: LockState.notificationCount === 1
                        ? qsTr("1 notification waiting")
                        : qsTr("%1 notifications waiting").arg(LockState.notificationCount)
                    color: Theme.inkSoft
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsSmall
                    textFormat: Text.PlainText
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("press any key, or start typing your password")
                color: Theme.inkMute
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsMonoSm
                textFormat: Text.PlainText
            }
        }

        // ---- PASSWORD and WRONG -------------------------------------------------
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

            text: qsTr("Enter to unlock   ·   Esc to go back")
            color: Theme.inkMute
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsMonoSm
            textFormat: Text.PlainText

            opacity: root.typing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
        }
    }

    // The clock ticks once a minute. Seconds would be sixty times the wake-ups
    // for information nobody standing at a locked machine needs.
    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // 24-hour or am/pm, whichever this machine's language uses — without the
    // seconds that some countries' "short" format still carries. The same
    // trimming the bar clock and the login screen do, for the same reason.
    readonly property string timeFormat: {
        const shortFormat = Qt.locale().timeFormat(Locale.ShortFormat);
        return String(shortFormat).replace(/[.:]?s+/g, "");
    }

    // ---- the keyboard always ends up in the password box -------------------------
    // Three moments need it, and they are genuinely different:
    //
    //   the surface appears     nothing has focus yet
    //   a password was wrong    the box has just been emptied
    //   Escape was pressed      the box has just been emptied, again
    //
    // Qt.callLater rather than a direct call, because on the first of those the
    // surface may not be on screen yet, and asking a window that is not on
    // screen for focus quietly does nothing.
    //
    // EVERY surface does this, not just the one drawing the card. See the note
    // at the top: only one of them will actually get the keyboard, and which
    // one is the compositor's decision, not ours.
    Component.onCompleted: Qt.callLater(card.field.takeFocus)

    Connections {
        target: LockState

        function onAnswerWanted(): void {
            Qt.callLater(card.field.takeFocus);
        }

        // The shake. It runs on every surface; on the ones at zero opacity
        // nobody sees it, which costs nothing and keeps this file free of a
        // special case.
        function onPhaseChanged(): void {
            if (LockState.phase === LockState.wrong)
                card.field.shake();
        }
    }
}
