// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// ToastLayer — the window the arriving notifications stack up in
// =============================================================================
// A layer-shell surface pinned to the top-right corner, exactly as wide as the
// notifications panel and exactly as tall as the toasts inside it. It exists
// only while there is something to show; the rest of the time the window is not
// there at all, so nothing of the desktop is covered and nothing of the desktop
// is unclickable.
//
// That last part is why this is its own window rather than a corner of the
// panel's full-screen one: a window that covers the screen swallows every click
// on it. A toast may be clicked, so it needs a real window — but only a window
// the size of the toasts.
//
// SAME POSITIONING RULE AS THE PANEL
//   `exclusiveZone: 0` means "reserve nothing for me, but respect what the bar
//   reserved", so the window starts just below the bar and the 8px margin lands
//   the first toast exactly where the design puts the panel. The long version of
//   this is in NotificationPanelWindow.qml.
//
// https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/
// =============================================================================
pragma ComponentBehavior: Bound

import QtQuick

import Quickshell

import "../../theme"

PanelWindow {
    id: root

    property var store: null

    anchors {
        top: true
        right: true
    }

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    margins {
        top: Theme.sp2
        right: Theme.sp3
    }

    // Toasts never take keyboard focus. Something appearing on its own must not
    // be able to swallow the keystroke you were in the middle of typing.
    focusable: false

    color: "transparent"

    implicitWidth: Theme.notifPanelWidth
    // A layer-shell surface may not be zero-sized, so the floor is 1 rather than
    // 0. It is never seen: the window is hidden whenever the column is empty.
    implicitHeight: Math.max(1, column.implicitHeight)

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.sp2

        Repeater {
            model: root.store ? root.store.toasts : []

            delegate: Toast {
                required property var modelData

                width: column.width
                notification: modelData
                store: root.store
            }
        }
    }
}
