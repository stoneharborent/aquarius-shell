// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// QsPlatform — which machine is this, and where does the OS layer begin?
// =============================================================================
// THE PROBLEM: the design's fourth tile does not exist on every computer
//
//   The V2 design's 2x2 grid is Wi-Fi, Bluetooth, Focus and Game Mode. Three of
//   those are on every machine. The fourth is not: "Game Mode" means the Steam
//   big-picture session a handheld boots into, and it is part of Bazzite's
//   handheld image. It does not exist on a desktop or a laptop.
//
//   A Game Mode tile on Royce's workstation would be a button that cannot do
//   anything, taking up a quarter of the panel. Leaving the square empty is
//   worse — a 2x2 grid with a hole in it reads as broken rather than deliberate.
//
// THE DECISION (carried over from the KDE Wave-2 widget, unchanged)
//
//   The fourth tile is ADAPTIVE: Game Mode on a handheld, Performance (the power
//   profile) everywhere else. A gamer on a handheld presses Game Mode to play; a
//   creator at a workstation presses Performance before a render. The tile keeps
//   its meaning even though the mechanism differs, which is why the two can
//   share a slot without the panel feeling inconsistent between machines.
//
//   Rejected, and why, so nobody re-derives it: Night Light (a comfort setting,
//   not a "the machine is about to work hard" one); Airplane mode (duplicates
//   the two tiles either side of it, the one thing a four-tile grid cannot
//   afford); three tiles on desktops (see above).
//
// ⚠️ THE CHOICE IS MADE WHEN THE PANEL OPENS, NOT WHEN THE IMAGE IS BUILT
//
//   AquariusOS builds three images from ONE recipe, and the standing rule in the
//   Containerfile is that there is no per-variant branching. Deciding this at
//   build time would break that rule for one square in one panel. So the shell
//   ships identically everywhere and works out where it is running.
//
// ⚠️ GAME MODE IS THE OS LAYER'S, NOT THE SHELL'S — THIS IS THE SEAM
//
//   The shell does not and must not implement Game Mode. Switching a Bazzite
//   machine into the Steam session is a session change: it stops the desktop
//   session and starts another one. That belongs to the OS image, which ships
//   `/usr/bin/return-to-gamemode` for exactly this purpose (Bazzite's own
//   `bazzite-user-setup` puts a "Return to Gaming Mode" launcher on the desktop
//   that runs it).
//
//   So the seam is: THE SHELL CALLS ONE COMMAND, NAMED IN EXACTLY ONE FILE.
//   That file is TileGameMode.qml, and its `osCommand` property is the entire
//   surface between this shell and Bazzite's session switching. If the OS
//   renames the command, or replaces it with a D-Bus call or a systemd unit,
//   that one property changes and nothing else in the shell moves.
//
//   This file decides only WHETHER that tile appears. It does not know how Game
//   Mode works and must not learn.
//
//   The tile is a DOOR, not a switch. It never reports Game Mode as "on",
//   because from inside a desktop session it never is: pressing it ends this
//   session. Faking a toggle there would be a lie about something irreversible.
// =============================================================================
import QtQuick

import Quickshell.Io

QtObject {
    id: root

    // -------------------------------------------------------------------------
    // Is this a handheld?
    // -------------------------------------------------------------------------
    // Starts false so a desktop — the common case — never flickers through a
    // Game Mode tile on its way to the right answer.
    property bool isHandheld: false

    // HOW THE TEST WORKS, AND WHY IT IS THIS TEST
    //   Every Universal Blue image — which is what Bazzite is, and therefore
    //   what AquariusOS is — writes /usr/share/ublue-os/image-info.json with an
    //   "image-name" field. Ours are "aquarius-os", "aquarius-os-nvidia" and
    //   "aquarius-os-deck", so the handheld is the one with "deck" in it.
    //
    //   This is not a convention invented here: it is the same test Bazzite
    //   itself uses. Its `bazzite-user-setup` does `if [[ $IMAGE_NAME =~ "deck" ]]`
    //   against this exact field, and that script is what puts the "Return to
    //   Gaming Mode" launcher on the desktop in the first place. Matching
    //   Bazzite's test means this tile appears exactly when that launcher does.
    //
    //   Anything that goes wrong — file missing (any non-AquariusOS machine,
    //   including every bench VM), unreadable, not JSON — means "not a
    //   handheld", which is the safe answer: Performance works on a handheld
    //   too, whereas a Game Mode tile on a desktop would not.
    property FileView imageInfo: FileView {
        path: "/usr/share/ublue-os/image-info.json"

        // NOT blockLoading. The Quickshell docs are explicit that a blocking
        // read stops the whole interface, and recommend it only for files needed
        // before any window exists. This one is needed when a panel opens, and
        // being wrong for a few milliseconds costs nothing because the default
        // answer is already the common one.
        blockLoading: false

        // On any machine that is not an AquariusOS install — every bench VM,
        // every developer's Fedora box — this file does not exist. That is the
        // normal case, not a fault, so it must not print an error on every
        // start-up. FileView prints read errors by default; this turns that off
        // for this one file.
        printErrors: false

        // `loaded` is both a readonly property and a signal on FileView. This is
        // the SIGNAL handler — it fires once, when the read succeeds.
        onLoaded: root.readImageName()

        // Said out loud, once, at log level rather than warning level, because
        // "there is no image-info.json" is the expected answer off the OS.
        onLoadFailed: {
            root.isHandheld = false;
            console.log("aquarius-shell: no /usr/share/ublue-os/image-info.json;",
                        "assuming this is not a handheld.");
        }
    }

    function readImageName() {
        try {
            const info = JSON.parse(root.imageInfo.text());
            const imageName = info["image-name"] || "";
            root.isHandheld = imageName.indexOf("deck") !== -1;
        } catch (error) {
            root.isHandheld = false;
        }
    }

    // -------------------------------------------------------------------------
    // Which file fills the fourth square
    // -------------------------------------------------------------------------
    readonly property string fourthTileSource:
        root.isHandheld ? "TileGameMode.qml" : "TilePowerProfile.qml"

    readonly property string fourthTileFallbackTitle:
        root.isHandheld ? qsTr("Game Mode") : qsTr("Performance")

    readonly property string fourthTileFallbackGlyph:
        root.isHandheld ? "gamepad" : "speedometer"
}
