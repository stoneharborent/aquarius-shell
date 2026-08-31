// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// NotificationGroup — every notification from one application, folded together
// =============================================================================
// This is the GNOME 48 idea, and it is the single most useful thing a
// notification list can do. Collapsed, an application takes up one slab no
// matter how much it has been talking:
//
//     ▣ Messages                            3   ⌄
//     ┌──────────────────────────────────────────┐
//     │ ▢  Mika                              4 h │
//     │    "stream starting in 10 — you in?"     │
//     └──────────────────────────────────────────┘
//      └────────────────────────────────────────┘   <- the ones behind it
//
// Expanded, they all show. The header counts them, and clearing the group
// clears that application and nothing else.
//
// WHY THIS AND NOT THE FLAT LIST IN THE ARTBOARD
//   The V2 artboard draws three notifications from three different applications,
//   which is a flat list and a grouped list at the same time — it does not tell
//   you what happens on a morning when one chat has said eleven things. Grouping
//   is what keeps everything else visible on that morning. It is the one
//   deliberate departure from the drawing in this whole track, and it is written
//   up in docs/notifications.md.
//
// The peeking slab underneath is how a collapsed group SHOWS that there is more
// behind it, rather than only saying so with a number. It is drawn from the same
// surface colour, inset and shortened, so it reads as depth without any shadow.
// =============================================================================
pragma ComponentBehavior: Bound

import QtQuick

import "../../theme"

Item {
    id: root

    // One entry from NotificationStore.groups.
    property var group: null
    property var store: null

    // Ticks once a minute; passed down so every row's age moves together.
    property double now: 0

    readonly property bool foldable: root.group && root.group.count > 1
    readonly property bool expanded: root.group ? root.group.expanded === true : false

    // Collapsed: only the newest. Expanded: all of them.
    readonly property var visibleItems: {
        if (!root.group)
            return [];
        if (root.expanded || root.group.count <= 1)
            return root.group.items;
        return [root.group.items[0]];
    }

    implicitHeight: column.implicitHeight

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.sp2

        // ---- the header ------------------------------------------------------
        Item {
            width: column.width
            height: Theme.notifGroupIconSize + Theme.sp1

            HoverHandler {
                id: headerHover
                cursorShape: root.foldable ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                enabled: root.foldable
                onTapped: root.store.toggleExpanded(root.group.key)
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2

                // The application's icon, small and without a box around it —
                // it is labelling the group, not being a notification of its
                // own. Falls back to the first letters of the name, exactly as
                // a row's chip does.
                IconChip {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.notifGroupIconSize
                    chrome: false
                    iconName: root.group ? root.group.appIcon : ""
                    label: root.group ? root.group.appName : ""
                    tint: Theme.inkSoft
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.group ? root.group.appName : ""
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Medium
                    color: Theme.inkSoft
                    textFormat: Text.PlainText
                }

                // The count, but only when there is more than one — a badge
                // reading "1" is noise.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.foldable
                    width: Math.max(countLabel.implicitWidth + Theme.sp2, Theme.sp4)
                    height: Theme.sp4
                    radius: height / 2
                    color: Theme.hoverWash

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: root.group ? root.group.count.toString() : ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsMonoSm
                        color: Theme.inkSoft
                        textFormat: Text.PlainText
                    }
                }
            }

            // The right-hand end: normally the fold arrow, and a "clear this
            // application" cross while the pointer is over the header.
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // A chevron that turns over when the group opens. One
                    // character rather than an icon file, and it rotates rather
                    // than being swapped, so the movement reads as the same
                    // object changing state.
                    text: "⌄"
                    // Shown whenever the group CAN fold, not only on hover: it
                    // is the thing that tells you the group can fold at all.
                    // (It also means the row does not reflow when the pointer
                    // moves onto the cross beside it.)
                    visible: root.foldable
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsCaption
                    color: headerHover.hovered ? Theme.ink : Theme.inkMute
                    textFormat: Text.PlainText

                    rotation: root.expanded ? 180 : 0
                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.durFast
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeOut
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    visible: headerHover.hovered || clearHover.hovered
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsSmall
                    color: clearHover.hovered ? Theme.ink : Theme.inkMute
                    textFormat: Text.PlainText

                    HoverHandler {
                        id: clearHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: root.store.clearGroup(root.group.key)
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Clear everything from this app")
                    Accessible.onPressAction: root.store.clearGroup(root.group.key)
                }
            }

            Accessible.role: Accessible.Button
            Accessible.name: root.group ? root.group.appName : ""
            Accessible.description: root.foldable
                ? (root.expanded ? qsTr("Showing all. Press to fold them together.")
                                 : qsTr("%1 notifications. Press to show them all.").arg(root.group.count))
                : ""
            Accessible.onPressAction: {
                if (root.foldable)
                    root.store.toggleExpanded(root.group.key);
            }
        }

        // ---- the notifications themselves -------------------------------------
        Repeater {
            model: root.visibleItems

            delegate: NotificationRow {
                required property var modelData

                width: column.width
                notification: modelData
                store: root.store
                now: root.now
            }
        }

        // ---- the slab peeking out from behind ----------------------------------
        // Only when the group is folded and there IS something behind. It is
        // deliberately not interactive: it is a picture of depth, and the way to
        // reach what is under it is the header above.
        Item {
            width: column.width
            height: Theme.sp1
            visible: root.foldable && !root.expanded

            // Behind everything else in the column, so the opaque row above
            // covers all of it except the sliver that sticks out below.
            z: -1

            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: -Theme.sp4
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Theme.sp5
                height: Theme.sp5
                radius: Theme.radiusLg
                color: Theme.surfaceAlt
            }
        }
    }
}
