// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// NotificationRow — one notification, as one slab in the panel
// =============================================================================
// The design (class `.notif` in the V2 shell artboard) is a soft rounded slab
// holding four things:
//
//     ┌──────┐  Screenshot saved                            now
//     │ icon │  Added to Pictures. Click to open.
//     └──────┘  [ Open folder ]  [ Delete ]
//
//   icon chip   34x34, 9px corners — see IconChip.qml
//   title       the notification's one-line summary, in the bright ink
//   body        the detail, quieter, up to three lines
//   age         "now", "5 m", "2 h", "3 d" — mono, quietest
//   actions     only when the sending application attached any
//
// The action buttons and the reply box are NOT in the artboard. They are in the
// protocol, and a notification server that silently drops the button an
// application attached is a notification server that loses your "Reply" and your
// "Restart now". Adding them is the smallest honest thing to do; they take no
// space at all on the notifications that carry none, which is most of them.
//
// NOTHING HERE IS SEE-THROUGH. The slab, the chip and the hover tint are washes
// of the ink colour painted on top of an opaque panel — not window transparency.
// Same call the Plasma theme made on 2026-08-30 ("Glass removed"), kept so the
// two shells look like the same product while both exist.
// =============================================================================
pragma ComponentBehavior: Bound

import QtQuick

import Quickshell.Services.Notifications

import "../../theme"

Item {
    id: root

    // The live Notification object.
    property var notification: null

    // The store, for the things a row cannot decide alone (what the default
    // action is, which actions to draw).
    property var store: null

    // Ticks once a minute, from the panel. Comparing against this rather than
    // Date.now() is what makes a row's age creep up on its own while the panel
    // is open, without this file owning a timer.
    property double now: 0

    readonly property bool critical: root.notification
        && root.notification.urgency === NotificationUrgency.Critical

    readonly property var buttons: (root.store && root.notification)
        ? root.store.buttonActions(root.notification)
        : []

    readonly property bool clickable: root.store && root.notification
        && root.store.defaultAction(root.notification) !== null

    implicitHeight: content.implicitHeight + Theme.sp3 * 2

    // ---- the slab -----------------------------------------------------------
    // `surfaceAlt` is the design system's own "a card inside a card" colour, so
    // the slab reads correctly in both Ice and Midnight without this file
    // knowing which one is in force.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt

        // A critical notification is outlined rather than tinted. A tint would
        // fight the accent-coloured chip beside it; an outline reads as urgent
        // at a glance and stays legible in both palettes.
        border.width: root.critical ? Theme.hairline : 0
        border.color: Theme.danger

        // The hover tint is a separate wash laid over the slab, not a second
        // solid colour, so it lightens in Ice and lightens in Midnight without
        // two branches.
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

        // ---- chip · text · age ----------------------------------------------
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

            // The age, or — while the pointer is over the row — a close button
            // in its place.
            //
            // WHY A HOVER-REVEALED CLOSE BUTTON, WHEN THE DESIGN DRAWS NONE
            //   Without a per-row control, a single notification can only be got
            //   rid of by clearing everything. Hiding the button until the
            //   pointer arrives means the panel at rest looks exactly like the
            //   mock. (The Wave-2 Plasma widget made the same call for the same
            //   reason.)
            Item {
                id: trailing
                anchors.right: parent.right
                anchors.top: parent.top
                width: Math.max(age.implicitWidth, Theme.notifGroupIconSize)
                height: Math.max(age.implicitHeight, Theme.notifGroupIconSize)

                Text {
                    id: age
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: root.ageText
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsMonoSm
                    color: Theme.inkMute
                    textFormat: Text.PlainText
                    visible: !closeButton.visible
                }

                Text {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.top: parent.top
                    // A multiplication sign, not the letter x — it is the right
                    // shape and it is one character, which is what keeps this
                    // from needing an icon file.
                    text: "×"
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsSmall
                    color: closeHover.hovered ? Theme.ink : Theme.inkMute
                    textFormat: Text.PlainText
                    visible: hover.hovered

                    HoverHandler {
                        id: closeHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: root.notification.dismiss()
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Dismiss this notification")
                    Accessible.onPressAction: root.notification.dismiss()
                }
            }

            Column {
                id: textColumn

                anchors.left: chip.right
                anchors.leftMargin: Theme.sp3
                anchors.right: trailing.left
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
                    // Notification bodies carry a little markup — bold, italic,
                    // the occasional link. StyledText is Qt's narrow subset,
                    // which is the right amount of trust to extend to text that
                    // arrived from any application on the machine. It is not a
                    // web view and it cannot run anything.
                    textFormat: Text.StyledText
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsMicro
                    color: Theme.inkSoft
                    linkColor: Theme.accent
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    visible: text.length > 0
                }
            }
        }

        // ---- the buttons the application attached ----------------------------
        ActionButtons {
            width: content.width
            actions: root.buttons
        }

        // ---- inline reply -----------------------------------------------------
        InlineReply {
            width: content.width
            notification: root.notification
            visible: root.notification !== null && root.notification.hasInlineReply
        }
    }

    // =========================================================================
    // The text of the thing
    // =========================================================================

    // A handful of applications send no summary at all. Their own name is the
    // most useful thing left to print.
    readonly property string title: {
        if (!root.notification)
            return "";
        const summary = root.notification.summary;
        if (summary && summary.length > 0)
            return summary;
        return root.notification.appName;
    }

    // Strip <img> tags before drawing.
    //
    // The server advertises `bodyImagesSupported: false`, but that flag is only
    // a hint — an application is free to send one anyway, and Qt's StyledText
    // would happily go and fetch it. An <img src="https://..."> inside text
    // written by any application on the machine is a tracking pixel with extra
    // steps. There is no version of this panel that should load one, so the tag
    // is removed rather than trusted.
    readonly property string bodyText: {
        if (!root.notification)
            return "";
        const body = root.notification.body;
        if (!body)
            return "";
        return body.replace(/<img\b[^>]*>/gi, "");
    }

    // --- "now", "5 m", "2 h", "3 d" -----------------------------------------
    // The short, glanceable form the design asks for, rather than a sentence.
    // The panel is 350px wide and this sits at the end of a line that already
    // has a title on it.
    readonly property string ageText: {
        if (!root.store || !root.notification)
            return "";
        const arrived = root.store.arrivalOf(root.notification);
        if (arrived <= 0)
            return "";

        const seconds = Math.max(0, Math.floor((root.now - arrived) / 1000));
        if (seconds < 60)
            return qsTr("now");

        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return qsTr("%1 m").arg(minutes);

        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return qsTr("%1 h").arg(hours);

        return qsTr("%1 d").arg(Math.floor(hours / 24));
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: root.title
    Accessible.description: root.notification ? root.notification.body : ""
}
