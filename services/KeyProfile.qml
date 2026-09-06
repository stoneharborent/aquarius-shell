// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// KeyProfile — is this machine set up like a Mac, or like a PC?
// =============================================================================
// WHAT THIS IS
//
//   AquariusOS asks one question at first login: "Mac or Windows?". The answer
//   is a keyboard style. On Mac, Copy is Command-C; on Windows, Copy is
//   Control-C. A person can change their mind at any time by running:
//
//       aq keys mac
//       aq keys windows
//
//   That command writes the answer into ONE file:
//
//       ~/.config/aquarius/keys.conf
//
//   whose entire contents are comments and a single line:
//
//       mode=mac        (or)      mode=windows
//
//   This file reads that line and nothing else. It is the shell's only opinion
//   about which of the two styles is switched on.
//
// WHY THE SHELL NEEDS TO KNOW
//
//   Because the app switcher behaves differently in the two styles, and that
//   was a deliberate design decision rather than a shortcut:
//
//     Mac style      Command-Tab switches between APPLICATIONS. Five windows of
//                    one editor are one tile. That is what a Mac does.
//     Windows style  Alt-Tab switches between WINDOWS. Five windows of one
//                    editor are five entries. That is what Windows does.
//
//   Nothing else in the shell reads it yet. It is a singleton anyway, because
//   the moment a second component wants the answer there must not be a second
//   place that works it out. (Same reasoning as services/FocusState.qml.)
//
// ⚠️ THIS FILE NEVER WRITES. NOT EVER.
//
//   `aq keys` owns this file, start to finish: it writes the mode, it restarts
//   the remapper, and it prints what happened. Two programs writing one
//   settings file is two programs that can disagree about what the setting is,
//   and the os-image repository already refuses that for the welcome screen
//   (build_files/67-welcome.sh fails the build if the welcome learns the
//   keys.conf format). The same rule applies here: the shell READS, `aq` WRITES.
//
// LIVE, NOT AT START-UP
//
//   `watchChanges: true` plus `reload()` on change is Quickshell's own
//   documented pattern, and it is the pattern components/dock/DockConfig.qml
//   already uses for the pinned-apps file. Run `aq keys windows` with the
//   switcher open and the next Tab lists windows instead of apps — no logout,
//   no restart.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/)
//
// WHAT HAPPENS WHEN THE FILE IS NOT THERE
//
//   Mac. That is not a guess: `aq keys status`, the run script
//   (/usr/libexec/aquarius-keys-run) and /etc/skel/.config/aquarius/keys.conf
//   all say a missing or unreadable file means Mac mode, and a fresh account is
//   given `mode=mac` on purpose. A shell that disagreed with the rest of the
//   system about the default would be the worst kind of bug — one where two
//   halves of the desktop are each behaving correctly.
//
// NOT PROVEN ON HARDWARE. Checked statically (tests/test-shell.sh section 38).
// =============================================================================
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- the answer ----------------------------------------------------------
    // One boolean, because there are exactly two styles and there is not going
    // to be a third. Everything else in this file exists to work it out.
    readonly property bool mac: root.mode !== "windows"

    // The raw word out of the file: "mac", "windows", or "" while nothing has
    // been read yet. Exposed for `aq`-style debugging and for the tests; the
    // components use `mac` above.
    property string mode: ""

    // ---- where the file lives ------------------------------------------------
    // The freedesktop base-directory rule, spelled the same way DockConfig.qml
    // spells it: $XDG_CONFIG_HOME if it is set, otherwise ~/.config.
    // `Quickshell.env` returns null for a variable that is not set.
    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (xdg)
            return xdg;
        const home = Quickshell.env("HOME");
        if (home)
            return home + "/.config";
        // No HOME at all — nothing to read. An empty path unloads the FileView,
        // `mode` stays "", and `mac` stays true, which is the documented
        // default. Exactly the right outcome, and no special case needed.
        return "";
    }

    // ⚠️ THE FOLDER IS `aquarius`, NOT `aquarius-shell`.
    //   DockConfig.qml reads ~/.config/aquarius-shell/dock.json, which is the
    //   SHELL's own folder. This file is not a shell setting — it is the
    //   system-wide keyboard style, owned by `aq`, and `aq` puts it in
    //   ~/.config/aquarius. One letter apart, two different folders, and
    //   reading the wrong one would silently give Mac mode forever.
    readonly property string path: root.configHome === ""
        ? "" : root.configHome + "/aquarius/keys.conf"

    // ---- reading the line ----------------------------------------------------
    // The file is a plain text file with comments, not JSON, so there is no
    // adapter to hand it to — it is parsed here.
    //
    // The shape this accepts is the shape `aq` writes and the shape the run
    // script accepts, which is deliberately forgiving: spaces are allowed
    // around the `=`, a line starting with `#` is a comment, and if somebody
    // has hand-edited the file into having two `mode=` lines then the LAST one
    // wins. That last rule is not arbitrary — it is what `aq keys status` does
    // (`sed ... | tail -n 1`), and the two must agree or the status command and
    // the desktop would tell a person different things about the same file.
    function parseMode(text: string): string {
        if (!text)
            return "";

        let found = "";
        const lines = String(text).split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line === "" || line.startsWith("#"))
                continue;

            const parts = line.split("=");
            if (parts.length < 2)
                continue;
            if (parts[0].trim() !== "mode")
                continue;

            const value = parts[1].trim().toLowerCase();
            if (value === "mac" || value === "windows")
                found = value;
        }

        return found;
    }

    FileView {
        id: file

        path: root.path

        watchChanges: true
        onFileChanged: file.reload()

        // A missing file is the NORMAL case on a machine nobody has run
        // `aq keys` on, and it means Mac. Printing an error for the normal case
        // trains people to ignore the log.
        printErrors: false

        onLoaded: root.mode = root.parseMode(file.text())

        // The read failed — no file, no permission, no home directory. Say
        // nothing and fall back to Mac, which is what every other part of the
        // system does with the same file.
        onLoadFailed: root.mode = ""
    }
}
