// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// NotificationPanelWindow — the window the notifications panel lives in
// =============================================================================
// A layer-shell surface covering the whole screen, transparent, and only there
// while the panel is open. It does two jobs:
//
//   1. It puts the 350px panel in the top-right corner, where the design draws
//      it (`right:12px; top:38px`).
//   2. It catches the click that lands ANYWHERE ELSE, and closes the panel. That
//      is the whole reason it is full-screen rather than panel-sized — a popup
//      you cannot dismiss by looking away is a popup that follows you around.
//
// THE ARCHITECTURAL LAW THIS FILE OBEYS
//   Same as the bar: `PanelWindow` is a request made through wlr-layer-shell, a
//   published protocol, and nothing here reaches into any particular window
//   manager's internals. See README.md, "The one architectural law".
//   https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/
//
// WHY `exclusiveZone: 0` AND NOT `ExclusionMode.Ignore`
//   These sound similar and are opposites.
//
//     Ignore  -> "I do not care about anybody else's reserved space." The window
//                would start at the very top of the screen, UNDERNEATH the bar.
//     Normal, -> "Reserve nothing for me, but respect what others reserved."
//     zone 0     The window starts just below the bar, which is exactly where
//                the design's 38px measurement lands.
//
//   So the design's "38px from the top" is written here as 8px from the top of a
//   window that already begins below a 30px bar. There is no 38 anywhere in the
//   code, and there should not be — if the bar's height changes, the gap should
//   stay 8.
//
// WHY THE PANEL IS ON EVERY SCREEN AT ONCE
//   Working out which monitor a person is looking at means asking the compositor
//   which one has the pointer or the focused window, and every portable answer
//   to that is a Phase P3 service this shell does not have yet. Until then, one
//   panel per screen, all showing the same list, all closing together. It is
//   slightly odd on a two-monitor desk and it is not wrong. Recorded in
//   docs/notifications.md.
// =============================================================================
import QtQuick

import Quickshell

import "../../theme"

PanelWindow {
    id: root

    property var store: null

    signal closeRequested()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Reserve nothing; respect what the bar reserved. See the long note above.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    // Keyboard focus is asked for so that Escape closes the panel and so the
    // inline reply box can be typed into. This is the least-proven line in the
    // component: what a compositor does with a keyboard-focusable layer surface
    // varies, and it has never been run. See docs/notifications.md.
    focusable: true

    // Nothing is painted by the window itself — only the panel inside it. The
    // colour is set before the window is ever shown, which is what Quickshell
    // requires for a surface that needs to be transparent.
    color: "transparent"

    // The catcher below covers the screen, so this must not exist while the
    // panel is closed or the desktop would be unclickable.
    visible: false

    Item {
        id: catcher

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: function (event) {
            root.closeRequested();
            event.accepted = true;
        }

        // Click away to close. The panel itself swallows its own clicks, so this
        // only ever fires for a click that genuinely landed outside it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.closeRequested()
        }

        NotificationsPanel {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.sp2    // the design's 38px, minus the bar
            anchors.rightMargin: Theme.sp3  // the design's right:12px

            store: root.store
            active: root.visible

            // Slides down and fades in from just under the bar. The panel is
            // "dropping out of the clock", so the movement should come from
            // that direction.
            //
            // Only the ARRIVAL is animated. The window itself vanishes the
            // instant it is hidden, so there is nothing left on screen for an
            // exit animation to play on. Doing that properly means keeping the
            // window alive for the length of the animation, which is a state
            // machine's worth of code for 120ms of polish — deferred, and
            // written down in docs/notifications.md rather than left as a
            // mystery.
            opacity: root.visible ? 1 : 0
            transform: Translate {
                y: root.visible ? 0 : -Theme.sp2
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.durMed
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeOut
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }
    }
}
