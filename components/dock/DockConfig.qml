// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// DockConfig — which apps are pinned to the dock, and where that list lives
// =============================================================================
// THE FILE
//
//     ~/.config/aquarius-shell/dock.json
//
//     {
//       "pinned": [
//         "org.gnome.Nautilus.desktop",
//         "org.mozilla.firefox.desktop",
//         "steam.desktop",
//         "aquarius-editor.desktop",
//         "aquarius-writer.desktop",
//         "org.gnome.Settings.desktop"
//       ]
//     }
//
// One key, "pinned", holding a list of desktop-entry names in the order they
// should appear. A name may be written with or without the ".desktop" ending;
// both are accepted, because the ".desktop" form is what a person will have
// seen everywhere else and it would be unkind to reject it.
//
// A name that does not match an installed application is simply not drawn. That
// is deliberate and it is the same rule the KDE dock followed: a typo, or an app
// you have not installed on this machine, costs you a slot and nothing else.
//
// WE READ THIS FILE, AND SINCE 2026-09-06 WE ALSO WRITE IT — BUT ONLY WHEN ASKED
//   Until that day this was read-only, because there was no gesture in the shell
//   that could change what is pinned. Right-clicking an app in the dock now
//   offers "Keep in Dock" / "Remove from Dock" (components/dock/DockItem.qml), so
//   there is finally something to save, and pin() / unpin() below are it.
//
//   NOTHING IS EVER WRITTEN UNPROMPTED. The shell still does not create this file
//   at start-up, still does not write a default copy, and still does nothing at
//   all if the file is absent — the defaults below simply stand. A file appears
//   only because somebody clicked a menu item, which is the one case where a
//   shell writing a file is not a surprise. That was the reasoning for the old
//   read-only rule and it survives this change intact.
//
//   `docs/dock.md` has the one command that creates the file with the defaults
//   in it, for somebody who would rather start by editing it by hand.
//
// HOW THE WRITE WORKS, AND WHY IT IS writeAdapter() AND NOT setText()
//   The header used to say "FileView.setText(), or a JsonAdapter write via
//   writeAdapter()". It is the second one. The adapter already holds the list in
//   the exact shape the file wants, so the whole write is: change the adapter's
//   property, call writeAdapter(), and let it serialise. setText() would mean
//   this file building JSON by hand — a second opinion about what the format is,
//   living three lines away from the first one.
//
//   The change is visible IMMEDIATELY, before the file is written, because
//   `pinned` below is a binding onto the adapter's property: the dock re-lays
//   itself out the moment the list changes and does not wait for a disk write to
//   come back. The write then lands, `watchChanges` notices the file it just
//   wrote, `reload()` reads it, and the adapter ends up holding what is on disk.
//   That round trip is redundant and harmless, and it is the thing that keeps
//   this working when the file is ALSO edited by hand in a text editor.
//
//   The list is REASSIGNED, never pushed onto. Changing the array in place would
//   change it without QML's property system noticing, so the dock would not
//   redraw until something unrelated happened to touch the binding. And each new
//   list is built with a plain loop into a plain array rather than with concat()
//   or filter(): what comes back out of a `list<string>` property is a sequence
//   wrapper, not necessarily a JavaScript Array, and a loop needs nothing of it
//   beyond `length` and an index — which is all DockModel asks of it too.
//
// ⚠️ THE PARENT DIRECTORY, WHICH IS THE ONE THING THAT CAN GO WRONG
//   FileView writes a file. It does not create the folder above it, and
//   ~/.config/aquarius-shell/ does not exist on a machine where nobody has ever
//   edited this by hand — which is every fresh install. So the first pin on a
//   fresh machine fails, and it fails silently unless something is watching.
//
//   onSaveFailed is what watches: it runs `mkdir -p` on the folder ONCE and
//   retries the write. Not before the first attempt — a shell that spawns a
//   process at start-up on the off-chance is the very thing the no-unprompted-
//   writes rule was written against — and not twice, because a second failure is
//   a real problem (a read-only home directory, a full disk) and retrying for
//   ever would hide it.
//
//   This is the only place in the dock that runs a program, and it runs one
//   exactly once per session and only after a real failure. It goes out through
//   execDetached, like every other launch in the shell — not the Process-command
//   form tests/test-shell.sh section 22 guards, which is the same distinction
//   DockDrive.qml's header draws for `gio` and `xdg-open`.
//
// ⚠️ WHY THE ROOT IS A Scope AND NOT THE FileView ITSELF
//   It used to be the FileView. It cannot stay one, because this file now needs
//   a Timer (the pause between mkdir and the retry) and a FileView WILL NOT TAKE
//   ONE: its default property is `adapter`, of type FileViewAdapter, so any
//   child object declared inside it is offered to that property and a Timer is
//   refused outright — "Cannot assign object of type Timer". A Scope is
//   Quickshell's own do-nothing container for exactly this, and it is what
//   Dock.qml and LogoMenu.qml are already built out of.
//
//   Nothing outside this file notices: `pinned` is still read the same way, and
//   `path` and `configHome` are still here for anything that wants to say where
//   the file is.
//
// EDIT THE FILE AND THE DOCK CHANGES WHILE YOU WATCH
//   `watchChanges` + `reload()` is Quickshell's own documented pattern for this
//   (see the FileView docs). Save the JSON, the dock reorders. No restart.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/)
//
// WHY errors ARE SILENCED
//   `printErrors: false`. The overwhelmingly common case is that the file does
//   not exist, which is not an error — it is a fresh install. A shell that
//   prints a scary line every start for a normal state trains people to ignore
//   its output.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Io

