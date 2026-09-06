// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LockField — the box you type your password into on the lock screen
// =============================================================================
// WHY THIS IS NOT greeter/GreeterField.qml, WHICH LOOKS ALMOST THE SAME
//
// It was going to be. Three things stopped it, and they are worth writing down
// so nobody spends an afternoon merging them back together:
//
//   1. THE KEYS ARE DIFFERENT. The login screen's box uses Up/Down to change
//      account and Left/Right to change desktop. There is one account and no
//      desktop choice on a lock screen, so those four keys have nothing to do —
//      and a box that swallows the arrow keys for no reason is a box that feels
//      broken.
//
//   2. THE BOX DOES NOT OWN THE TEXT. On a two-monitor machine there is one of
//      these per screen, and the compositor decides which of them the keyboard
//      goes to — which need not be the one the card is drawn on. So the text
//      lives in LockState and every box is a window onto it. That inverts the
//      login screen's arrangement, where the box holds its own text and hands
//      it over on Enter.
//
//   3. IT IS A DIFFERENT SIZE. 48 tall with a 12 corner, from the approved
//      spec, against the shell's standard control height and small radius.
//
// What IS shared is everything that matters: the colours, the typeface, the
// focus ring, and the reason for using TextInput rather than TextField — a
// style engine that then has to be argued out of drawing its own background is
// a fight, and TextInput is a cursor and a string with no opinions.
//
// ⚠️ IT ALWAYS EXISTS, EVEN IN THE CALM STATE. That is the whole type-ahead
// trick: in the calm state the card is at zero opacity, this box is invisible,
// and it still has the keyboard — so the first characters somebody types while
// walking up to the machine land in it instead of on the floor. See the header
// of LockState.qml.
// =============================================================================
import QtQuick

import "."
import "../theme"

Item {
    id: root

    // Draw as unavailable — while PAM is thinking, and while the wait after
    // three wrong passwords counts down.
    //
    // ⚠️ THIS IS NOT `enabled`, AND THAT IS DELIBERATE. Setting an Item's
    // `enabled` to false disables everything inside it, and a disabled item
    // CANNOT HOLD THE KEYBOARD. The box would lose focus for the ten seconds of
    // the wait and nothing would give it back, so the first thing typed
    // afterwards would go nowhere — which looks exactly like a frozen lock
    // screen.
    //
    // So the box stays alive and focused the whole time and only LOOKS quiet.
    // What actually refuses to act is LockState.submit(), which does nothing
    // while it is busy or waiting. Typing during the countdown fills the box,
    // and Enter starts working again the moment the count reaches zero.
    property bool quiet: false

    // Draw the danger ring — the box has just been told no.
    property bool alarmed: false

    property string placeholder: qsTr("Password")

    signal accept()
    signal dismiss()

    implicitHeight: Theme.lockFieldHeight

    function takeFocus(): void {
        input.forceActiveFocus();
    }

    // ---- the shake -----------------------------------------------------------
    // Three moves of six pixels, the whole thing over 240 ms, and nothing else
    // on the card moves. LockSurface calls shake() when a password was wrong.
    //
    // It moves THIS number and the two drawn things read it, rather than
    // animating `x` directly. Inside a Column, `x` belongs to the Column — an
    // animation that writes to it is a tug of war with the layout, and the
    // layout wins at the worst possible moment.
    property real shakeOffset: 0

    function shake(): void {
        shaker.restart();
    }

    SequentialAnimation {
        id: shaker

        // Six steps of 40 ms is 240 ms, and six steps is three there-and-backs.
        NumberAnimation { target: root; property: "shakeOffset"; to: Theme.lockShakeDistance; duration: Theme.lockShakeMs / 6 }
        NumberAnimation { target: root; property: "shakeOffset"; to: -Theme.lockShakeDistance; duration: Theme.lockShakeMs / 6 }
        NumberAnimation { target: root; property: "shakeOffset"; to: Theme.lockShakeDistance; duration: Theme.lockShakeMs / 6 }
        NumberAnimation { target: root; property: "shakeOffset"; to: -Theme.lockShakeDistance; duration: Theme.lockShakeMs / 6 }
        NumberAnimation { target: root; property: "shakeOffset"; to: Theme.lockShakeDistance; duration: Theme.lockShakeMs / 6 }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: Theme.lockShakeMs / 6 }
    }

    Rectangle {
        id: box

        x: root.shakeOffset
        y: 0
        width: parent.width
        height: parent.height

        radius: Theme.lockFieldRadius
        color: root.quiet ? Theme.tileDisabled : Theme.bgSoft

        // Two pixels of danger when the password was wrong, one hairline the
        // rest of the time. The width changes as well as the colour, because a
        // colour alone is not enough for somebody who does not see red.
        border.width: root.alarmed ? Theme.lockRingWidth : Theme.hairline
        border.color: root.alarmed
            ? Theme.danger
            : (input.activeFocus ? Theme.accent : Theme.lineStrong)

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durFast
            }
        }

        TextInput {
            id: input

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.greeterFieldPaddingH
            anchors.rightMargin: Theme.greeterFieldPaddingH
            anchors.verticalCenter: parent.verticalCenter

            font.family: Theme.fontBody
            font.pixelSize: Theme.fsSubhead
            color: Theme.ink
            selectionColor: Theme.accentWash
            selectedTextColor: Theme.ink

            // Always dots. Unlike the login screen, which shows a one-time code
            // from a phone in the clear when the system asks for one, this box
            // only ever carries a password — LockState refuses any other kind
            // of question rather than showing the answer as bullets.
            echoMode: TextInput.Password
            // Set explicitly because Qt's default bullet renders as an empty box
            // in some typefaces, and "my password box shows squares" is a bug
            // report nobody enjoys.
            passwordCharacter: "•"
            passwordMaskDelay: 0

            activeFocusOnPress: true
            selectByMouse: false
            clip: true

            Accessible.role: Accessible.EditableText
            Accessible.name: root.placeholder

            // ---- a window onto LockState.answer, not its owner --------------
            // `textEdited` fires ONLY when a person changed the text, never when
            // the binding above assigns it. That is what stops the two from
            // chasing each other round in a loop.
            text: LockState.answer
            onTextEdited: LockState.type(input.text)

            // Every handler names its `event` and accepts it. Both matter: Qt 6
            // warns about handlers that use the implicit `event`, and an
            // unaccepted key carries on to Qt's own focus navigation — which in
            // a window with one focusable item means focus quietly goes nowhere
            // and typing stops. That is the bug that makes a lock screen look
            // frozen.
            Keys.onReturnPressed: event => {
                root.accept();
                event.accepted = true;
            }
            Keys.onEnterPressed: event => {
                root.accept();
                event.accepted = true;
            }
            Keys.onEscapePressed: event => {
                root.dismiss();
                event.accepted = true;
            }

            // ---- ANY key wakes the screen ----------------------------------
            // This runs BEFORE the key is turned into text, and it deliberately
            // does NOT accept the event, so the keystroke goes on to be typed as
            // usual. It is how pressing Space, or an arrow key, brings the card
            // up without also having to type something.
            Keys.onPressed: event => {
                LockState.wake();
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                visible: input.text.length === 0
                text: root.placeholder
                font: input.font
                color: Theme.inkMute
                textFormat: Text.PlainText
            }
        }
    }
}
