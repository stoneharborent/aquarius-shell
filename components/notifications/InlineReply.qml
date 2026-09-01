// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// InlineReply — answering a message without opening the application
// =============================================================================
// Some chat applications attach a reply field to their notifications. The
// protocol calls it an inline reply: the server shows a text box, the person
// types, and the answer goes straight back to the application over the same
// D-Bus connection the notification arrived on.
//
//     ┌──────────────────────────────────────────┬──────┐
//     │ Message                                  │ Send │
//     └──────────────────────────────────────────┴──────┘
//
// This only ever appears when `Notification.hasInlineReply` is true, which
// itself only happens because NotificationStore advertises
// `inlineReplySupported: true`. If we stopped advertising it, applications would
// stop offering it and this file would never be seen — the flag and the box have
// to travel together.
//
// WHY A RAW TextInput AND NOT QtQuick.Controls' TextField
//   QtQuick.Controls brings a whole style with it — its own colours, its own
//   metrics, its own idea of what a focus ring looks like. Every one of those is
//   a second opinion about design, and this repo has exactly one source of truth
//   for that. A TextInput inside a themed Rectangle is thirty more lines and no
//   second opinion.
//
// TYPING HERE NEEDS KEYBOARD FOCUS, which the panel's window asks the compositor
// for (`focusable: true` in NotificationPanelWindow.qml). That request is the
// least-proven part of this component — see docs/notifications.md.
//
// https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/Notification/
// =============================================================================
import QtQuick

import "../../theme"

Item {
    id: root

    property var notification: null

    implicitHeight: Theme.controlHeightSm

    function send(): void {
        const text = field.text.trim();
        if (text.length === 0 || !root.notification)
            return;
        root.notification.sendInlineReply(text);
        field.text = "";
    }

    Rectangle {
        id: box

        anchors.left: parent.left
        anchors.right: sendButton.left
        anchors.rightMargin: Theme.sp2
        height: parent.height

        radius: Theme.radiusSm
        color: Theme.surface
        border.width: Theme.hairline
        border.color: field.activeFocus ? Theme.accent : Theme.line

        TextInput {
            id: field

            anchors.fill: parent
            anchors.leftMargin: Theme.sp2
            anchors.rightMargin: Theme.sp2
            verticalAlignment: TextInput.AlignVCenter

            font.family: Theme.fontBody
            font.pixelSize: Theme.fsMicro
            color: Theme.ink
            selectionColor: Theme.accent
            selectedTextColor: Theme.inkOnAccent

            clip: true
            selectByMouse: true

            onAccepted: root.send()

            Accessible.role: Accessible.EditableText
            Accessible.name: placeholder.text
        }

        // The application supplies its own wording for this ("Reply to Mika",
        // "Message"). Its own is always better than ours, so ours is only used
        // when it sent none.
        Text {
            id: placeholder

            anchors.left: parent.left
            anchors.leftMargin: Theme.sp2
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (!root.notification)
                    return "";
                const supplied = root.notification.inlineReplyPlaceholder;
                return (supplied && supplied.length > 0) ? supplied : qsTr("Reply");
            }
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsMicro
            color: Theme.inkMute
            textFormat: Text.PlainText
            visible: field.text.length === 0 && !field.activeFocus
        }
    }

    Rectangle {
        id: sendButton

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: sendLabel.implicitWidth + Theme.sp4
        height: parent.height
        radius: Theme.radiusSm

        readonly property bool ready: field.text.trim().length > 0

        color: sendButton.ready ? Theme.accentWash : Theme.hoverWash
        border.width: Theme.hairline
        border.color: sendMouse.containsMouse ? Theme.lineStrong : Theme.line

        Text {
            id: sendLabel
            anchors.centerIn: parent
            text: qsTr("Send")
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Medium
            color: sendButton.ready ? Theme.ink : Theme.inkMute
            textFormat: Text.PlainText
        }

        MouseArea {
            id: sendMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: sendButton.ready
            cursorShape: Qt.PointingHandCursor
            onClicked: root.send()
        }

        Accessible.role: Accessible.Button
        Accessible.name: sendLabel.text
        Accessible.onPressAction: root.send()
    }
}
