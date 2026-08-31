// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// TileBluetooth — the Bluetooth switch, and what is connected to it
// =============================================================================
// Verified against https://quickshell.org/docs/v0.3.1/types/Quickshell.Bluetooth/:
//
//   Bluetooth (singleton)  adapters : ObjectModel<BluetoothAdapter>
//                          defaultAdapter : BluetoothAdapter
//                          devices : ObjectModel<BluetoothDevice>
//   BluetoothAdapter       enabled (WRITABLE), state : BluetoothAdapterState,
//                          name, adapterId, devices, discovering
//   BluetoothDevice        connected, paired, name, battery, state
//   BluetoothAdapterState  Enabled | Enabling | Disabled | Disabling | Blocked
//
// The module is present in Quickshell v0.2.1 as well as v0.3.1, so unlike the
// Wi-Fi tile this one does not need a new Quickshell to work.
//
// THE ONE THING THAT IS SIMPLER HERE THAN IT WAS IN PLASMA
//   The KDE version had to do two operations to switch Bluetooth on: clear the
//   rfkill soft block (`bluetoothBlocked`) AND power each adapter
//   (`adapter.powered`). Doing only half of it looked like it worked and did
//   nothing. Quickshell exposes one writable `enabled` per adapter and reports
//   the rfkill case separately as `state === Blocked`, so the write is one line
//   — and the blocked case gets SAID rather than silently swallowed, which is
//   better behaviour than the widget it replaces.
//
//   `enabled` is only documented as "True if the adapter is currently enabled".
//   Whether writing it also lifts a soft rfkill block is NOT stated. This is on
//   the unproven list in docs/quick-settings.md and needs the bench to settle:
//   turn Bluetooth off with `rfkill block bluetooth`, then press the tile.
// =============================================================================
import QtQuick

import Quickshell.Bluetooth

QsTile {
    id: root

    title: qsTr("Bluetooth")

    // Usually there is exactly one. A machine with none — most desktop towers —
    // gets a dimmed tile rather than a switch with nothing behind it.
    readonly property var adapter: Bluetooth.defaultAdapter

    available: root.adapter !== null

    active: root.adapter !== null && root.adapter.enabled

    glyph: root.active ? "bluetooth" : "bluetooth-off"

    // The devices actually in use right now. `Bluetooth.devices` is documented
    // as connected devices across all adapters, but it is filtered on
    // `connected` here anyway: a list that quietly starts including paired-but-
    // absent devices would put a subtitle on the tile that is not true, and
    // filtering costs nothing.
    readonly property var connectedNames: {
        const names = [];
        const all = Bluetooth.devices.values;
        for (let i = 0; i < all.length; ++i) {
            if (all[i].connected)
                names.push(all[i].name);
        }
        return names;
    }

    // The design shows real device names ("Pad · Buds") rather than a count,
    // because the names are the useful part. Past two, a count is the only thing
    // that fits — the tile is about 165px wide.
    subtitle: {
        if (root.adapter === null)
            return qsTr("No adapter");
        if (root.adapter.state === BluetoothAdapterState.Blocked)
            return qsTr("Blocked by hardware");
        if (root.adapter.state === BluetoothAdapterState.Enabling)
            return qsTr("Turning on…");
        if (root.adapter.state === BluetoothAdapterState.Disabling)
            return qsTr("Turning off…");
        if (!root.adapter.enabled)
            return qsTr("Off");

        const names = root.connectedNames;
        if (names.length === 0)
            return qsTr("On");
        if (names.length <= 2)
            return names.join(" · ");       // the interpunct the design uses
        return qsTr("%1 devices").arg(names.length);
    }

    onActivated: {
        if (root.adapter === null)
            return;
        root.adapter.enabled = !root.adapter.enabled;
    }
}
