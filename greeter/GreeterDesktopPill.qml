// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// GreeterDesktopPill — which desktop you are about to log in to
// =============================================================================
// AquariusOS ships two: the Aquarius Desktop, which is ours, and GNOME, which
// is the permanent fallback. The first is the default because it is the one on
// the box; the second is one keypress away and always will be.
//
// Clicking the pill moves to the next one, and so do the Left and Right arrow
// keys. On a machine with only one desktop the pill still shows what it is,
// because knowing what you are about to start is useful even when there is no
// choice about it — it just cannot be clicked.
// =============================================================================
import QtQuick

import "."
import "../theme"

Item {
    id: root

    readonly property bool canChange: GreeterState.desktops.length > 1
        && !GreeterState.launching

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Rectangle {
        id: pill

        implicitWidth: label.implicitWidth + Theme.greeterPillPaddingH * 2
        implicitHeight: label.implicitHeight + Theme.greeterPillPaddingV * 2

        radius: Theme.greeterPillRadius
        color: !root.canChange ? Theme.tileIdle
             : mouse.pressed ? Theme.tileActiveHover
             : mouse.containsMouse ? Theme.tileHover
             : Theme.tileIdle
        border.width: Theme.hairline
        border.color: Theme.line

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFast
            }
        }

        Text {
            id: label

            anchors.centerIn: parent
            text: GreeterState.desktop !== null
                ? GreeterState.desktop.name
                : qsTr("No desktop")
            color: Theme.inkSoft
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsCaption
            textFormat: Text.PlainText
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: root.canChange
        enabled: root.canChange
        cursorShape: Qt.PointingHandCursor
        onClicked: GreeterState.chooseDesktop(1)
    }
}
