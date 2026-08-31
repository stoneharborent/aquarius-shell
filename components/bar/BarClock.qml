// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// BarClock — the date and time at the right-hand end of the bar
// =============================================================================
// The design (the V2 shell artboard's bar item with onclick="toggle('notif')"):
//
//     Sat Aug 30 21:47
//     └─ quieter ─┘ └ normal
//
// Date first, then the time, on one line, with the date drawn in the quiet ink
// colour. That contrast is the whole idea: you glance at the time constantly and
// the date rarely, so the time is what your eye should land on.
//
// THIS IS A PORT OF THE DESIGN, NOT OF THE OLD CODE
//   AquariusOS already has a clock like this — the Plasma widget at
//   os-image/system_files/usr/share/plasma/plasmoids/com.aquariusos.clock. Its
//   two rules are carried over here deliberately:
//
//   1. THE DATE READS "ddd MMM d" — short day, short month, day with no leading
//      zero. "Sat Aug 30".
//
//   2. 12-HOUR OR 24-HOUR FOLLOWS THE USER'S COUNTRY. The design mock shows
//      21:47, but we do not force 24-hour on anybody. The person chose a region
//      during setup and that choice decides. A German install shows 21:47, an
//      American one shows 9:47 PM, and both are correct.
//      `Qt.locale().timeFormat(Locale.ShortFormat)` is exactly that promise.
//
//   None of the widget's Plasma-specific machinery came across — no Kirigami,
//   no PlasmaComponents, no colour scheme. Colour comes from Theme, and the time
//   itself comes from Quickshell's SystemClock, which wakes up once a minute
//   rather than once a second when it knows you are not showing seconds.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell/SystemClock/)
//
// P2 will hang the notifications panel off a click here. For now the click is
// wired to a signal that goes nowhere, so the shape of the thing is right.
// =============================================================================
import QtQuick

import Quickshell

import "../../theme"

BarItem {
    id: root

    // Emitted on click. P2 connects this to the notifications + calendar panel.
    signal activated()

    interactive: true
    onClicked: root.activated()

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Clock and notifications")
    Accessible.description: dateLabel.text + " " + timeLabel.text

    // Ticks once a minute. Seconds would be 60x the wake-ups for information
    // nobody reads off a bar.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // The locale's own short time, with any seconds taken back out. Some
    // countries' "short" format still carries seconds, and a bar clock wants
    // neither that nor the "long" format. KDE's own digital clock does the same
    // trimming, for the same reason.
    readonly property string timeFormat: {
        const shortFormat = Qt.locale().timeFormat(Locale.ShortFormat);
        // Pull out "hours", whatever separator sits between, and "minutes";
        // drop everything after.
        const match = /(hh?)(.+?)(mm)/i.exec(shortFormat);
        if (!match) {
            // No locale we know of fails this. If one did, showing the
            // country's own string unchanged beats showing nothing.
            return shortFormat;
        }
        // Lower-case "h" on purpose: Qt reads a capital H as "always 24-hour"
        // and then ignores the AM/PM marker entirely.
        let result = match[1].toLowerCase() + match[2] + match[3];
        // Keep the country's AM/PM if it has one. No "ap" in the locale's
        // pattern means the country writes 24-hour time, and we leave it be.
        if (shortFormat.toLowerCase().indexOf("ap") !== -1)
            result += " AP";
        return result;
    }

    Text {
        id: dateLabel
        text: Qt.locale().toString(clock.date, "ddd MMM d")
        font.family: Theme.fontBody
        font.pixelSize: Theme.fsCaption
        font.weight: Font.Normal
        color: Theme.inkMute          // the quiet one
        textFormat: Text.PlainText
    }

    Text {
        id: timeLabel
        text: Qt.formatTime(clock.date, root.timeFormat)
        font.family: Theme.fontBody
        font.pixelSize: Theme.fsCaption
        font.weight: Font.Medium
        color: Theme.ink              // the one your eye lands on
        textFormat: Text.PlainText
    }
}
