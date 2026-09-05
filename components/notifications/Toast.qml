// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// Toast — one notification, as it arrives
// =============================================================================
// The popup that appears on its own when something happens, waits a few seconds,
// and goes away. It is the same content as a panel row and deliberately the same
// shape, because they are the same thing at two moments in its life: this is what
// it looks like when it arrives, and NotificationRow is what it looks like when
// you go back and look for it.
//
//     ┌──────────────────────────────────────────────┐
//     │ ┌──────┐  Screenshot saved                 × │
//     │ │ icon │  Added to Pictures. Click to open.  │
//     │ └──────┘  [ Open folder ]                    │
//     └──────────────────────────────────────────────┘
//
// THE DESIGN DOES NOT DRAW THIS, and that is worth saying out loud rather than
// pretending otherwise. The V2 artboards draw the notifications PANEL and the
// bar; there is no toast anywhere in the design system. So its placement is a
// decision made here, and the reasoning is:
//
//   * It uses the panel's exact geometry — 350 wide, top right, 8px under the
//     bar, 12px in from the edge. A notification therefore appears in the same
//     place it will later be found, and the panel opening over it reads as the
//     same object growing rather than a second unrelated surface.
//   * It is NOT centred at the top like GNOME's. A creator watching a preview or
//     a timeline has their eye in the middle of the screen; the top centre is
//     the worst place to put something that covers what you are looking at.
//
// HOW LONG IT STAYS: NotificationStore.toastTimeout() decides, and there is a
// long note there about the one unresolved question in that sum.
// =============================================================================
pragma ComponentBehavior: Bound

import QtQuick

import Quickshell.Services.Notifications

import "../../theme"

Item {
    id: root

    property var notification: null
    property var store: null

    readonly property bool critical: root.notification
        && root.notification.urgency === NotificationUrgency.Critical

    readonly property var buttons: (root.store && root.notification)
        ? root.store.buttonActions(root.notification)
        : []

    readonly property bool clickable: root.store && root.notification
        && root.store.defaultAction(root.notification) !== null

    // 0-100 while the sender is reporting a job, -1 the rest of the time.
    readonly property int percent: (root.store && root.notification)
        ? root.store.progressOf(root.notification)
        : -1

    implicitHeight: content.implicitHeight + Theme.sp3 * 2

    // ---- how long it lives --------------------------------------------------
    // A zero interval means "never on its own" — a critical notification, or one
    // whose sender explicitly asked for it to stay. `running` is false in that
    // case, so nothing counts down at all.
    readonly property int lifetime: (root.store && root.notification)
        ? root.store.toastTimeout(root.notification)
        : 0

    Timer {
        interval: Math.max(1, root.lifetime)
        running: root.lifetime > 0 && !hover.hovered
        repeat: false
        onTriggered: root.store.hideToast(root.notification)
    }

    // Hovering pauses the countdown, and because a Timer restarts from the
    // beginning when it is set running again, moving the pointer away gives the
    // full time back rather than the two seconds that were left. That is the
    // behaviour a person expects from "I am reading this".

    // ---- the card -----------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surface

        // A little heavier than a panel row's border: this one is floating over
        // whatever the person is actually doing and has to separate itself from
        // a photograph, a timeline or a game.
        border.width: Theme.hairline
        border.color: root.critical ? Theme.danger : Theme.lineStrong

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.hoverWash
            visible: hover.hovered
        }
    }

    HoverHandler {
        id: hover
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.clickable
        onTapped: root.store.activate(root.notification)
    }

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.sp3
        spacing: Theme.sp2

        Item {
            width: content.width
            implicitHeight: Math.max(chip.height, textColumn.implicitHeight)

            IconChip {
                id: chip
                anchors.left: parent.left
                anchors.top: parent.top
                notification: root.notification
                tint: root.critical ? Theme.danger : Theme.accent
            }

            Text {
                id: closeButton
                anchors.right: parent.right
                anchors.top: parent.top
                text: "×"
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsSmall
                color: closeHover.hovered ? Theme.ink : Theme.inkMute
                textFormat: Text.PlainText
                // Always visible on a toast, unlike in the panel. A toast is on
                // top of your work and the way to get rid of it should not be a
                // thing you have to discover.
                visible: root.notification !== null

                HoverHandler {
                    id: closeHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.store.closeFromToast(root.notification)
                }

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Dismiss this notification")
                Accessible.onPressAction: root.store.closeFromToast(root.notification)
            }

            Column {
                id: textColumn

                anchors.left: chip.right
                anchors.leftMargin: Theme.sp3
                anchors.right: closeButton.left
                anchors.rightMargin: Theme.sp2
                anchors.top: parent.top
                spacing: Theme.sp1

                Text {
                    width: parent.width
                    text: root.title
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsCaption
                    font.weight: Font.DemiBold
                    color: Theme.ink
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }

                Text {
                    width: parent.width
                    text: root.bodyText
                    // Same narrow markup subset and the same <img> stripping as
                    // the panel row — see NotificationRow.qml for why.
                    textFormat: Text.StyledText
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsMicro
                    color: Theme.inkSoft
                    linkColor: Theme.accent
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    visible: text.length > 0
                }
            }
        }

        // ---- the bar, when the sender is reporting a job ---------------------
        // Nothing here when there is no `value` hint, which is almost every
        // notification: `visible: false` on an Item in a Column takes no space.
        ProgressBar {
            width: content.width
            percent: root.percent
            fill: root.critical ? Theme.danger : Theme.accent
            visible: root.percent >= 0
        }

        ActionButtons {
            width: content.width
            actions: root.buttons
        }
    }

    // ---- arriving -----------------------------------------------------------
    // Slides in from the right edge and fades up. Nothing animates on the way
    // out: the toast is removed from the list the moment it is finished, and
    // there is no object left to animate. Same trade as the panel — recorded in
    // docs/notifications.md.
    // Flipped once, from the root object's own completion. A Behavior is
    // deliberately inert while its component is being built, so a value set
    // from a CHILD's Component.onCompleted may or may not animate depending on
    // construction order. The root's completion runs after every child's, which
    // makes this the one moment the animation is certain to be live.
    property bool shown: false
    Component.onCompleted: root.shown = true

    opacity: root.shown ? 1 : 0

    transform: Translate {
        x: root.shown ? 0 : Theme.sp4
        Behavior on x {
            NumberAnimation {
                duration: Theme.durMed
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeOut
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durMed
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeOut
        }
    }

    readonly property string title: {
        if (!root.notification)
            return "";
        const summary = root.notification.summary;
        if (summary && summary.length > 0)
            return summary;
        return root.notification.appName;
    }

    readonly property string bodyText: {
        if (!root.notification)
            return "";
        const body = root.notification.body;
        if (!body)
            return "";
        return body.replace(/<img\b[^>]*>/gi, "");
    }

    Accessible.role: Accessible.AlertMessage
    Accessible.name: root.title
    Accessible.description: root.notification ? root.notification.body : ""
}
