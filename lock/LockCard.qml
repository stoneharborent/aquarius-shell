// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LockCard — the card you type your password into
// =============================================================================
//
//   ┌──────────────────────────────────────────────┐
//   │                                              │
//   │                   ( RA )                     │
//   │                Royce Adkins                  │
//   │                                              │
//   │   ┌──────────────────────────────────────┐   │
//   │   │ ••••••••                             │   │
//   │   └──────────────────────────────────────┘   │
//   │   Password                                   │
//   │                                              │
//   │                   Sleep                      │
//   └──────────────────────────────────────────────┘
//
// It is the login screen's card with the parts that do not apply taken out.
// The avatar is literally the same component — greeter/GreeterAvatar.qml — so
// the face you unlock at and the face you log in at are the same face. There
// are no ‹ › arrows because there is only one person here by definition: a
// lock screen asks the person whose session this is, and nobody else.
//
// WHY THERE IS NO "SWITCH USER"
//   The approved spec asked for "Switch user · Sleep" and said, in the same
//   breath, to leave the word out if the login manager cannot do it here. It
//   cannot. AquariusOS logs in through **greetd**, and greetd's model is one
//   session at a time on a seat: there is no way to ask it for a second login
//   screen on another virtual terminal while keeping this session alive. GNOME
//   and GDM can do that; greetd does not, and pretending otherwise would put a
//   word on the lock screen that does nothing. So the row is one word.
//
// Every colour and size comes from Theme. There is not a hex value or a bare
// pixel in this file, the same rule the rest of the shell obeys.
// =============================================================================
import QtQuick

import Quickshell

import "."
import "../theme"
import "../greeter"

Rectangle {
    id: root

    // The same width and padding as the login screen's card, on purpose: they
    // are the same card. See the LOCK SCREEN block in theme/Theme.qml.
    implicitWidth: Theme.greeterCardWidth
    implicitHeight: column.implicitHeight + Theme.greeterCardPadding * 2

    radius: Theme.radiusXl

    // Frosted, not solid: the theme's card colour at 86%, over the blurred
    // wallpaper of the veil underneath.
    //
    // Written as Qt.rgba() of a Theme colour rather than as a colour with an
    // alpha channel written into theme/Ice.qml, because the alpha here is a
    // property of THIS surface — how much of the veil shows through the card —
    // and not a new colour the rest of the shell should be able to reach for.
    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b,
                   Theme.lockCardOpacity)

    border.width: Theme.hairline
    border.color: Theme.lineStrong

    // Handed up to LockSurface so it does not have to know how the card is
    // built to give it the keyboard or to shake it.
    property alias field: passwordField

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.greeterCardPadding

        spacing: Theme.greeterSectionGap

        // ---- who is being asked ---------------------------------------------
        GreeterAvatar {
            anchors.horizontalCenter: parent.horizontalCenter
            person: LockState.person
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LockState.person.real
            color: Theme.ink
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.lockNameSize
            font.weight: Font.DemiBold
            textFormat: Text.PlainText
        }

        // ---- the password ----------------------------------------------------
        LockField {
            id: passwordField

            width: parent.width

            // Quiet while PAM is thinking, and while the wait after three wrong
            // passwords is counting down. Both are moments when another Enter
            // would do nothing useful and typing would be a lie.
            enabled: !LockState.busy && !LockState.waiting

            alarmed: LockState.phase === LockState.wrong

            onAccept: LockState.submit()
            onDismiss: LockState.backToCalm()
        }

        // ---- what just happened ----------------------------------------------
        // PAM's own words wherever PAM had any. Height is kept even when there
        // is nothing to say, so the card does not jump a line taller the first
        // time you get your password wrong — which would move the box out from
        // under the cursor at exactly the wrong moment.
        Text {
            width: parent.width
            height: Theme.fsSmall + Theme.sp1
            text: LockState.status
            color: LockState.statusIsError ? Theme.danger : Theme.inkSoft
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsSmall
            elide: Text.ElideRight
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
        }

        // ---- the one thing you can do without a password ----------------------
        // A word, not an icon. An icon on a lock screen is a guess somebody has
        // to make with their hands behind their back; the whole screen has room
        // for the word.
        Text {
            id: sleepWord

            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Sleep")
            color: sleepArea.containsMouse ? Theme.accent : Theme.inkSoft
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsSmall
            textFormat: Text.PlainText

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durFast
                }
            }

            MouseArea {
                id: sleepArea

                anchors.fill: parent
                anchors.margins: -Theme.sp2   // a bigger target than the word
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                // The same front door the Aquarius menu's Sleep row uses. The
                // machine goes to sleep still locked, and wakes into the calm
                // state, because nothing here unlocked anything.
                onClicked: Quickshell.execDetached(["systemctl", "suspend"])
            }
        }
    }
}
