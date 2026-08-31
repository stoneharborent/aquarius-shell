// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// NotificationsPanel — what drops out of the clock
// =============================================================================
// Straight from the design: branding/design-system/AquariusOS Desktop Shell.html,
// the block with id="ovNotif" (also published on its own as "AquariusOS Shell
// Notifications.html", which just frames that same panel).
//
//     ┌─ 350px ──────────────────────────────────┐
//     │ Notifications                  Clear all │
//     │                                          │
//     │ Screenshots                              │
//     │ ▢ Screenshot saved                   now │
//     │   Added to Pictures. Click to open.      │
//     │ Software                                 │
//     │ ▢ You're up to date                  2 h │
//     │   Tonight's updates installed themselves │
//     │ ──────────────────────────────────────── │
//     │ 21:47                 [ Focus until      │
//     │ Saturday, August 30       morning ]      │
//     └──────────────────────────────────────────┘
//
// NO CALENDAR, ON PURPOSE.
//   Every other desktop's clock opens a calendar. This one opens notifications,
//   because that is what the design draws and a calendar would push the panel to
//   twice the width. That decision was taken in Wave 2 and it still stands; it
//   is not an omission and it does not need re-deciding.
//
// The app-name headers above are the one thing here that is NOT in the drawing —
// see NotificationGroup.qml for why grouping earned its place.
//
// This file draws; it does not know how notifications work. Everything comes
// from `store`, which is NotificationStore.qml.
// =============================================================================
pragma ComponentBehavior: Bound

import QtQuick

import Quickshell

import "../../theme"
import "../../services"

