// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// MountTable — what kind of filesystem is mounted where
// =============================================================================
// WHAT IT IS FOR
//   One question, asked in one place: "the drive mounted at /run/media/royce/X
//   — what sort of drive is it?". The dock's right-click menu needs the answer
//   because a MAC (APFS) drive and every other drive are put away differently:
//
//     an ordinary drive   udisks2 mounted it. Unmount closes its files and
//                         leaves it in Files with a re-mount icon; Eject also
//                         powers it off so the cable can come out. TWO menu
//                         items, because they are two different things.
//     a Mac drive         apfs-fuse mounted it, in your own session, and there
//                         is no udisks2 drive behind it to power off. Closing
//                         it IS putting it away, so the menu offers ONE item —
//                         Eject — rather than the same action under two names.
//
// WHERE THE ANSWER COMES FROM
//   /proc/self/mounts, which is the kernel's own list of what is mounted right
//   now. It is a plain text file, one mount per line:
//
//       /dev/sdb1 /run/media/royce/FIELD\040SSD exfat rw,nosuid,... 0 0
//       └ device  └ where it is                 └ what kind
//
//   A space in a drive's name is written `\040`, which is undone below. This is
//   the same file, read the same way, that `aq drive list` reads (it uses the
//   mountinfo cousin of it) — so the terminal and the dock cannot disagree about
//   what a drive is.
//
// ⚠️ WHY NOT ASK udisks2 DIRECTLY
//   The shipped Quickshell has no UDisks2 or GIO binding (the long version is in
//   the header of components/dock/DockDrives.qml), and this shell does not
//   hand-roll D-Bus clients. Reading a text file the kernel maintains is the
//   plainest standard route there is, and it needs no permission at all.
//
// ⚠️ IT IS READ, NEVER WATCHED
//   /proc files do not tell anybody when they change, so there is no point
//   watching this one. It is re-read on demand instead: a drive tile asks for a
//   refresh when it appears, and again after it has been unmounted. That is
//   exactly when the answer can have changed.
//
// IF THE READ FAILS the table is simply empty and `fsTypeFor()` returns "". Every
// caller is written so that an empty answer means "an ordinary drive", which is
// the common case and the safe one: the worst that happens is that a Mac drive
// is offered an Unmount item as well as Eject, and both of them close it.
//
// NOT PROVEN ON HARDWARE.
// =============================================================================
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // mount point -> filesystem type, e.g. { "/run/media/royce/FIELD SSD": "exfat" }
    property var byPath: ({})

    // The filesystem type at a mount point, or "" if we do not know.
    function fsTypeFor(path: string): string {
        const found = root.byPath[path];
        return found === undefined ? "" : found;
    }

    // True for a Mac drive — an APFS volume opened by apfs-fuse. The type is
    // reported as `fuse.apfs` by the fuse build Fedora ships, and older or
    // differently-built ones say `fuse.apfs-fuse`, so the test is on the front
    // of the string rather than on one exact spelling.
    function isMacDrive(path: string): bool {
        return root.fsTypeFor(path).indexOf("fuse.apfs") === 0;
    }

    // Read the file again. Cheap — it is a few hundred bytes the kernel makes
    // up on the spot — and only called when something has just changed.
    function refresh(): void {
        mounts.reload();
    }

    // ---- the parser ----------------------------------------------------------
    // Field 1 is the device, field 2 is the mount point, field 3 is the type.
    // Anything after that is options, which nothing here wants. A line with
    // fewer than three fields is not a mount line and is skipped rather than
    // guessed at.
    function parse(text: string): var {
        const table = {};
        const lines = (text || "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].split(" ");
            if (fields.length < 3)
                continue;
            // `\040` is how the kernel writes a space, and `\011` a tab. Undone
            // in that order because the backslashes are literal characters here,
            // not escapes the QML engine has already dealt with.
            const where = fields[1].split("\\040").join(" ").split("\\011").join("\t");
            table[where] = fields[2];
        }
        return table;
    }

    FileView {
        id: mounts

        path: "/proc/self/mounts"

        // Nothing watches a /proc file; see the note above.
        watchChanges: false

        // A read that fails here costs one menu item's wording, not a feature.
        // Printing an error for it would be louder than the problem.
        printErrors: false

        onLoaded: root.byPath = root.parse(mounts.text())
        onLoadFailed: root.byPath = ({})
    }
}
