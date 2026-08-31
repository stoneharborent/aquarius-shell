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
// WE READ THIS FILE. WE NEVER WRITE IT.
//   There is no pin/unpin gesture in the shell yet, so there is nothing for the
//   shell to save. Writing a default copy on first run was considered and
//   rejected: the folder would have to be created first, which means spawning a
//   process at start-up on the off-chance, and a shell that creates files you
//   did not ask for is a shell you cannot fully predict. If the file is absent
//   the defaults below are used and nothing is written anywhere.
//
//   `docs/dock.md` has the one command that creates the file with the defaults
//   in it, for somebody who wants to start editing.
//
//   When pin/unpin does arrive it belongs here: FileView.setText(), or a
//   JsonAdapter write via writeAdapter(). The reader is already the right shape
//   for it.
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
import Quickshell
import Quickshell.Io

FileView {
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

    path: root.configHome === ""
        ? ""
        : root.configHome + "/aquarius-shell/dock.json"

    watchChanges: true
    onFileChanged: root.reload()

    printErrors: false

    // NOT blockLoading. The FileView docs allow a blocking read for exactly this
    // kind of file, but the dock does not need it: the adapter starts holding
    // the defaults, and swaps to the file's list the moment it lands. The worst
    // case is the default six being visible for a few milliseconds on a machine
    // whose pinned list is different, which is a far better trade than a shell
    // that freezes on slow storage.

    JsonAdapter {
        id: adapter

        // The one key in the file. `list<string>` is a type JsonAdapter
        // supports directly, so the JSON array arrives already parsed.
        property list<string> pinned: root.defaultPinned
    }
}
