// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// QsTileSlot — the safety net that loads one tile
// =============================================================================
// WHY EVERY TILE IS BEHIND A LOADER, AND WHY THIS IS NOT PARANOIA
//
//   A QML file that imports a module which is not installed does not warn and
//   carry on. It fails to load, completely. If that file is part of the panel,
//   the panel does not open. If it is `import`ed by the panel's own file, the
//   PANEL fails. One missing module takes everything with it.
//
//   That is not hypothetical here. It is the situation today:
//
//     Quickshell.Networking — which the Wi-Fi tile needs — LANDED IN QUICKSHELL
//     v0.3.0. The changelog's v0.3.0 entry reads "Added network management
//     support", and the v0.2.1 type index has no Quickshell.Networking module at
//     all. Fedora's `quickshell` package is a 0.2.1 snapshot (checked when
//     docs/adr/0001-framework.md was written). Arch has 0.3.1.
//
//   So on a plain Fedora box today, `import Quickshell.Networking` fails. With
//   this file in the way, that costs a dimmed Wi-Fi tile. Without it, it costs
//   the whole Quick Settings panel — and the person seeing that has no way to
//   tell which of the twelve files caused it.
//
//   The other three tiles' modules (Bluetooth, UPower) are present in v0.2.1, so
//   they do not need this today. They get it anyway, because "which of these is
//   safe" is exactly the kind of thing that stops being true quietly.
//
//   This pattern is lifted from the KDE Wave-2 widget's AqTileSlot.qml, which
//   solved the same problem for the same reason.
//
// WHAT A FAILED TILE LOOKS LIKE
//   A dimmed, unclickable QsTile with the right name on it. The grid keeps its
//   shape; the person sees "Wi-Fi, unavailable" rather than a hole or a blank
//   panel. The reason is printed once to the log, because the person cannot see
//   it and whoever is debugging needs it.
// =============================================================================
import QtQuick

import "../../theme"

Item {
    id: root

    // The tile file to load, e.g. "TileWifi.qml". Resolved relative to THIS
    // file, which is the same directory the tiles live in.
    property string tileSource: ""

    // What the placeholder says if the load fails.
    property string fallbackTitle: ""
    property string fallbackGlyph: ""

    implicitHeight: Theme.qsTileHeight

    Loader {
        id: loader
        anchors.fill: parent
        source: root.tileSource

        // Synchronous on purpose. These are tiny files, the panel is about to be
        // shown, and an asynchronous load would make the grid pop in a piece at
        // a time in front of the person who just clicked.
        asynchronous: false

        onStatusChanged: {
            if (loader.status === Loader.Error) {
                console.warn("aquarius-shell: Quick Settings could not load",
                             root.tileSource,
                             "- showing a placeholder instead. The usual cause is",
                             "a Quickshell module this build does not have; see",
                             "docs/quick-settings.md.");
            }
        }
    }

    // The placeholder. Only drawn when the real thing did not arrive.
    QsTile {
        anchors.fill: parent
        visible: loader.status === Loader.Error || loader.status === Loader.Null
        title: root.fallbackTitle
        glyph: root.fallbackGlyph
        subtitle: qsTr("Unavailable")
        active: false
        available: false
    }
}
