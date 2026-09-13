// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// CaptureService — screenshots and screen recordings, from one small helper
// =============================================================================
// WHAT THIS IS
//
//   The shell's half of feature 017. The bar gets two buttons — a camera and a
//   record circle — and each offers three ways to capture: the whole screen, a
//   single application window, or an area you drag out with the mouse. None of
//   that work happens in here. Every one of those is a line of shell script in
//   ONE program that the OS image installs:
//
//       /usr/libexec/aquarius-capture
//
//   and this file is the only place in the shell that speaks to it.
//
// THE CONTRACT, WHICH IS FIXED AND SHARED WITH THE OTHER REPOSITORY
//
//   aquarius-capture shot   screen|window|area
//       Takes a still picture. The HELPER saves the file, copies it to the
//       clipboard and raises the notification — not us. Exit 0 means it is
//       done; a non-zero exit is usually the person pressing Escape out of the
//       area picker, which is not an error and is not reported as one.
//
//   aquarius-capture record screen|window|area
//       Starts a recording and RETURNS as soon as it is running. It does not
//       stay in the foreground, so nothing here has to babysit a process.
//
//   aquarius-capture record stop
//       Stops the recording that is running.
//
//   aquarius-capture status
//       Prints one line of JSON and ALWAYS exits 0:
//
//           {"recording":true,"started":1789245600,
//            "file":"~/Screenshots/Screen Recording ….mp4",
//            "elapsed":42}
//
//   aquarius-capture folder
//       Prints the Screenshots folder's path.
//
//   This shell speaks standard Wayland protocols and shells out to that one
//   command. It never talks to a compositor-private interface — the one
//   architectural law in README.md. Which program actually takes the picture
//   (grim, slurp, wf-recorder) is the image's business, not ours, and it can be
//   swapped there without this file changing a character.
//
// WHY THE HELPER IS THE ONE HOLDING THE TRUTH
//
//   A recording can be started by a keyboard shortcut, by the bar, or by a
//   person typing the command in a terminal — and the shell can be reloaded
//   while one is running (editing a QML file does exactly that). So the shell
//   must never be the place that REMEMBERS whether a recording is going. It
//   ASKS, once a second while it believes one is running, and more slowly the
//   rest of the time so that a recording started by a keyboard shortcut still
//   turns the bar button red within a few seconds. It also asks once at
//   start-up, which is what makes a shell reload during a recording harmless.
//
// WHEN THE HELPER IS NOT THERE — the nested harness, a developer's Fedora box
//
//   `available` goes false, and every function logs one warning and returns.
//   The buttons still draw and still open their menus: a bar that rearranges
//   itself depending on which machine it woke up on is harder to reason about
//   than one that is always the same shape, and the warning in the log says
//   exactly what is missing. Nothing here throws.
//
// TESTING IT WITHOUT THE OS
//
//   AQ_CAPTURE_BIN overrides the path. tests/fixtures/capture/aquarius-capture
//   is a fake helper that answers the whole contract out of a temporary file,
//   which is how tests/test-shell.sh exercises the JSON parsing, the elapsed
//   clock and the recording state changes on a machine with no image on it.
// =============================================================================
pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- where the helper is -------------------------------------------------
    // The image installs it at the first path. AQ_CAPTURE_BIN is for the
    // harness and the tests; it is read once, at start-up, because a shell that
    // changed which program it runs halfway through a session would be a much
    // stranger thing than one that needs restarting.
    readonly property string defaultBin: "/usr/libexec/aquarius-capture"
    readonly property string bin: {
        const override = Quickshell.env("AQ_CAPTURE_BIN");
        return (override === null || override === undefined || String(override) === "")
            ? root.defaultBin
            : String(override);
    }

    // Is that file there and runnable? Probed once at start-up and again every
    // time somebody asks for a capture, so installing the image's helper while
    // the shell is already running does not need a reload.
    property bool available: false

    // ---- what is happening right now ----------------------------------------
    // All three are written ONLY by readStatus(). Nothing else in this file, and
    // nothing outside it, may set them: they are what the helper said, and the
    // helper is the truth.
    property bool recording: false
    property int elapsedSeconds: 0
    property string lastFile: ""

    // The Screenshots folder, as the helper reports it. Read once, lazily; the
    // bar does not use it yet, but "where did that go?" is the first question
    // anybody asks and this is the answer without a second guess at the path.
    property string folder: ""

    // True from the moment a start is asked for until the helper has answered.
    // It is what stops two clicks in quick succession starting two recordings.
    property bool starting: false
    property bool stopping: false

    // mm:ss for the bar. Hours roll into the minutes rather than growing a third
    // field — a 90-minute recording reads 90:00, which is unambiguous and does
    // not make the bar item change width halfway through a screencast.
    readonly property string elapsedText: root.formatElapsed(root.elapsedSeconds)

    function formatElapsed(seconds: int): string {
        const total = (seconds > 0) ? seconds : 0;
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return (minutes < 10 ? "0" : "") + minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    // ---- the three things the bar can ask for -------------------------------
    // `mode` is "screen", "window" or "area". Anything else is refused here
    // rather than handed to the helper: the helper would reject it too, but the
    // warning would come out of a program the person cannot see.
    readonly property var modes: ["screen", "window", "area"]

    function isMode(mode: string): bool {
        return root.modes.indexOf(mode) !== -1;
    }

    function warnMissing(what: string): void {
        console.warn("aquarius-shell: cannot " + what + " — " + root.bin
                    + " is not installed on this machine."
                    + " Screenshots and recordings come from the OS image's"
                    + " capture helper (feature 017); in the nested harness"
                    + " there is none. Set AQ_CAPTURE_BIN to a stand-in.");
    }

    // A still picture. Fire and forget: the helper saves it, copies it to the
    // clipboard and raises the notification itself.
    function shot(mode: string): void {
        if (!root.isMode(mode)) {
            console.warn("aquarius-shell: unknown screenshot mode '" + mode + "'");
            return;
        }
        probe.running = true;          // keep `available` honest
        if (!root.available) {
            root.warnMissing("take a screenshot");
            return;
        }
        if (shotProc.running) {
            // The area picker is already up. A second one would fight the first
            // for the pointer, so the click is dropped on purpose.
            return;
        }
        shotProc.command = [root.bin, "shot", mode];
        shotProc.running = true;
    }

    // Start recording. Returns as soon as the helper says it is running; the
    // poll below is what turns the bar button red.
    function record(mode: string): void {
        if (!root.isMode(mode)) {
            console.warn("aquarius-shell: unknown recording mode '" + mode + "'");
            return;
        }
        probe.running = true;
        if (!root.available) {
            root.warnMissing("start a recording");
            return;
        }
        // The double-start guard. Three ways to already be busy: one is running,
        // one is being started, or one is being stopped and the file is still
        // being closed.
        if (root.recording || root.starting || root.stopping || recordProc.running)
            return;

        root.starting = true;
        recordProc.command = [root.bin, "record", mode];
        recordProc.running = true;
    }

    // Stop it. Safe to call when nothing is recording; the helper treats that as
    // a no-op, and this refuses before it gets there anyway.
    function stop(): void {
        probe.running = true;
        if (!root.available) {
            root.warnMissing("stop the recording");
            return;
        }
        if (!root.recording || root.stopping || stopProc.running)
            return;

        root.stopping = true;
        stopProc.command = [root.bin, "record", "stop"];
        stopProc.running = true;
    }

    // Ask the helper what is true. Called by the poll, by start-up, and after
    // every start and stop.
    function readStatus(): void {
        if (!root.available || statusProc.running)
            return;
        statusProc.running = true;
    }

    // ---- reading the answer --------------------------------------------------
    // The helper's own JSON, parsed defensively. A partial line (the helper
    // caught mid-write), an empty one, or anything that is not an object leaves
    // every value exactly as it was: a bar item that flickers out of the
    // recording state for one second and back is worse than one that waits for
    // the next poll.
    function applyStatus(text: string): void {
        const trimmed = (text === undefined || text === null) ? "" : String(text).trim();
        if (trimmed === "")
            return;

        let parsed = null;
        try {
            parsed = JSON.parse(trimmed);
        } catch (error) {
            console.warn("aquarius-shell: capture status was not JSON: " + trimmed);
            return;
        }

        if (parsed === null || typeof parsed !== "object")
            return;

        const nowRecording = (parsed.recording === true);

        // The elapsed seconds are the helper's, not a clock of ours. A recording
        // that survived a shell reload therefore shows the right time
        // immediately rather than starting again from zero.
        let seconds = 0;
        if (typeof parsed.elapsed === "number" && isFinite(parsed.elapsed))
            seconds = Math.max(0, Math.floor(parsed.elapsed));

        if (typeof parsed.file === "string" && parsed.file !== "")
            root.lastFile = parsed.file;

        root.recording = nowRecording;
        root.elapsedSeconds = nowRecording ? seconds : 0;

        // Whatever the helper says is running or not running settles both of
        // these: a start that failed cannot leave the bar stuck on "starting".
        if (nowRecording)
            root.starting = false;
        else
            root.stopping = false;
    }

    // ---- start-up ------------------------------------------------------------
    Component.onCompleted: probe.running = true

    // Is the helper there? `test -x` is the same presence probe the Aquarius
    // menu uses for the updater, for the same reason: it is one tiny program
    // that answers with an exit code and cannot go wrong.
    Process {
        id: probe
        command: ["test", "-x", root.bin]
        onExited: function (exitCode) {
            const nowAvailable = (exitCode === 0);
            const firstTime = nowAvailable && !root.available;
            root.available = nowAvailable;
            if (firstTime) {
                // Recover state the moment we know there is somebody to ask —
                // this is the "shell reloaded during a recording" case.
                root.readStatus();
                folderProc.running = true;
            }
        }
    }

    Process {
        id: folderProc
        command: [root.bin, "folder"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim();
                if (value !== "")
                    root.folder = value;
            }
        }
    }

    Process {
        id: shotProc
        command: []
        onExited: function (exitCode) {
            // Non-zero is the ordinary way a person says "never mind" — Escape
            // out of the area picker, or no window chosen. Said quietly, once,
            // because it is not a fault.
            if (exitCode !== 0)
                console.info("aquarius-shell: screenshot cancelled or failed"
                            + " (aquarius-capture exited " + exitCode + ")");
        }
    }

    Process {
        id: recordProc
        command: []
        onExited: function (exitCode) {
            root.starting = false;
            if (exitCode !== 0)
                console.info("aquarius-shell: recording not started"
                            + " (aquarius-capture exited " + exitCode + ")");
            // Either way, ask. The helper is the truth and it has just changed.
            root.readStatus();
        }
    }

    Process {
        id: stopProc
        command: []
        onExited: function (exitCode) {
            root.stopping = false;
            if (exitCode !== 0)
                console.info("aquarius-shell: stopping the recording failed"
                            + " (aquarius-capture exited " + exitCode + ")");
            root.readStatus();
        }
    }

    Process {
        id: statusProc
        command: [root.bin, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(this.text)
        }
    }

    // ---- the poll ------------------------------------------------------------
    // One second while a recording is running, because the elapsed clock in the
    // bar has to tick. Every five seconds otherwise, so that a recording started
    // by a keyboard shortcut (⌘⇧6, or PrtSc's twin on the Windows layout) still
    // lights the bar button up without anybody clicking anything. Both are one
    // very small program that prints one line; the slow tick costs twelve
    // launches a minute at worst and it is what keeps the two ways of starting
    // a recording in agreement.
    Timer {
        interval: root.recording ? 1000 : 5000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: root.readStatus()
    }
}
