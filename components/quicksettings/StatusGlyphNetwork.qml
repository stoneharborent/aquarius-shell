// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// StatusGlyphNetwork — the Wi-Fi glyph in the top bar
// =============================================================================
// A read-only mirror of the same `Networking` singleton the Quick Settings
// Wi-Fi tile reads. It holds no state of its own, which is the only way to be
// sure the bar and the panel can never disagree.
//
// ⚠️ This file is loaded, never imported — because if it were imported into
// StatusCluster.qml, a Quickshell without `Quickshell.Networking` would cost the
// bar its tray and its clock as well as this glyph. The module IS present on the
// build AquariusOS ships (checked 2026-09-02; the header of QsTileSlot.qml has
// the details and the correction), but the version floor is not ours to hold.
//
// The two names used here — the `Networking` singleton and `DeviceType.Wifi` —
// are spelled the same on Quickshell 0.2.1 and 0.3.x. The device's `state` enum
// is NOT, which is why this file does not read it and TileWifi.qml has to look
// its namespace up at run time.
//
// WHY THERE IS NO SIGNAL-STRENGTH LADDER
//   `WifiNetwork.signalStrength` is a real 0..1 and drawing three or four
//   strength states off it is a small job. It is not done here on purpose: the
//   design's bar glyph is one Wi-Fi mark, and inventing four undrawn variants
//   for the bar while the design shows one is exactly the drift that makes a
//   shell stop looking designed. If strength bars are wanted, they get drawn in
//   the design system first.
// =============================================================================
import QtQuick

import Quickshell.Networking

import "../../theme"

QsGlyph {
    id: root

    readonly property var wifiDevice: {
        const all = Networking.devices.values;
        for (let i = 0; i < all.length; ++i) {
            if (all[i].type === DeviceType.Wifi)
                return all[i];
        }
        return null;
    }

    readonly property bool connected:
        root.wifiDevice !== null && root.wifiDevice.connected

    // WHEN THE MACHINE HAS NO WI-FI AT ALL, SAY NOTHING
    //   A desktop on an Ethernet cable has no Wi-Fi radio to report on. Drawing
    //   a permanently crossed-out Wi-Fi mark there is not a status, it is a
    //   complaint about hardware the machine was never supposed to have — and
    //   the user cannot act on it. This is the same rule the battery glyph
    //   already follows: no battery, no battery mark (StatusGlyphBattery.qml).
    //
    //   Note the distinction. Wi-Fi hardware that is present but off or
    //   disconnected DOES still show `wifi-off`, because that is a real state
    //   with a real fix. Only the absence of the radio hides the glyph.
    //
    //   Written on 2026-09-01 because the RTX 4090 bench machine appeared to
    //   have no Wi-Fi adapter and the bar wore a crossed-out Wi-Fi mark all day.
    //
    //   ⚠️ THAT MACHINE DOES HAVE ONE. Probed on 2026-09-02 against the host's
    //   system bus, NetworkManager reports `wlp7s0`, DeviceType.Wifi,
    //   wifiHardwareEnabled true, disconnected. `Networking.devices` is simply
    //   EMPTY FOR THE FIRST MOMENT of the shell's life and fills in
    //   asynchronously, so the first evaluation of any of this says "no radio"
    //   and a later one says otherwise. The rule below is still right — a
    //   machine with no radio should say nothing — but on this desk it should
    //   now draw `wifi-off`, not nothing.
    //
    //   Everything here is a BINDING for that reason. Anything that reads
    //   Networking.devices once, at Component.onCompleted, will conclude forever
    //   that the machine has no wireless.
    //
    //   BarItem lays its contents out in a `Row`, and a Row skips invisible
    //   children outright — no gap, no stray spacing. So `visible` is the whole
    //   mechanism here; nothing else needs collapsing.
    readonly property bool haveWifi: root.wifiDevice !== null

    visible: root.haveWifi

    glyph: root.connected ? "wifi" : "wifi-off"
    size: Theme.barGlyphSize

    // The bar's ink when connected, the quiet ink when not. Same idea as the
    // clock's date being quieter than its time: the state you are usually in
    // should not shout.
    color: root.connected ? Theme.ink : Theme.inkMute

    Accessible.role: Accessible.StaticText
    Accessible.name: root.connected ? qsTr("Wi-Fi connected") : qsTr("Wi-Fi off")
    Accessible.ignored: !root.haveWifi
}
