// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// GreeterCard — the card you actually log in with
// =============================================================================
//
//   ┌──────────────────────────────────────────────┐
//   │            ◭  AquariusOS                     │
//   │                                              │
//   │                   ( RA )                     │
//   │              ‹  Royce Adkins  ›              │
//   │                                              │
//   │   ┌──────────────────────────────────────┐   │
//   │   │ ••••••••                             │   │
//   │   └──────────────────────────────────────┘   │
//   │   Password:                                  │
//   │                                              │
//   │             ◇ Aquarius Desktop               │
//   └──────────────────────────────────────────────┘
//
// Every piece of it comes from Theme, so the screen you log in at and the
// desktop you land on are one design rather than two that resemble each other.
//
// The ‹ › either side of the name only appear when there is more than one
// account on the computer, and the desktop pill only when there is more than
// one desktop. A login screen with one account and one desktop shows neither
// and is simply a name and a password box, which is what it should be.
// =============================================================================
import QtQuick

import "."
import "../theme"
import "../components/bar"

Rectangle {
    id: root

    implicitWidth: Theme.greeterCardWidth
    implicitHeight: column.implicitHeight + Theme.greeterCardPadding * 2

    radius: Theme.radiusXl
    color: Theme.surface
    border.width: Theme.hairline
    border.color: Theme.lineStrong

    // Handed down from the window so the card does not have to know how the
    // keyboard gets to it.
    property alias field: passwordField

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.greeterCardPadding

        spacing: Theme.greeterSectionGap

        // ---- the mark ------------------------------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.greeterLogoGap

            LogoMark {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.greeterLogoSize
                color: Theme.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "AquariusOS"
                color: Theme.ink
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fsSubhead
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
            }
        }

        // ---- who is logging in ---------------------------------------------
        GreeterAvatar {
            anchors.horizontalCenter: parent.horizontalCenter
            person: GreeterState.person
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.greeterListGap

            // The two arrows are real buttons as well as a hint that the arrow
            // keys do something. They are invisible on a one-account machine,
            // where they would be a control that does nothing.
            GreeterStepArrow {
                anchors.verticalCenter: parent.verticalCenter
                visible: GreeterState.people.length > 1
                pointsLeft: true
                onTriggered: GreeterState.choosePerson(-1)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: GreeterState.person !== null
                    ? GreeterState.person.real
                    : (GreeterState.loaded ? qsTr("No accounts") : qsTr("Just a moment…"))
                color: Theme.ink
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsHeading
                textFormat: Text.PlainText
            }

            GreeterStepArrow {
                anchors.verticalCenter: parent.verticalCenter
                visible: GreeterState.people.length > 1
                pointsLeft: false
                onTriggered: GreeterState.choosePerson(1)
            }
        }

        // ---- the password ---------------------------------------------------
        GreeterField {
            id: passwordField

            width: parent.width
            echo: GreeterState.echoAnswer
            enabled: !GreeterState.launching && GreeterState.person !== null

            onAccept: {
                GreeterState.signIn(passwordField.text);
                // The box is emptied the moment its contents have been handed
                // over. A password left sitting in a text box on a screen
                // anybody can walk up to is a password on a screen anybody can
                // walk up to.
                passwordField.clear();
            }
            onDismiss: GreeterState.startOver()
            onMovePerson: step => GreeterState.choosePerson(step)
            onMoveDesktop: step => GreeterState.chooseDesktop(step)
        }

        // ---- what just happened ---------------------------------------------
        // greetd's own words, wherever greetd had any. Height is kept even when
        // there is nothing to say, so that the card does not jump a line taller
        // the first time you get your password wrong.
        Text {
            width: parent.width
            height: Theme.fsSmall + Theme.sp1
            text: GreeterState.status
            color: GreeterState.statusIsError ? Theme.danger : Theme.inkSoft
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsSmall
            elide: Text.ElideRight
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
        }

        // ---- which desktop ---------------------------------------------------
        GreeterDesktopPill {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: GreeterState.desktops.length > 0
        }
    }
}
