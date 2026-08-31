// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// ActionButtons — the buttons an application attaches to a notification
// =============================================================================
// "Reply" · "Open folder" · "Restart now". They arrive as a list of
// NotificationAction objects, each carrying the words to print and a function to
// call. Used by both the toast and the panel row, which is why it is its own
// file: an action that behaves differently depending on where you press it is a
// bug that takes a week to find.
//
// The action whose identifier is "default" is NOT in this list. The
// specification reserves that one for "what happens when you click the
// notification itself", and the store filters it out before we get here.
//
// WHY A Flow AND NOT A Row
//   Applications send as many actions as they like and the panel is 350 pixels
//   wide. A Row would push the third button off the edge; a Flow wraps it onto a
//   second line. The design draws no buttons at all, so there is no arrangement
//   to be faithful to — only a shape that cannot break.
//
// https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/NotificationAction/
// =============================================================================
pragma ComponentBehavior: Bound

import QtQuick

import "../../theme"

Flow {
    id: root

    // A plain JavaScript array of NotificationAction, from
    // NotificationStore.buttonActions().
    property var actions: []

    spacing: Theme.sp2
    visible: root.actions.length > 0

    Repeater {
        model: root.actions

        delegate: Rectangle {
            id: button

            required property var modelData

            implicitWidth: label.implicitWidth + Theme.sp4
            implicitHeight: Theme.controlHeightSm
            radius: Theme.radiusSm

            color: mouse.pressed ? Theme.pressWash : Theme.hoverWash
            border.width: Theme.hairline
            border.color: mouse.containsMouse ? Theme.lineStrong : Theme.line

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durFast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeOut
                }
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: button.modelData.text
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Medium
                color: Theme.ink
                textFormat: Text.PlainText
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // `invoke()` also closes the notification, unless the sending
                // application asked to stay resident. That is the protocol's
                // rule, not a choice made here.
                onClicked: button.modelData.invoke()
            }

            Accessible.role: Accessible.Button
            Accessible.name: button.modelData.text
            Accessible.onPressAction: button.modelData.invoke()
        }
    }
}
