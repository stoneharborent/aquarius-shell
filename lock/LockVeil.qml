// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LockVeil — the frosted sheet the lock screen is drawn on
// =============================================================================
// WHAT IT IS: the same wallpaper the desktop has, blurred, with a wash of the
// theme's own background colour over it. It fills a whole screen and everything
// else on the lock screen sits on top of it.
//
// ⚠️ IT IS THE WALLPAPER, NOT THE DESKTOP. This is a rule, not an
// implementation detail, and it is why this file draws a picture from disk
// rather than capturing the screen.
//
// Quickshell can capture a live screen — `ScreencopyView` does exactly that —
// and a blurred photograph of your actual desktop is what several other lock
// screens show. It looks lovely and it is a mistake. A blur is not redaction.
// A 20-pixel blur of an email still tells anybody standing behind you how many
// messages you have, who is on the call you are in, and roughly what the
// document says; a name in a large heading survives it almost intact. And a
// blur is a rendering choice, which means a bug, a slow frame or a driver quirk
// can hand back the un-blurred frame.
//
// The wallpaper leaks nothing, cannot leak anything, and is what the login
// screen already shows. So: the wallpaper.
//
// -----------------------------------------------------------------------------
// THE BLUR, AND WHY IT IS BEHIND A Loader
// -----------------------------------------------------------------------------
// Read LockBlur.qml's header. Short version: the blur needs an import that
// would take this whole file down with it if it ever failed, and on a lock
// screen a file that will not load means a computer nobody can get back into.
// So the import is quarantined in its own file, loaded through a Loader, and if
// it is not there the veil is the plain wallpaper under a heavier wash.
// =============================================================================
import QtQuick

import "../theme"

Item {
    id: root

    // Where the wallpaper is. Written as properties rather than straight into
    // the Image so the nested harness can point them at something else on a
    // machine that is not AquariusOS.
    property string wallpaperLight: "/usr/share/backgrounds/aquarius/the-pour-ice-3840x2160.png"
    property string wallpaperDark: "/usr/share/backgrounds/aquarius/the-pour-midnight-3840x2160.png"

    // True once the blur is really there. The wash leans on this: without a
    // blur it has to work harder, because a sharp wallpaper under a light wash
    // is a lock screen you can read the desktop's shape through.
    readonly property bool blurred: blurLoader.status === Loader.Ready
                                    && blurLoader.item !== null

    // ---- the picture ---------------------------------------------------------
    // Invisible when the blur loaded, because in that case MultiEffect is
    // drawing it for us — see LockBlur.qml. Visible when it did not, so the
    // fallback is a sharp wallpaper rather than a black rectangle.
    Image {
        id: plate

        anchors.fill: parent
        source: "file://" + (Theme.dark ? root.wallpaperDark : root.wallpaperLight)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        // The picture is 3840x2160 and the screen may not be. Telling Qt the
        // size to decode at means a laptop screen does not hold an 8-megapixel
        // image in memory to draw two million pixels of it.
        sourceSize.width: root.width
        sourceSize.height: root.height
        smooth: true
        visible: !root.blurred
    }

    Loader {
        id: blurLoader

        anchors.fill: parent
        source: "LockBlur.qml"

        onLoaded: {
            blurLoader.item.plate = plate;
            blurLoader.item.blurWidth = Theme.lockVeilBlur;
        }

        onStatusChanged: {
            if (blurLoader.status === Loader.Error)
                console.warn("aquarius-lock: no QtQuick.Effects on this machine, "
                             + "so the veil is the plain wallpaper under a heavier wash");
        }
    }

    // ---- the wash ------------------------------------------------------------
    // The theme's own ground colour, laid over the blur. This is what makes the
    // lock screen Ice in the light theme and Midnight in the dark one, and it
    // follows the system live: flip the theme while the machine is locked and
    // this changes with it, because Theme.bg is a binding like every other
    // colour in this shell.
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        // Half again as much when there is no blur to hide behind. Not a
        // separate design decision — it is the same design, doing the same job,
        // with one of its two tools missing.
        opacity: root.blurred
            ? Theme.lockVeilWash
            : Math.min(1.0, Theme.lockVeilWash * 1.5)

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.lockVeilFadeMs
            }
        }
    }
}