Scope {
    id: root

    // The default pinned set. These SIX ARE NOT INVENTED — they are the exact
    // list, in the exact order, that the shipping OS puts in GNOME's dock:
    //   os-image/system_files/usr/share/glib-2.0/schemas/
    //       zz1-aquarius-20-shell.gschema.override   ->  favorite-apps
    // That file also records why each one earns a permanent seat. If the OS's
    // list changes, change this to match rather than inventing a second answer.
    readonly property list<string> defaultPinned: [
        "org.gnome.Nautilus.desktop",
        "org.mozilla.firefox.desktop",
        "steam.desktop",
        "aquarius-editor.desktop",
        "aquarius-writer.desktop",
        "org.gnome.Settings.desktop"
    ]

    // What the rest of the dock reads. The adapter holds the defaults until a
    // file is loaded, so this is never empty and never undefined.
    readonly property var pinned: adapter.pinned

    // Where the file lives, worked out the way the freedesktop base-directory
    // specification says to: $XDG_CONFIG_HOME if it is set, otherwise
    // ~/.config. `Quickshell.env` returns null for an unset variable.
    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (xdg)
            return xdg;
        const home = Quickshell.env("HOME");
        if (home)
            return home + "/.config";
        // No HOME at all. Nothing sane to read; an empty path unloads the file
        // and leaves the defaults in force, which is the right outcome.
        return "";
    }

    // The folder the file sits in — named separately because it is the thing
    // that has to be created before a first write can succeed.
    readonly property string configDir: root.configHome === ""
        ? "" : root.configHome + "/aquarius-shell"

    readonly property string path: root.configDir === ""
        ? "" : root.configDir + "/dock.json"

    // ---- comparing two spellings of the same app -----------------------------
    // "org.gnome.Nautilus.desktop", "org.gnome.Nautilus" and "ORG.GNOME.NAUTILUS"
    // are one application written three ways, and all three turn up: the file
    // accepts either ending, and a desktop entry's own id never carries one.
    // This is the form they are compared in.
    //
    // DockModel.qml has the same function, for the same reason, and the two must
    // agree — a name this file thinks is pinned and that file thinks is not
    // would put a menu item in front of somebody that does nothing. They are
    // eight lines each and neither imports the other; if a third copy ever
    // appears, that is the moment to give it a home of its own.
    function normaliseId(id: string): string {
        if (!id)
            return "";
        let text = String(id);
        if (text.toLowerCase().endsWith(".desktop"))
            text = text.slice(0, -8);
        return text.toLowerCase();
    }

    // Is this app in the pinned list, whichever way its name is spelled?
    function isPinned(id: string): bool {
        const wanted = root.normaliseId(id);
        if (wanted === "")
            return false;

        const list = root.pinned;
        for (let i = 0; i < list.length; i++) {
            if (root.normaliseId(list[i]) === wanted)
                return true;
        }
        return false;
    }

    // ---- changing the list ---------------------------------------------------
    // Add to the END, which is where a dock is expected to put a newly kept app:
    // the tile the person just right-clicked was already there (an unpinned
    // running app is drawn after every pinned one — see DockModel), so keeping
    // it means the tile does not jump out from under the pointer.
    //
    // The name is written WITH the ".desktop" ending, because that is how every
    // name in the default list and in the documented example file is written,
    // and a file that a person opens should look like the one the documentation
    // showed them. The reader accepts either.
    function pin(id: string): void {
        const wanted = root.normaliseId(id);
        if (wanted === "" || root.isPinned(id))
            return;

        let text = String(id);
        if (!text.toLowerCase().endsWith(".desktop"))
            text = text + ".desktop";

        const out = [];
        const list = root.pinned;
        for (let i = 0; i < list.length; i++)
            out.push(String(list[i]));
        out.push(text);

        adapter.pinned = out;
        root.save();
    }

    // Remove every spelling of this app, not the first one found: a file that
    // has been hand-edited can perfectly well contain both "steam" and
    // "steam.desktop", and removing one of them leaves the tile exactly where it
    // was, which reads as "the menu item did nothing".
    function unpin(id: string): void {
        const wanted = root.normaliseId(id);
        if (wanted === "")
            return;

        const out = [];
        const list = root.pinned;
        for (let i = 0; i < list.length; i++) {
            if (root.normaliseId(list[i]) !== wanted)
                out.push(String(list[i]));
        }

        if (out.length === list.length)
            return;

        adapter.pinned = out;
        root.save();
    }

    // ---- getting it onto disk ------------------------------------------------
    // Whether the folder above the file has already been created this session.
    // See the header: the first failure creates it and retries, and a second
    // failure is left alone to be a real error rather than an infinite retry.
    property bool triedCreatingFolder: false

    function save(): void {
        if (root.path === "")
            return;
        file.writeAdapter();
    }

    FileView {
        id: file

        path: root.path

        watchChanges: true
        onFileChanged: file.reload()

        printErrors: false

        onSaveFailed: {
            if (root.triedCreatingFolder || root.configDir === "") {
                // Already tried, or there is no home directory to try in. The
                // list in memory is still correct and the dock still shows it;
                // what is lost is that the change does not survive a restart.
                // Say so — silence here would be a pin that quietly forgets
                // itself, which is worse than one that fails out loud.
                console.warn("aquarius-shell: could not save", root.path,
                             "— pinned apps will not survive a restart");
                return;
            }

            root.triedCreatingFolder = true;

            // The overwhelmingly likely reason a first write fails: the folder
            // does not exist yet. `mkdir -p` creates it and is content when it
            // is already there, so this is safe even if the real problem was
            // something else — in which case the retry fails and the warning
            // above is what gets printed.
            Quickshell.execDetached(["mkdir", "-p", root.configDir]);

            retryAfterMkdir.restart();
        }

        // NOT blockLoading. The FileView docs allow a blocking read for exactly
        // this kind of file, but the dock does not need it: the adapter starts
        // holding the defaults, and swaps to the file's list the moment it
        // lands. The worst case is the default six being visible for a few
        // milliseconds on a machine whose pinned list is different, which is a
        // far better trade than a shell that freezes on slow storage.

        JsonAdapter {
            id: adapter

            // The one key in the file. `list<string>` is a type JsonAdapter
            // supports directly, so the JSON array arrives already parsed.
            property list<string> pinned: root.defaultPinned
        }
    }

    // The pause between creating the folder and trying the write again. A
    // detached process gives nothing to wait on, so this is a wait rather than a
    // handshake — and if it is ever not long enough, the retry fails, the
    // warning above is printed, and the NEXT pin succeeds, because by then the
    // folder certainly exists.
    Timer {
        id: retryAfterMkdir
        interval: 200
        repeat: false
        onTriggered: file.writeAdapter()
    }
}