Item {
    id: root

    property var store: null

    // False while the panel's window is hidden. Only used to stop the clock
    // waking up once a minute for a panel nobody is looking at.
    property bool active: true

    implicitWidth: Theme.notifPanelWidth
    implicitHeight: stack.implicitHeight + Theme.sp4 * 2

    // ---- the panel surface --------------------------------------------------
    // Opaque, and staying that way. The V2 artboard's panel is frosted glass;
    // the glass came out of the shipping desktop on 2026-08-30 and this shell
    // follows, so that the two look like one product while both exist.
    //
    // The design also gives this a large soft drop shadow (`--shadow-pop`). It
    // is NOT drawn here — a shadow in QtQuick needs QtQuick.Effects, and adding
    // an untested effects pipeline to a component that has never been run once
    // is a poor trade. The heavier border stands in for it. Written up as a gap
    // in docs/notifications.md rather than quietly skipped.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surface
        border.width: Theme.hairline
        border.color: Theme.lineStrong
    }

    // Swallow clicks that land on the panel's own background, so they do not
    // fall through to the click-away catcher behind it and close the panel the
    // person is using.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
    }

    Column {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.sp4
        spacing: 0

        // =====================================================================
        // Header: the word, and the way out
        // =====================================================================
        Item {
            width: stack.width
            height: heading.implicitHeight

            Text {
                id: heading
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Notifications")
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsSmall
                font.weight: Font.DemiBold
                color: Theme.ink
                textFormat: Text.PlainText
            }

            // Only shown when there is something it could clear. A button that
            // does nothing is worse than no button.
            Text {
                id: clearAll
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Clear all")
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsMicro
                color: clearHover.hovered ? Theme.ink : Theme.inkMute
                textFormat: Text.PlainText
                visible: root.store !== null && root.store.count > 0

                HoverHandler {
                    id: clearHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.store.clearAll()
                }

                Accessible.role: Accessible.Button
                Accessible.name: clearAll.text
                Accessible.onPressAction: root.store.clearAll()
            }
        }

        Item {
            width: stack.width
            height: Theme.sp3
        }

        // =====================================================================
        // The Focus banner
        // =====================================================================
        // Only while Focus is on. It says the one thing that makes a Do Not
        // Disturb switch safe to leave on: how much you have not been told, and
        // when the machine will start telling you again.
        Item {
            width: stack.width
            height: FocusState.enabled ? banner.implicitHeight + Theme.sp3 : 0
            visible: FocusState.enabled
            clip: true

            Rectangle {
                id: banner
                width: parent.width
                implicitHeight: bannerText.implicitHeight + Theme.sp2 * 2
                radius: Theme.radiusMd
                color: Theme.accentWash

                Text {
                    id: bannerText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.sp3
                    anchors.rightMargin: Theme.sp3
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.focusSummary
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsMicro
                    color: Theme.ink
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                }
            }
        }

        // =====================================================================
        // The list
        // =====================================================================
        // A Flickable rather than a ListView on purpose. The model is a small
        // array of groups, each of which contains a variable number of rows; a
        // ListView recycling delegates of wildly different heights is where this
        // sort of code goes wrong, and there is nothing to gain from recycling
        // eight items.
        Flickable {
            id: list

            width: stack.width
            height: Math.min(groups.implicitHeight, Theme.notifMaxListHeight)
            visible: root.store !== null && root.store.count > 0

            contentHeight: groups.implicitHeight
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: groups
                width: list.width
                spacing: Theme.sp3

                Repeater {
                    model: root.store ? root.store.groups : []

                    delegate: NotificationGroup {
                        required property var modelData

                        width: groups.width
                        group: modelData
                        store: root.store
                        now: root.now
                    }
                }
            }
        }

        // =====================================================================
        // Nothing to show
        // =====================================================================
        // "All caught up" is good news and should read like it. There is no
        // second, sadder empty state here the way the Plasma widget had one:
        // that widget was a client of a daemon that might not be running, and
        // this shell IS the daemon. If it is drawing this panel, it is listening.
        Item {
            width: stack.width
            height: visible ? Theme.sp8 : 0
            visible: root.store === null || root.store.count === 0

            Text {
                anchors.centerIn: parent
                text: FocusState.enabled ? qsTr("Nothing came in. Focus is on.")
                                         : qsTr("You're all caught up.")
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsMicro
                color: Theme.inkMute
                textFormat: Text.PlainText
            }
        }

        // =====================================================================
        // Footer: the big clock, and Focus
        // =====================================================================
        Item {
            width: stack.width
            height: Theme.sp3
        }

        Rectangle {
            width: stack.width
            height: Theme.hairline
            color: Theme.line
        }

        Item {
            width: stack.width
            height: Theme.sp3
        }

        Item {
            width: stack.width
            height: Math.max(clockColumn.implicitHeight, focusPill.height)

            Column {
                id: clockColumn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: Qt.formatTime(clock.date, root.timeFormat)
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fsSubhead
                    font.weight: Font.DemiBold
                    color: Theme.ink
                    textFormat: Text.PlainText
                }

                Text {
                    text: Qt.locale().toString(clock.date, "dddd, MMMM d")
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsMicro
                    color: Theme.inkMute
                    textFormat: Text.PlainText
                }
            }

            // ---- the Focus pill --------------------------------------------
            // Pressing it holds every notification back until the next 06:00.
            // Pressing it again lets them through. The state lives in
            // services/FocusState.qml, which is the same switch Quick Settings
            // flips — this button and that toggle are two views of one thing.
            Rectangle {
                id: focusPill

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: focusLabel.implicitWidth + Theme.sp5
                height: focusLabel.implicitHeight + Theme.sp4
                radius: Theme.radiusLg

                color: FocusState.enabled
                    ? Theme.accentWash
                    : (focusHover.hovered ? Theme.pressWash : Theme.hoverWash)
                border.width: Theme.hairline
                border.color: Theme.line

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durFast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeOut
                    }
                }

                Text {
                    id: focusLabel
                    anchors.centerIn: parent
                    text: qsTr("Focus until morning")
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsCaption
                    font.weight: Font.Medium
                    color: FocusState.enabled ? Theme.ink : Theme.inkMute
                    textFormat: Text.PlainText
                }

                HoverHandler {
                    id: focusHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: FocusState.toggleUntilMorning()
                }

                Accessible.role: Accessible.Button
                Accessible.name: focusLabel.text
                Accessible.checkable: true
                Accessible.checked: FocusState.enabled
                Accessible.description: FocusState.enabled
                    ? root.focusSummary
                    : qsTr("Hold notifications back until 6 in the morning")
                Accessible.onPressAction: FocusState.toggleUntilMorning()
            }
        }
    }

    // =========================================================================
    // Time
    // =========================================================================

    // Ticks once a minute. Everything time-shaped in the panel — the big clock,
    // every row's age — reads off this one object, so they can never disagree
    // about what minute it is.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        // No point waking up for a panel nobody is looking at.
        enabled: root.active
    }

    readonly property double now: clock.date.getTime()

    // What the Focus banner and the pill's screen-reader description both say.
    readonly property string focusSummary: {
        const held = root.store ? root.store.heldBack : 0;
        const ends = FocusState.endsAt;

        if (ends === null) {
            return held > 0
                ? qsTr("Focus is on. %1 held back.").arg(held)
                : qsTr("Focus is on.");
        }

        const at = Qt.formatTime(ends, root.timeFormat);
        return held > 0
            ? qsTr("Focus is on until %1. %2 held back.").arg(at).arg(held)
            : qsTr("Focus is on until %1.").arg(at);
    }

    // -------------------------------------------------------------------------
    // 12-hour or 24-hour, exactly as the bar clock decides it
    // -------------------------------------------------------------------------
    // The same locale-derived format BarClock.qml works out, repeated here
    // rather than shared through a third file: it is eight lines, and the two
    // clocks disagreeing would be the kind of bug nobody notices for months. If
    // this is ever needed a third time, move it into services/.
    readonly property string timeFormat: {
        const shortFormat = Qt.locale().timeFormat(Locale.ShortFormat);
        const match = /(hh?)(.+?)(mm)/i.exec(shortFormat);
        if (!match)
            return shortFormat;
        let result = match[1].toLowerCase() + match[2] + match[3];
        if (shortFormat.toLowerCase().indexOf("ap") !== -1)
            result += " AP";
        return result;
    }
}
