// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// ProgressBar — the filling bar inside a notification that reports a job
// =============================================================================
// When an application says how far along it is — the `value` hint, an integer
// from 0 to 100 — this is what the shell draws under its text:
//
//     Converting A001_C003.MP4 · 42% · about 2 min left
//     ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░
//
// WHY IT EXISTS
//   Royce, on the bench on 2026-09-04: converting a camera clip with "Make
//   Editor-Ready" said it had started and then went quiet for several minutes.
//   The tool now reports itself (os-image, ingest/aq_ingest/progress.py) and
//   this is the half of the answer that lives in the shell.
//
//   It is NOT specific to that tool. Anything on the machine that sends the
//   standard hint gets a bar here — a download, a backup, an update.
//
// TWO THINGS IT DELIBERATELY DOES NOT DO
//   * It does not appear when there is no `value` hint, which is almost every
//     notification. A bar sitting at zero under a message that is not about a
//     job is worse than no bar.
//   * It does not have a number on it. The percentage is already in the body
//     text — that is how GNOME's notification daemon, which has no bar at all,
//     shows the same information — and printing it twice looks like a mistake.
//
// The colours are the design system's, through Theme: the track is the same
// wash the Quick Settings sliders use, and the fill is the accent. Both are
// defined in Ice and Midnight, so this reads correctly in either without
// knowing which one is in force.
// =============================================================================
import QtQuick

import "../../theme"

Item {
    id: root

    // 0 to 100. Anything outside that has already been clamped by progress.js
    // before it reaches here; clamping again is one line and means this
    // component is safe to use from anywhere.
    property int percent: 0

    // Critical notifications are outlined in the danger colour rather than the
    // accent, and a bar inside one should agree with its own outline.
    property color fill: Theme.accent

    implicitHeight: Theme.notifBarHeight

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Theme.trackIdle

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: parent.radius
            color: root.fill

            // The bar is redrawn about once a second, because that is how often
            // the sending application is allowed to redraw its own notification.
            // Without this the bar would JUMP a second's worth of work at a
            // time, which reads as stuttering rather than as progress. The
            // animation spends that second walking there instead.
            width: track.width * Math.max(0, Math.min(100, root.percent)) / 100

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durMed
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }
    }

    // A screen reader gets the number, since the bar itself is a picture of it.
    Accessible.role: Accessible.ProgressBar
    Accessible.name: qsTr("%1 percent done").arg(root.percent)
}
