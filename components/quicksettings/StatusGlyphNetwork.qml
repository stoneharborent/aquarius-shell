// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// StatusGlyphNetwork — the Wi-Fi glyph in the top bar
// =============================================================================
// A read-only mirror of the same `Networking` singleton the Quick Settings
// Wi-Fi tile reads. It holds no state of its own, which is the only way to be
// sure the bar and the panel can never disagree.
//
// ⚠️ This file is loaded, never imported. `Quickshell.Networking` arrived in
// Quickshell v0.3.0 and Fedora's package was a 0.2.1 snapshot when this was
// written, so on some machines this file simply will not load — and if it were
// imported into StatusCluster.qml, the whole bar would go with it. See the
// header of QsTileSlot.qml.
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

    glyph: root.connected ? "wifi" : "wifi-off"
    size: Theme.barGlyphSize

    // The bar's ink when connected, the quiet ink when not. Same idea as the
    // clock's date being quieter than its time: the state you are usually in
    // should not shout.
    color: root.connected ? Theme.ink : Theme.inkMute

    Accessible.role: Accessible.StaticText
    Accessible.name: root.connected ? qsTr("Wi-Fi connected") : qsTr("Wi-Fi off")
}
