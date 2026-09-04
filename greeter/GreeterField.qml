// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// GreeterField — the box you type your password into
// =============================================================================
// It is the only thing on the login screen that ever has the keyboard, and
// every key the login screen understands is handled here, because the box is
// where focus lives and moving focus somewhere else would mean you could no
// longer type.
//
//   Enter          sign in
//   Escape         start over — empty the box, forget the attempt
//   Up / Down      a different person (only when there is more than one)
//   Left / Right   a different desktop (only when there is more than one)
//
// WHY TextInput AND NOT TextField — the same reason as the search box:
// TextField brings a whole style engine that then has to be argued out of
// drawing its own background and focus ring in somebody else's design language.
// TextInput is a cursor and a string with no opinions, and everything visible
// here comes from Theme.
//
// ⚠️ `echoMode` IS BOUND, NOT SET ONCE. greetd decides per question whether the
// answer is secret. A password is; a code from an authenticator app is not, and
// showing that one as dots would be actively unhelpful. Binding it means the
// box changes with the question rather than being told twice.
// =============================================================================
import QtQuick

import "../theme"

Item {
    id: root

    property alias text: input.text

    // Show the typing, or hide it behind dots?
    property bool echo: false

    // Everything goes quiet while a desktop is starting.
    property bool enabled: true

    property string placeholder: qsTr("Password")

    signal accept()
    signal dismiss()
    signal movePerson(int step)
    signal moveDesktop(int step)

    implicitHeight: Theme.controlHeight

    function takeFocus(): void {
        input.forceActiveFocus();
    }

    function clear(): void {
        input.text = "";
    }

    Rectangle {
        id: box

        anchors.fill: parent
        radius: Theme.radiusSm
        color: root.enabled ? Theme.bgSoft : Theme.tileDisabled
        border.width: Theme.hairline
        border.color: input.activeFocus ? Theme.accent : Theme.lineStrong

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durFast
            }
        }
    }

    TextInput {
        id: input

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.greeterFieldPaddingH
        anchors.rightMargin: Theme.greeterFieldPaddingH
        anchors.verticalCenter: parent.verticalCenter

        enabled: root.enabled

        font.family: Theme.fontBody
        font.pixelSize: Theme.fsSubhead
        color: Theme.ink
        selectionColor: Theme.accentWash
        selectedTextColor: Theme.ink

        echoMode: root.echo ? TextInput.Normal : TextInput.Password
        // The dot Qt draws for a hidden character. Set explicitly because Qt's
        // default is a bullet that renders as an empty box in some typefaces,
        // and "my password box shows squares" is a bug report nobody enjoys.
        passwordCharacter: "•"
        passwordMaskDelay: 0

        activeFocusOnPress: true
        selectByMouse: true
        clip: true

        Accessible.role: Accessible.EditableText
        Accessible.name: root.placeholder

        // Every handler names its `event` and accepts it. Both matter: Qt 6
        // warns about handlers that use the implicit `event`, and an unaccepted
        // arrow key carries on to Qt's own focus navigation — which in a window
        // with one focusable item means focus quietly goes nowhere and typing
        // stops. That is the bug that makes a login screen look frozen.
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
        Keys.onUpPressed: event => {
            root.movePerson(-1);
            event.accepted = true;
        }
        Keys.onDownPressed: event => {
            root.movePerson(1);
            event.accepted = true;
        }
        Keys.onLeftPressed: event => {
            root.moveDesktop(-1);
            event.accepted = true;
        }
        Keys.onRightPressed: event => {
            root.moveDesktop(1);
            event.accepted = true;
        }
        // Tab has nowhere to go on this screen — there is one control. Sending
        // it to the desktop picker is more useful than losing focus with it.
        Keys.onTabPressed: event => {
            root.moveDesktop(1);
            event.accepted = true;
        }
        Keys.onBacktabPressed: event => {
            root.moveDesktop(-1);
            event.accepted = true;
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
