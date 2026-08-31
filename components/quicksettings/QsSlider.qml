// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// QsSlider — the look of one labelled slider
// =============================================================================
//   Sound                                        64%
//   ●━━━━━━━━━━━━━━━━━━━━━○───────────────────────
//
// The word on the left, the percentage on the right in the mono face, the track
// underneath. Design: `.slider` in the V2 artboard — 6px track, 16px round
// handle, filled portion in the accent.
//
// Like QsTile, this file knows nothing about what it is controlling. Sound and
// brightness supply the meaning.
//
// WHY THE PERCENTAGE IS IN THE MONO FACE
//   Because it changes while you drag it. In a proportional face the number
//   jitters left and right as digits change width, which reads as the label
//   twitching. The design specifies var(--font-mono) for exactly this and it is
//   worth keeping.
//
// THE ONE SUBTLE LINE IN THIS FILE
//   `value: !dragging ? root.value : value` on the drag state. Without it, the
//   binding fights the finger: the caller sets the real volume, the real volume
//   comes back in as `root.value`, and the handle jumps out from under the
//   pointer. While the handle is held, the slider owns its own position; the
//   binding takes back over the moment it is let go. Every slider that has ever
//   felt "sticky" is missing this line.
//
// WHY THIS IS BUILT FROM A MouseArea AND NOT QtQuick.Controls' Slider
//   The Plasma version used QQC2.Slider because Plasma already had a style
//   loaded. This shell does not ship a Controls style, and QtQuick.Controls'
//   default style would drag its own (non-Aquarius) look into the panel, which
//   would then have to be overridden piece by piece with custom `background:`
//   and `handle:` delegates anyway. At that point the Control is providing
//   keyboard handling and a stepSize, and costing a whole module. A track, a
//   handle and a MouseArea is less code and no dependency.
// =============================================================================
import QtQuick
import QtQuick.Layouts

import "../../theme"

ColumnLayout {
    id: root

    // The word on the left.
    property string label: ""

    // 0.0 to 1.0. The caller keeps this in step with the real world.
    property real value: 0

    // False when there is nothing to control — no sound card, no backlight. The
    // whole row hides itself and the panel simply gets shorter. Unlike a tile,
    // a missing slider misaligns nothing, so there is no reason to draw a
    // placeholder for it.
    property bool available: true

    // Emitted continuously while dragging, and once per click on the track.
    signal moved(real newValue)

    visible: root.available
    spacing: Theme.qsSliderLabelGap

    Accessible.role: Accessible.Slider
    Accessible.name: root.label
    Accessible.description: Math.round(root.value * 100) + "%"

    // ---- the label row -------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: root.label
            color: Theme.ink
            font.family: Theme.fontBody
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Medium        // the design's 500
            textFormat: Text.PlainText
        }

        Item { Layout.fillWidth: true }

        Text {
            text: Math.round(root.value * 100) + "%"
            color: Theme.ink

            // `font.families` rather than `font.family`: the OS installs
            // JetBrains Mono, but the bench machine running the nested harness
            // may not have it. fontconfig always resolves "monospace" to
            // something, so the number can never fall back to nothing.
            font.families: [Theme.fontMono, Theme.fontMonoFallback]
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Medium
            textFormat: Text.PlainText
        }
    }

    // ---- the track -----------------------------------------------------------
    Item {
        id: track

        Layout.fillWidth: true
        // Tall enough for the handle, which overhangs the 6px track.
        implicitHeight: Theme.qsHandleSize

        readonly property real usableWidth: track.width - Theme.qsHandleSize
        readonly property real shownValue: drag.dragging
            ? drag.draggedValue
            : Math.max(0, Math.min(1, root.value))

        // The unfilled groove.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.qsTrackHeight
            radius: height / 2
            color: Theme.trackIdle

            // The filled portion, left of the handle.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Theme.qsHandleSize / 2 + track.shownValue * track.usableWidth
                radius: parent.radius
                color: Theme.accent
            }
        }

        // The handle's shadow, drawn as a slightly larger, very faint circle
        // one pixel lower rather than as a real blur. A blur would mean pulling
        // in QtQuick.Effects and paying for an offscreen render pass on a dot
        // this size; at 16px the cheap version reads the same.
        Rectangle {
            x: track.shownValue * track.usableWidth - 1
            y: (track.height - height) / 2 + 1
            width: Theme.qsHandleSize + 2
            height: width
            radius: width / 2
            color: Theme.handleShadow
        }

        // The handle.
        Rectangle {
            x: track.shownValue * track.usableWidth
            y: (track.height - height) / 2
            width: Theme.qsHandleSize
            height: width
            radius: width / 2
            color: Theme.handleFill

            scale: drag.dragging ? 1.1 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }

        MouseArea {
            id: drag

            anchors.fill: parent
            hoverEnabled: false
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor

            property bool dragging: false
            property real draggedValue: 0

            // Where the handle's LEFT EDGE would be if its CENTRE were under the
            // pointer, expressed back as 0..1. Without the half-handle offset,
            // clicking the far right of the track gives 1.0 only when the
            // pointer is past the end of it.
            function valueAt(mouseX: real): real {
                if (track.usableWidth <= 0)
                    return 0;
                const raw = (mouseX - Theme.qsHandleSize / 2) / track.usableWidth;
                return Math.max(0, Math.min(1, raw));
            }

            onPressed: function (event) {
                drag.dragging = true;
                drag.draggedValue = drag.valueAt(event.x);
                root.moved(drag.draggedValue);
            }

            onPositionChanged: function (event) {
                if (!drag.dragging)
                    return;
                drag.draggedValue = drag.valueAt(event.x);
                root.moved(drag.draggedValue);
            }

            onReleased: drag.dragging = false
            onCanceled: drag.dragging = false

            // One notch of the wheel is 5%, which is the step KDE's own volume
            // and brightness controls use. `angleDelta.y` is in eighths of a
            // degree and a normal notch is 120 of them.
            onWheel: function (event) {
                const notches = event.angleDelta.y / 120;
                const next = Math.max(0, Math.min(1, root.value + notches * 0.05));
                root.moved(next);
            }
        }
    }
}
