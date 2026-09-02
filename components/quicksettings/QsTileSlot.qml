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
//   ⚠️ THIS FILE USED TO CLAIM Quickshell.Networking WAS MISSING ON THE BUILD WE
//   SHIP. It is not. Checked on the machine on 2026-09-02: Fedora's
//   `quickshell-0.2.1^git20260209.dacfa9d-5.fc44` is a git snapshot from long
//   after the 0.2.1 tag, and it carries
//   /usr/lib64/qt6/qml/Quickshell/Networking. Every module all four tiles import
//   — Networking, Bluetooth, UPower — is present. No tile falls back today.
//
//   That does not retire this file, for two reasons:
//
//     1. The version floor is not ours to hold. Bazzite is rebased continuously
//        and this shell is also run on plain Fedora, Arch and a copr build. "The
//        module happens to be there right now" is a fact about one machine on
//        one day, which is exactly the kind of fact that stops being true
//        quietly and takes a whole panel with it.
//     2. It is the difference between one dimmed square and a blank panel, and
//        the person looking at a blank panel has no way to tell which of the
//        twelve files caused it.
//
//   What this file could NOT have saved us from is the bug it was written for's
//   near cousin: a module that IS installed but spells one of its enums
//   differently. That file loads perfectly and then throws a ReferenceError deep
//   inside one binding. See the `connState` note in TileWifi.qml, and section 28
//   of tests/test-shell.sh, which is what actually guards against it.
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
