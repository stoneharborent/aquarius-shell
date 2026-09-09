// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SystemAppearance — does this machine want a light desktop or a dark one?
// =============================================================================
// WHAT THIS IS FOR
//   Theme.qml used to hold a stored `dark` value that somebody had to flip by
//   hand. This file makes it follow the system instead: turn the machine dark
//   and the shell turns Midnight, turn it light and the shell turns Ice, with
//   no restart and nothing to configure.
//
// WHAT IT ASKS, AND WHO ANSWERS
//   There is one cross-desktop way to ask this question, and it is a standard:
//
//     bus:        session
//     service:    org.freedesktop.portal.Desktop
//     object:     /org/freedesktop/portal/desktop
//     interface:  org.freedesktop.portal.Settings
//     method:     ReadOne("org.freedesktop.appearance", "color-scheme") -> u
//     signal:     SettingChanged(namespace, key, value)
//
//   The answer is one small number:
//       0  no preference
//       1  prefer dark
//       2  prefer light
//   Anything else is to be treated as 0. (Verified against the interface's own
//   documentation, org.freedesktop.portal.Settings.xml, xdg-desktop-portal.)
//
//   This is the same question GNOME apps, KDE apps, GTK apps, Firefox and every
//   Flatpak ask. Answering it the same way is exactly the "standardised
//   protocols only" law applied to appearance instead of to windows.
//
// WHY IT SHELLS OUT TO gdbus INSTEAD OF USING A QUICKSHELL SERVICE
//   Because there is no Quickshell service for it. This was checked against the
//   full module listing of Quickshell v0.3.1, not remembered: the modules are
//   Quickshell, .Bluetooth, .DBusMenu, .Hyprland, .I3, .Io, .Networking,
//   .Services.{Greetd,Mpris,Notifications,Pam,Pipewire,Polkit,SystemTray,
//   UPower}, .Wayland, .Widgets and .WindowManager. There is no portal module,
//   no appearance service, and no general-purpose D-Bus type in QML.
//
//   Quickshell's own FAQ points at exactly this answer for exactly this gap:
//   "Quickshell currently only bundles interfaces for working with Hyprland and
//   i3, however you can implement your own using Socket or Process." So:
//   `gdbus`, which ships with glib2 and is on every machine that has D-Bus at
//   all, driven by Quickshell's Process type.
//
//   The alternative considered and NOT taken was Qt's own
//   `Application.styleHints.colorScheme` (real, Qt 6.5+, reachable from QML).
//   It was rejected for one reason: whether Qt is reading the portal at all
//   depends on which platform-theme plugin Qt picked, and under a bare niri or
//   labwc session that is not something we control or can check from here.
//   Asking the portal ourselves has no such ambiguity. If the bench run shows
//   styleHints works reliably, this file gets shorter — and that is a good
//   trade to make with evidence, not without it.
//
// WHAT HAPPENS WHEN THERE IS NO PORTAL
//   Nothing bad, and this is the point. `available` stays false, `Theme.dark`
//   falls back to its stored default, and the shell is Ice — which is what
//   AquariusOS is meant to look like anyway. A missing portal must never be a
//   black bar or a crash. Every failure path in this file ends in one printed
//   sentence and the stored default.
//
// OWNERSHIP
//   This file owns the question "what does the system prefer". It does not own
//   the answer "which palette is in force" — that is Theme.qml's job, because
//   Theme.qml is also where a future manual override in Settings would live.
//
//   It DOES own telling the two things outside QML that cannot follow a QML
//   binding: the window frames, which belong to labwc, and the wallpaper, which
//   belongs to swaybg. Both are the same shape — a program named by an
//   environment variable, run fire-and-forget, doing nothing at all when the
//   variable is unset — and both are written out at length further down.
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // =========================================================================
    // WHAT THE SYSTEM SAYS
    // =========================================================================
    // The three values the standard defines. Named, so that no other file in
    // this repo has to remember that 1 means dark and 2 means light — which is
    // the wrong way round from what everybody guesses.
    readonly property int noPreference: 0
    readonly property int preferDark: 1
    readonly property int preferLight: 2

    // The raw value last heard from the portal.
    property int colorScheme: root.noPreference

    // True once the portal has actually answered. False in the nested harness,
    // on a machine with no portal installed, and for the first fraction of a
    // second of every run.
    property bool available: false

    // A short human-readable line for logs and for a future "why is my theme
    // not following the system" panel. Never shown as-is in the UI.
    property string status: "asking the portal"

    // --- what the rest of the shell actually reads ---------------------------
    // `hasPreference` is deliberately false when the portal said "no
    // preference": that is the system declining to answer, not the system
    // asking for light, and the difference matters. When the system declines,
    // AquariusOS's own decision wins — and that decision is Ice.
    readonly property bool hasPreference: root.available
                                          && root.colorScheme !== root.noPreference
    readonly property bool prefersDark: root.colorScheme === root.preferDark
    readonly property bool prefersLight: root.colorScheme === root.preferLight

    // =========================================================================
    // READING THE VALUE
    // =========================================================================
    // Two spellings of the same question, because the portal grew a better one:
    //
    //   ReadOne  the current method. Returns the value inside ONE variant.
    //   Read     the older method, kept for compatibility and marked deprecated
    //            upstream. Returns the value inside TWO variants, which is the
    //            bug that caused ReadOne to exist.
    //
    // Older machines only have Read. Rather than guess, we ask with ReadOne and
    // fall back once. The reply is parsed with a regular expression that copes
    // with either amount of wrapping, so the difference never reaches anything
    // else in this file.
    readonly property string portalService: "org.freedesktop.portal.Desktop"
    readonly property string portalObject: "/org/freedesktop/portal/desktop"
    readonly property string portalInterface: "org.freedesktop.portal.Settings"
    readonly property string appearanceNamespace: "org.freedesktop.appearance"
    readonly property string colorSchemeKey: "color-scheme"

    property bool triedLegacyRead: false

    function readCommand(method) {
        return [
            "gdbus", "call", "--session",
            "--dest", root.portalService,
            "--object-path", root.portalObject,
            "--method", root.portalInterface + "." + method,
            root.appearanceNamespace,
            root.colorSchemeKey
        ];
    }

    // Pull the number out of a gdbus reply. gdbus prints GVariant text, so
    // ReadOne gives `(<uint32 1>,)` and the deprecated Read gives
    // `(<<uint32 1>>,)`. One pattern reads both.
    function parseScheme(text) {
        const match = /uint32\s+(\d+)/.exec(text);
        if (match === null)
            return -1;

        const value = parseInt(match[1], 10);
        // The standard says unknown values are to be treated as "no
        // preference". Obeying that is what keeps a future fourth value from
        // turning the desktop an unexpected colour.
        if (value !== root.preferDark && value !== root.preferLight)
            return root.noPreference;

        return value;
    }

    function acceptScheme(value, source) {
        const changed = root.colorScheme !== value || !root.available;

        // ⚠️ A FLIP IS NOT THE SAME AS THE FIRST ANSWER, and two things below
        //   need to tell them apart. `changed` is true the very first time the
        //   portal speaks, because until then we had nothing. `flipped` is true
        //   only when we already had an answer and it is now a different one —
        //   which is what a person means by "I flipped it to dark".
        const flipped = root.available && root.colorScheme !== value;

        root.colorScheme = value;
        root.available = true;
        root.status = "following the system (" + source + ")";

        // The shell repaints itself from the new palette on its own — every
        // component is bound to Theme, and Theme is bound to this. The WINDOW
        // FRAMES are the part that does not, and that is what the line below is
        // for. See the long note beside frameProc.
        if (changed)
            root.rebuildWindowFrames();

        // And neither is the WALLPAPER. See the long note beside
        // wallpaperProc — including why this one is `flipped` and the line
        // above it is `changed`.
        if (flipped)
            root.followWallpaper();
    }

    // =========================================================================
    // WHICH LOOK IS ON, AS ONE WORD
    // =========================================================================
    // "ice" or "midnight" — the two names the palettes have (theme/Ice.qml,
    // theme/Midnight.qml) and the same two words `generate-theme --scheme`
    // takes. One vocabulary, so that nothing outside QML has to be told twice.
    //
    // ⚠️ IT FOLLOWS THE PORTAL, NOT Theme.dark, and that is deliberate and
    //   worth understanding. `Theme.dark` is a writable property: assigning to
    //   it (from a future Settings panel) breaks the binding and pins the
    //   theme by hand. Everything outside QML that has to follow the look —
    //   the window frames, and now the wallpaper — asks the SYSTEM instead,
    //   because that is what generate-theme already does when it runs at login
    //   with no shell to ask (`ask_the_portal()` in session/labwc/generate-
    //   theme). Two answers to one question would be worse than one answer
    //   that is occasionally overridden.
    //
    //   The honest consequence: the day a Settings panel can pin the theme by
    //   hand, the frames and the wallpaper will follow the system and the shell
    //   will not, and all three have to be changed together. Written here
    //   because that is the day somebody will be looking at this line.
    readonly property string schemeName:
        (root.available && root.prefersDark) ? "midnight" : "ice"

    // =========================================================================
    // THE WINDOW FRAMES, WHICH THE SHELL DOES NOT DRAW
    // =========================================================================
    // Four things on an Aquarius screen belong to labwc and not to us: the
    // title bar of every window, the border around it, the round buttons in
    // that title bar, and the menu that opens on a right-click of the
    // wallpaper. labwc is a C program reading flat text files and cannot follow
    // a QML binding, so when this file decides the machine has gone dark, those
    // four surfaces would stay light. On the bench that reads as the shell
    // turning navy while every window title bar stays ice white.
    //
    // The fix is two steps and they have to happen in this order:
    //
    //   1. session/labwc/generate-theme reads theme/Midnight.qml (or Ice.qml)
    //      and writes labwc's files out again — the colours, the sizes and the
    //      button pictures.
    //   2. `labwc --reconfigure`, which is labwc's own "re-read your files now"
    //      command. generate-theme runs it itself, at the end, which is why
    //      --reconfigure is passed below rather than run as a second process
    //      from here: one program owning both halves means they cannot get out
    //      of order.
    //
    // --quiet because this is the second and later runs; the noisy first run
    // happens at login, from the session launcher, where somebody reading
    // session.log wants to see it.
    //
    // IF IT FAILS, THE DESKTOP IS FINE. The window frames simply keep the theme
    // they had until the next login. A cosmetic step must never be able to take
    // the desktop down, so this is a fire-and-forget process with its failure
    // written to the log and nothing else.
    // The full path to generate-theme, handed to us by whichever launcher
    // started the session. It is a variable rather than a path written here for
    // the same reason no other path is written in this repository: the file
    // lives in a different place on an installed AquariusOS machine than it
    // does in a clone of this repository, and the shell should not have to know
    // which one it is running on.
    //
    // Unset means "not an Aquarius session" — the nested harness, or somebody
    // running the shell on their own desktop — where there are no Aquarius
    // window frames to rebuild and this whole section does nothing.
    readonly property string frameGenerator: Quickshell.env("AQ_FRAME_GENERATOR") || ""

    function rebuildWindowFrames() {
        if (root.frameGenerator === "")
            return;

        frameProc.running = false;
        frameProc.running = true;
    }

    Process {
        id: frameProc
        running: false
        command: ["python3", root.frameGenerator, "--quiet", "--reconfigure"]

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.info("aquarius-shell: window frames — "
                                + this.text.trim());
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0)
                console.info("aquarius-shell: window frames — could not rebuild "
                            + "them (exit " + exitCode + "). The title bars keep "
                            + "the theme they had until the next login.");
        }
    }

    // =========================================================================
    // THE WALLPAPER, WHICH THE SHELL DOES NOT DRAW EITHER
    // =========================================================================
    // WHAT WAS WRONG. Flip the machine to dark and the bar, the dock and the
    // menus all go navy — and the picture behind them stays the pale Ice Pour.
    // Both pictures ship; only one was ever shown. Bench, 2026-09-07 and again
    // 2026-09-08, where it is the most likely thing behind "the flip to dark
    // didn't carry over".
    //
    // WHY THE SHELL CANNOT JUST DRAW IT. The wallpaper is put up by `swaybg`,
    // started once by the session at login. That is a good decision and it is
    // not changing: a wallpaper drawn by a separate program survives the shell
    // crashing, so a bad night's work on the bar can never leave somebody
    // staring at a black screen. The cost is that nothing re-runs it.
    //
    // SO THE SESSION OWNS THE PICTURE AND THE SHELL OWNS THE NEWS. This is the
    // second half of a contract whose first half lives in the os-image
    // repository, and the whole of it is written out in plain language in
    // docs/session.md:
    //
    //   the session ships   /usr/libexec/aquarius-wallpaper <ice|midnight|auto>
    //                       — it stops the swaybg it started before and starts
    //                         a new one with the right picture
    //   autostart calls it  with `auto` at login, so the picture is already
    //                       right for the theme the machine is in
    //   the shell calls it  here, with one word, every time the theme FLIPS
    //
    // ⚠️ WHY THIS RUNS ON A FLIP AND THE WINDOW FRAMES RUN ON THE FIRST ANSWER
    //   TOO. Because the session has already put the right picture up by the
    //   time the shell starts — `autostart` runs the setter before it runs
    //   `qs`. Calling it again a second later would restart swaybg for no
    //   reason, and a swaybg restart is VISIBLE: the desktop blinks. The window
    //   frames have no such flash, and generate-theme at login is cheap, so
    //   that one stays as it was.
    //
    // IF IT FAILS, THE DESKTOP IS FINE. The picture simply stays as it was
    // until the next login. A cosmetic step must never be able to take the
    // desktop down, so this is fire-and-forget with one sentence in the log
    // and nothing else — the same shape, and the same rule, as the frames.
    //
    // Unset means "not an Aquarius session" — the nested harness, somebody
    // running the shell on their own desktop, or an image whose session half of
    // this contract has not landed yet. Then NOTHING happens, which is exactly
    // right: there is no Aquarius wallpaper to swap, and calling a program that
    // is not there would be a failure logged on every flip for ever.
    readonly property string wallpaperSetter: Quickshell.env("AQ_WALLPAPER_SETTER") || ""

    function followWallpaper() {
        if (root.wallpaperSetter === "")
            return;

        // The command is assigned rather than bound because the word in it
        // changes with the theme, and a binding that updates a property of a
        // process while that process is running is a question nobody should
        // have to answer. Set it, then start it.
        wallpaperProc.running = false;
        wallpaperProc.command = [root.wallpaperSetter, root.schemeName];
        wallpaperProc.running = true;
    }

    Process {
        id: wallpaperProc
        running: false
        command: []

        // Kept only so that a failure can say what the program complained
        // about. On an ordinary run it is empty: the setter writes its own
        // sentence into the session log.
        stderr: StdioCollector { }

        onExited: function (exitCode) {
            if (exitCode === 0)
                return;

            const said = wallpaperProc.stderr.text.trim();
            console.info("aquarius-shell: wallpaper — could not swap it (exit "
                         + exitCode + ")"
                         + (said === "" ? "" : ": " + said)
                         + ". The picture keeps the theme it had until the next "
                         + "login.");
        }
    }

    function giveUp(reason) {
        root.available = false;
        root.status = reason;
        console.info("aquarius-shell: appearance — " + reason
                    + "; staying on the stored theme default (Ice).");
    }

    Process {
        id: readProc

        // Started by the Timer below rather than here, so that the very first
        // read and every retry go through exactly one code path.
        command: root.readCommand("ReadOne")

        stdout: StdioCollector {
            onStreamFinished: {
                const value = root.parseScheme(this.text);
                if (value >= 0) {
                    root.acceptScheme(value, "portal");
                    monitorProc.running = true;
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.info("aquarius-shell: appearance — gdbus said: "
                                + this.text.trim());
            }
        }

        onExited: function (exitCode, exitStatus) {
            if (root.available)
                return;

            // Try the older method exactly once before concluding there is no
            // portal here.
            if (!root.triedLegacyRead) {
                root.triedLegacyRead = true;
                readProc.command = root.readCommand("Read");
                readProc.running = true;
                return;
            }

            root.giveUp("no appearance portal answered (gdbus exit "
                        + exitCode + ")");
        }
    }

    // =========================================================================
    // NOTICING WHEN IT CHANGES
    // =========================================================================
    // `gdbus monitor` prints one line per signal. The line we care about looks
    // like this, all on one line:
    //
    //   /org/freedesktop/portal/desktop: org.freedesktop.portal.Settings.
    //   SettingChanged ('org.freedesktop.appearance', 'color-scheme', <uint32 1>)
    //
    // SplitParser hands us one line at a time as they arrive, which is what
    // Quickshell's own FAQ recommends for a long-running process that streams.
    // Everything that is not this exact signal is ignored — the same monitor
    // also carries font and accent-colour changes we have no use for yet.
    Process {
        id: monitorProc

        // Started only after a successful read. Watching for changes to a
        // setting that was never there in the first place is noise.
        running: false

        command: [
            "gdbus", "monitor", "--session",
            "--dest", root.portalService,
            "--object-path", root.portalObject
        ]

        stdout: SplitParser {
            onRead: function (line) {
                if (line.indexOf("SettingChanged") < 0)
                    return;
                if (line.indexOf(root.appearanceNamespace) < 0)
                    return;
                if (line.indexOf(root.colorSchemeKey) < 0)
                    return;

                const value = root.parseScheme(line);
                if (value >= 0)
                    root.acceptScheme(value, "portal, live");
            }
        }

        onExited: {
            // The monitor died. The value we already have is still the best one
            // we know, so keep it and keep `available` true — the desktop
            // simply stops noticing further changes until the next reload.
            // Restarting in a loop here would be a way to spin a CPU core
            // forever on a machine where gdbus is broken.
            console.info("aquarius-shell: appearance — stopped watching for "
                        + "changes. The current light/dark setting is kept.");
        }
    }

    // =========================================================================
    // STARTING, AND KNOWING WHEN TO STOP WAITING
    // =========================================================================
    // A process that cannot start at all (no gdbus on the machine) does not
    // always announce itself the way a process that ran and failed does. So
    // rather than trust one signal, there is a deadline: if nothing has
    // answered by the time this fires, we say so once, in plain words, and move
    // on with the stored default.
    Timer {
        id: deadline
        interval: 4000
        repeat: false
        onTriggered: {
            if (!root.available)
                root.giveUp("the appearance portal did not answer in time "
                            + "(is xdg-desktop-portal running?)");
        }
    }

    Component.onCompleted: {
        readProc.running = true;
        deadline.running = true;
    }
}
