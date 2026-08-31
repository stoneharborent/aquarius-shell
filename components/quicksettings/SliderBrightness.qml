// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SliderBrightness — the Brightness slider. ⚠️ INTERIM: it shells out.
// =============================================================================
// ⚠️ READ THIS BEFORE COPYING THE PATTERN ANYWHERE ELSE.
//
//   Every other service in this panel goes through a Quickshell service that
//   speaks a published protocol. This one runs a command-line program. It is the
//   only place in the shell that does, apart from the Game Mode handoff, and
//   tests/test-shell.sh enforces that.
//
// WHY: QUICKSHELL HAS NO BRIGHTNESS SERVICE. I CHECKED.
//
//   The v0.3.1 module index (https://quickshell.org/docs/v0.3.1/types/) lists
//   Bluetooth, DBusMenu, Hyprland, I3, Io, Networking, Greetd, Mpris,
//   Notifications, Pam, Pipewire, Polkit, SystemTray, UPower, Wayland, Widgets
//   and WindowManager. There is no brightness or backlight type in any of them,
//   and UPower's types are batteries and power profiles only. So unlike Wi-Fi —
//   where the roadmap expected hand-rolled D-Bus and Quickshell turned out to
//   have a service — there genuinely is no QML path here.
//
//   The alternatives were:
//
//     a) Write to /sys/class/backlight/*/brightness directly. Needs root or a
//        udev rule, and picking the right device is the same guessing game.
//     b) Talk to logind's org.freedesktop.login1.Session.SetBrightness over
//        D-Bus. Correct, unprivileged, and the right long-term answer — but
//        Quickshell exposes no generic D-Bus client type, so it is not reachable
//        from QML today.
//     c) Run brightnessctl. It exists for exactly this, it is packaged
//        everywhere, and on Fedora it ships udev rules that let a member of the
//        `video` group set brightness without root.
//
//   (c), clearly labelled as interim, until either Quickshell grows a brightness
//   service or a generic D-Bus type. When that happens this file is replaced
//   wholesale and nothing else changes — which is the reason the shelling-out is
//   quarantined in one file behind the plain QsSlider interface.
//
// WHAT brightnessctl ACTUALLY PRINTS
//   `brightnessctl -m -c backlight i` prints one comma-separated line:
//
//       amdgpu_bl1,backlight,64,25%,255
//       device,class,current,percent,max
//
//   The fourth field is the percentage with a % on the end. `-m` is "machine
//   readable" and is what makes this parseable at all.
//
//   `brightnessctl -q -c backlight set 60%` sets it. Percent rather than a raw
//   number, so nothing here has to know the hardware's own scale (which is NOT
//   0-100 — it is commonly 0-255, 0-937, or whatever the panel reports).
//
// WHAT HAPPENS ON A MACHINE WITH NO BACKLIGHT
//   Most desktop monitors have no software brightness control at all; they are
//   dimmed by their own physical buttons. brightnessctl then exits non-zero or
//   prints nothing parseable, the first read fails, `available` stays false, and
//   the row hides itself. Which is correct: a slider that moves and changes
//   nothing is worse than no slider.
// =============================================================================
import QtQuick

import Quickshell.Io

QsSlider {
    id: root

    label: qsTr("Brightness")

    // True only once a read has actually succeeded. Starting false and never
    // optimistically flipping it is what makes the "no backlight" case correct
    // without needing to detect it separately.
    property bool readSucceeded: false
    available: root.readSucceeded

    // Set by the panel while it is on screen. Polling a subprocess forever in
    // the background would be rude; polling while the panel is open is what
    // catches somebody pressing the brightness key on their keyboard with the
    // panel already up.
    property bool live: false

    value: root.level
    property real level: 0

    onMoved: function (newValue) {
        // Move the handle immediately, then tell the hardware. Waiting for
        // brightnessctl to return before the handle moves would make the slider
        // feel like it is dragging through mud.
        root.level = newValue;
        applyDebounce.restart();
    }

    onLiveChanged: if (root.live) root.read()

    Component.onCompleted: root.read()

    // ---- reading -------------------------------------------------------------
    function read() {
        if (reader.running)
            return;
        reader.running = true;
    }

    Process {
        id: reader
        command: ["brightnessctl", "-m", "-c", "backlight", "i"]

        stdout: StdioCollector {
            onStreamFinished: {
                // amdgpu_bl1,backlight,64,25%,255
                const fields = this.text.trim().split(",");
                if (fields.length < 4)
                    return;

                const percent = parseInt(fields[3].replace("%", ""), 10);
                if (isNaN(percent))
                    return;

                root.level = Math.max(0, Math.min(1, percent / 100));
                root.readSucceeded = true;
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0 && !root.readSucceeded) {
                // Said once, quietly. On a desktop tower this is the normal,
                // expected outcome and not a fault.
                console.log("aquarius-shell: no readable backlight",
                            "(brightnessctl exited", exitCode + ").",
                            "Hiding the Brightness slider.");
            }
        }
    }

    // ---- writing -------------------------------------------------------------
    // Dragging emits a value on every mouse move. Firing a subprocess per pixel
    // would spawn dozens a second, so writes are collapsed into one every 60ms
    // — fast enough that the screen tracks the finger, slow enough that the
    // machine is not being asked to fork constantly.
    Timer {
        id: applyDebounce
        interval: 60
        repeat: false
        onTriggered: root.apply(root.level)
    }

    function apply(fraction: real) {
        const percent = Math.round(Math.max(0, Math.min(1, fraction)) * 100);
        writer.command = ["brightnessctl", "-q", "-c", "backlight",
                          "set", percent + "%"];
        // The documented way to restart a Process: stopping one that is not
        // running is a no-op, so this is safe on the first call too.
        writer.running = false;
        writer.running = true;
    }

    Process {
        id: writer
        // `command` is assigned in apply(), not bound, so that nothing here can
        // start a process by itself.
    }

    // ---- keeping up with the keyboard ---------------------------------------
    Timer {
        interval: 4000
        repeat: true
        running: root.live && root.readSucceeded
        onTriggered: root.read()
    }
}
