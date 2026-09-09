// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// ThemeStatus — "what does the shell actually believe about light and dark?"
// =============================================================================
// WHY THIS EXISTS
//
//   On the bench on 2026-09-08 the report was: "the flip to dark didn't carry
//   over to the lock screen". Every link in the chain looked right on paper —
//   the portal said dark, the shell's watcher was alive, the veil is bound to
//   the theme — and there was no way to ask the running shell what it thought.
//   So an afternoon went on reasoning about code instead of one command.
//
//   This is that command:
//
//       qs ipc call theme status
//
//   It prints, in plain words, the four things that decide what colour the
//   desktop and the lock screen are:
//
//       system     what the appearance portal last said, and how we heard it
//       theme      Ice or Midnight, and WHY — following the system, or the
//                  stored default because nothing answered
//       wallpaper  the picture the lock screen would draw right now
//       frames     whether this session has a window-frame generator to run
//                  when the theme flips (unset in the harness; set by the
//                  Aquarius session)
//
//   If the desktop is dark and this says Midnight, the shell is right and the
//   fault is somewhere else — the wallpaper on the desktop (which is swaybg's,
//   started once at login: see docs/session.md), or the window frames, or the
//   picture on disk. If it says Ice while the system says dark, the fault is
//   here and the line tells you which link broke.
//
// IT ONLY READS. There is deliberately no `qs ipc call theme dark` to force a
// theme by hand: a debug lever that changes what the desktop looks like is a
// setting, and a setting belongs in Settings, with a person's name on the
// decision. Read the note beside `dark` in theme/Theme.qml.
//
// WHY IT IS NOT A SINGLETON. An IpcHandler has to be part of the scene to be
// registered at all, and a singleton is built the first time somebody asks for
// it — which for a file nothing else imports is never. So this is an ordinary
// type, named once in shell.qml.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Io

// "." is this folder — SystemAppearance lives beside this file. Named
// explicitly rather than relied on: a folder with a qmldir shows the outside
// world only what the qmldir lists, and being explicit is what makes that
// visible to somebody reading one file.
import "."
import "../theme"

Scope {
    id: root

    IpcHandler {
        target: "theme"

        // Everything the shell believes about light and dark, in one block of
        // text. Written as sentences rather than as a machine format on
        // purpose: the reader is a person at a bench with a terminal, and the
        // next thing they do is paste it into a bench note.
        function status(): string {
            const lines = [];

            lines.push("system     : " + SystemAppearance.status);
            lines.push("             portal answered: "
                       + (SystemAppearance.available ? "yes" : "no")
                       + "; value: " + SystemAppearance.colorScheme
                       + " (0 no preference, 1 dark, 2 light)");

            lines.push("theme      : " + (Theme.dark ? "Midnight (dark)" : "Ice (light)"));
            lines.push("             because: "
                       + (SystemAppearance.hasPreference
                          ? "the system asked for it"
                          : "nothing answered, so the stored default stands ("
                            + (Theme.storedDark ? "Midnight" : "Ice") + ")"));

            lines.push("wallpaper  : " + Theme.wallpaper);
            lines.push("             (this is the picture the LOCK screen draws."
                       + " The desktop's own wallpaper belongs to swaybg and is"
                       + " started once at login — docs/session.md.)");

            lines.push("frames     : "
                       + (SystemAppearance.frameGenerator === ""
                          ? "no generator in this session (harness, or not "
                            + "an Aquarius session) — window frames do not follow"
                          : SystemAppearance.frameGenerator));

            // The desktop's own picture, which belongs to swaybg and not to us.
            // If this says there is no setter, a dark machine keeps a light
            // desktop and the shell is not at fault — read docs/session.md.
            lines.push("desktop    : "
                       + (SystemAppearance.wallpaperSetter === ""
                          ? "no wallpaper setter in this session — the desktop "
                            + "picture does not follow the theme"
                          : SystemAppearance.wallpaperSetter + " "
                            + SystemAppearance.schemeName));

            return lines.join("\n");
        }

        // The one-word answer, for a script that wants to branch on it.
        function dark(): bool {
            return Theme.dark;
        }
    }
}
