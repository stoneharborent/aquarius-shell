// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// TileWifi — the Wi-Fi switch, and the name of the network you are on
// =============================================================================
// ⚠️ THIS FILE HAS TO RUN ON TWO DIFFERENT QUICKSHELL BUILDS
//
//   For a while this header said `Quickshell.Networking` needed Quickshell
//   0.3.0. That was wrong, and it was wrong in the expensive direction. The
//   build AquariusOS actually ships — Fedora's
//   `quickshell-0.2.1^git20260209.dacfa9d-5.fc44`, a git snapshot taken well
//   after the 0.2.1 tag — HAS the module. It was found installed at
//   /usr/lib64/qt6/qml/Quickshell/Networking on 2026-09-02, and this tile does
//   load there.
//
//   What the two builds do NOT share is the name of one enum:
//
//     the device's connection state    0.2.1 git   `DeviceConnectionState`
//                                      0.3.x       `ConnectionState`
//
//   Same five variants in both (Unknown, Connecting, Connected, Disconnecting,
//   Disconnected) — only the namespace was renamed. This file named the 0.3.x
//   one, and on the shipped build that is a ReferenceError, which kills the
//   binding it appears in. On the bench PC nothing noticed, because that machine
//   has no Wi-Fi adapter and the subtitle returns "No adapter" long before the
//   line is reached. On a laptop or a handheld it would have cost the subtitle.
//   See `connState` below for how both builds are served at once.
//
// WHAT WAS ACTUALLY CHECKED, AND WHAT THE ROADMAP SAID
//   The roadmap's P2 entry says "NetworkManager over D-Bus", which read as "we
//   will be writing a D-Bus client by hand". We do not have to. Quickshell 0.3.0
//   ships a NetworkManager-backed service with a QML API, so the D-Bus is
//   somebody else's problem and the standardised-protocols law is satisfied the
//   same way it is for the tray: through a published interface, spoken by a
//   service that already exists.
//
//   Checked twice over: against
//   https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/, and against
//   the module as installed on the shipped 0.2.1 git build, by reading its
//   `quickshell-network.qmltypes` and by running a QML probe under it.
//
//     Networking (singleton)  wifiEnabled (writable), wifiHardwareEnabled,
//                             devices : ObjectModel<NetworkDevice>
//     NetworkDevice           type : DeviceType, connected, state
//     WifiDevice              networks : ObjectModel<WifiNetwork>
//     Network                 name, connected, state
//     WifiNetwork : Network   signalStrength (0..1), security, connect()
//
//   Everything on that list is on BOTH builds. `Networking.connectivity` is
//   0.3.x only and is not used here. Neither is `WifiNetwork.connectWithPsk()`,
//   which on 0.2.1 is just `connect()` — a Phase P3 problem, noted below.
//
//   `Networking` says of itself: "An interface to a network backend (currently
//   only NetworkManager)". So it IS NetworkManager, reached through a QML
//   surface rather than a hand-rolled D-Bus client.
//
// WHAT THIS TILE DELIBERATELY DOES NOT DO
//   Pick a network. The design's tile is a switch with a name under it, and that
//   is what this is. Choosing between networks, and typing a password for one,
//   is a list and a text field — a Settings surface, which is Phase P3. The call
//   it will make is `WifiNetwork.connect()` on 0.2.1 and `connectWithPsk()` on
//   0.3.x, so whoever builds it gets to solve the same two-builds problem again.
//   A half-built picker in a 165px-wide tile would be worse than none.
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

    // ---- the enum whose name moved -------------------------------------------
    // `NetworkDevice.state` is an enum, and the enum's NAMESPACE is spelled
    // differently on the two builds this shell has to run on:
    //
    //   Quickshell 0.2.1 git (what AquariusOS ships)   DeviceConnectionState
    //   Quickshell 0.3.x     (Arch, the copr build)    ConnectionState
    //
    // Naming the missing one is a ReferenceError, and a ReferenceError in QML
    // does not warn and carry on — it kills the binding that touched it. So look
    // the namespace up once, by name, and read everything downstream off that.
    //
    // `typeof` is safe on a QML type that does not exist: it answers "undefined"
    // rather than throwing. That was not assumed — it was run under 0.2.1 on
    // Qt 6.11 on 2026-09-02, along with the two names below.
    //
    // Do NOT replace this with the raw numbers. The variants are not declared in
    // the same order on the two builds, so the numbers are not portable even
    // though the words are.
    readonly property var connState:
        (typeof ConnectionState !== "undefined") ? ConnectionState             // 0.3.x
        : (typeof DeviceConnectionState !== "undefined") ? DeviceConnectionState // 0.2.1
        : null                                                                  // neither: say nothing

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
        // If neither build's enum is there, fall through to "Not connected"
        // rather than guess — it is the true state either way, just less
        // specific about how it got there.
        if (root.connState !== null
                && root.wifiDevice.state === root.connState.Connecting)
            return qsTr("Connecting…");
        return qsTr("Not connected");
    }

    // One property, writable, that maps onto NetworkManager's own software
    // rfkill switch for every wireless device at once. That is the same thing
    // the Plasma tile did through `Handler.enableWireless()`.
    onActivated: Networking.wifiEnabled = !Networking.wifiEnabled
}
