// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// TileWifi — the Wi-Fi switch, and the name of the network you are on
// =============================================================================
// ⚠️ THIS FILE NEEDS QUICKSHELL 0.3.0 OR NEWER, AND IT IS THE ONLY ONE THAT DOES
//
//   `Quickshell.Networking` did not exist before v0.3.0. The changelog's v0.3.0
//   entry says "Added network management support", and the v0.2.1 type index
//   lists no such module. Fedora's `quickshell` package was a 0.2.1 snapshot
//   when docs/adr/0001-framework.md was written; Arch ships 0.3.1.
//
//   On a build without it, this file fails to load and QsTileSlot puts a dimmed
//   "Wi-Fi — Unavailable" placeholder in its square. That is why this tile is
//   loaded rather than imported, and it is the whole reason QsTileSlot exists.
//   Read the long note at the top of that file before changing this arrangement.
//
// WHAT WAS ACTUALLY CHECKED, AND WHAT THE ROADMAP SAID
//   The roadmap's P2 entry says "NetworkManager over D-Bus", which read as "we
//   will be writing a D-Bus client by hand". We do not have to. Quickshell 0.3.0
//   ships a NetworkManager-backed service with a QML API, so the D-Bus is
//   somebody else's problem and the standardised-protocols law is satisfied the
//   same way it is for the tray: through a published interface, spoken by a
//   service that already exists.
//
//   Verified against https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/:
//     Networking (singleton)  wifiEnabled (writable), wifiHardwareEnabled,
//                             devices : ObjectModel<NetworkDevice>, connectivity
//     NetworkDevice           type : DeviceType, networks : ObjectModel<Network>,
//                             connected, state
//     Network                 name, connected, state, known, connect(), disconnect()
//     WifiNetwork : Network   signalStrength (0..1), security, connectWithPsk()
//
//   `Networking` says of itself: "An interface to a network backend (currently
//   only NetworkManager)". So it IS NetworkManager, reached through a QML
//   surface rather than a hand-rolled D-Bus client.
//
// WHAT THIS TILE DELIBERATELY DOES NOT DO
//   Pick a network. The design's tile is a switch with a name under it, and that
//   is what this is. Choosing between networks, and typing a password for one,
//   is a list and a text field — a Settings surface, which is Phase P3
//   (`WifiNetwork.connectWithPsk()` is the call it will make). A half-built
//   picker in a 165px-wide tile would be worse than none.
// =============================================================================
import QtQuick

import Quickshell.Networking

QsTile {
    id: root

    title: qsTr("Wi-Fi")

    // ---- finding the wireless device ----------------------------------------
    // `Networking.devices` is an ObjectModel, and the docs are explicit that a
    // binding into `model[i]` will NOT update reactively while `model.values[i]`
    // will. So every walk over one of these models in this repo goes through
    // `.values`. Getting that wrong produces a tile that is correct when the
    // panel opens and then quietly stops being correct, which is the worst kind
    // of wrong.
    readonly property var wifiDevice: {
        const all = Networking.devices.values;
        for (let i = 0; i < all.length; ++i) {
            if (all[i].type === DeviceType.Wifi)
                return all[i];
        }
        return null;
    }

    // The network this device is actually on, if any.
    readonly property var activeNetwork: {
        if (!root.wifiDevice)
            return null;
        const nets = root.wifiDevice.networks.values;
        for (let i = 0; i < nets.length; ++i) {
            if (nets[i].connected)
                return nets[i];
        }
        return null;
    }

    // No wireless card at all, or the hardware kill switch (a laptop's aeroplane
    // slider, or rfkill) is holding it down. Either way there is nothing this
    // tile can do, so it dims rather than offering a switch that cannot move.
    available: root.wifiDevice !== null && Networking.wifiHardwareEnabled

    active: Networking.wifiEnabled

    glyph: root.active ? "wifi" : "wifi-off"

    subtitle: {
        if (root.wifiDevice === null)
            return qsTr("No adapter");
        if (!Networking.wifiHardwareEnabled)
            return qsTr("Blocked by hardware");
        if (!Networking.wifiEnabled)
            return qsTr("Off");
        if (root.activeNetwork !== null)
            return root.activeNetwork.name;
        if (root.wifiDevice.state === ConnectionState.Connecting)
            return qsTr("Connecting…");
        return qsTr("Not connected");
    }

    // One property, writable, that maps onto NetworkManager's own software
    // rfkill switch for every wireless device at once. That is the same thing
    // the Plasma tile did through `Handler.enableWireless()`.
    onActivated: Networking.wifiEnabled = !Networking.wifiEnabled
}
