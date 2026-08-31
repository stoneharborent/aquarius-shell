// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// BatteryLine — "Battery 82% · about 6 hr left", along the bottom of the panel
// =============================================================================
// Verified against https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.UPower/:
//
//   UPower (singleton)  displayDevice : UPowerDevice   (never null)
//                       devices : ObjectModel<UPowerDevice>
//                       onBattery : bool
//   UPowerDevice        percentage : real, state : UPowerDeviceState,
//                       timeToEmpty / timeToFull : real (SECONDS),
//                       isLaptopBattery : bool, ready : bool, isPresent : bool
//   UPowerDeviceState   Charging | Discharging | FullyCharged | Empty |
//                       PendingCharge | PendingDischarge | Unknown
//
// Present in Quickshell v0.2.1 as well as v0.3.1.
//
// WHY displayDevice AND NOT A DEVICE OUT OF THE LIST
//   `displayDevice` is UPower's own aggregate — the single number a desktop is
//   meant to show, already combining multiple batteries on machines that have
//   them. Walking `devices` and picking one would mean re-implementing that
//   aggregation and getting it wrong on a two-battery ThinkPad.
//
//   It is documented as never null but possibly not yet initialised, which is
//   what `ready` is for. It also does NOT appear in `devices`, so there is no
//   risk of counting it twice.
//
// WHY THE WHOLE LINE HIDES ON A DESKTOP
//   A tower has no battery. Printing "Battery 0%" would be worse than useless.
//   `isLaptopBattery` is documented as equivalent to `type == Battery &&
//   powerSupply == true`, which is UPower's own answer to "is this a real
//   battery worth summarising", so it is the test.
//
//   When it hides, the panel's footer simply gets shorter. There is nothing
//   beside it to be misaligned by its absence — see the note in
//   QuickSettingsPanel.qml about the design's "All settings" link, which this
//   shell does not have yet and does not fake.
//
// THE TIME FORMATTING IS OURS
//   The Plasma version had KCoreAddons.Format.formatDuration, which produced
//   "6 hr 12 min" in the user's own language and unit conventions. Quickshell
//   has no equivalent and Qt's QML surface has no duration formatter either, so
//   the rounding below is hand-written. It is deliberately coarse — "about 6 hr
//   left", not "6 hr 12 min 4 s" — because a minute-accurate battery estimate is
//   a fiction anyway, and a number that visibly ticks invites people to watch it.
//
//   ⚠️ The strings are marked for translation but the ASSEMBLY is English-shaped
//   ("6 hr", "45 min"). A proper localisation pass is P3 work and is on the list
//   in docs/quick-settings.md.
// =============================================================================
import QtQuick
import QtQuick.Layouts

import Quickshell.Services.UPower

import "../../theme"

RowLayout {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool haveBattery:
        root.device !== null && root.device.ready && root.device.isLaptopBattery

    readonly property bool charging:
        root.haveBattery && root.device.state === UPowerDeviceState.Charging

    readonly property real level:
        root.haveBattery ? Math.max(0, Math.min(1, root.device.percentage / 100)) : 0

    visible: root.haveBattery
    spacing: Theme.qsFooterGap

    Accessible.role: Accessible.StaticText
    Accessible.name: label.text

    QsBatteryGlyph {
        Layout.alignment: Qt.AlignVCenter
        level: root.level
        charging: root.charging
    }

    Text {
        id: label

        Layout.fillWidth: true
        elide: Text.ElideRight
        color: Theme.ink
        font.family: Theme.fontBody
        font.pixelSize: Theme.fsCaption     // design says 11.5px
        textFormat: Text.PlainText

        text: {
            if (!root.haveBattery)
                return "";

            const percentPart = qsTr("Battery %1%")
                .arg(Math.round(root.device.percentage));

            if (root.device.state === UPowerDeviceState.FullyCharged)
                return qsTr("%1 · Fully charged").arg(percentPart);

            // UPower reports 0 when it has not worked the estimate out yet,
            // which happens for a minute or so after plugging or unplugging.
            // Saying nothing beats saying "0 min".
            if (root.charging) {
                if (root.device.timeToFull > 0) {
                    return qsTr("%1 · %2 until full")
                        .arg(percentPart)
                        .arg(root.roughDuration(root.device.timeToFull));
                }
                return qsTr("%1 · Charging").arg(percentPart);
            }

            if (root.device.timeToEmpty > 0) {
                return qsTr("%1 · about %2 left")
                    .arg(percentPart)
                    .arg(root.roughDuration(root.device.timeToEmpty));
            }

            return percentPart;
        }
    }

    // Seconds -> "6 hr" / "1 hr 30 min" / "45 min". See the note at the top
    // about why this is hand-written and deliberately coarse.
    function roughDuration(seconds: real): string {
        const totalMinutes = Math.round(seconds / 60);
        if (totalMinutes < 60)
            return qsTr("%1 min").arg(totalMinutes);

        const hours = Math.floor(totalMinutes / 60);
        // Round the leftover to the nearest quarter hour. A battery estimate is
        // not accurate to the minute and should not pretend to be.
        const minutes = Math.round((totalMinutes % 60) / 15) * 15;

        if (minutes === 0)
            return qsTr("%1 hr").arg(hours);
        if (minutes === 60)
            return qsTr("%1 hr").arg(hours + 1);
        return qsTr("%1 hr %2 min").arg(hours).arg(minutes);
    }
}
