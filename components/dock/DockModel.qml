// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// DockModel — the list of tiles the dock draws, in order
// =============================================================================
// Two sources go in and one ordered list comes out:
//
//   pinnedIds   the names from ~/.config/aquarius-shell/dock.json (DockConfig)
//   toplevels   every window the compositor is willing to tell us about
//
//   -> items    pinned apps first, in the order they were pinned, then any
//               running app that is not pinned, in the order its first window
//               appeared. Exactly how a dock is expected to behave.
//
// Each entry in `items` is a plain object:
//
//   key       the canonical desktop id, lower case: "org.gnome.nautilus"
//   pinned    true if this tile came from the pinned list
//   entry     the DesktopEntry, or null if we could not identify the app
//   appId     the raw appId the compositor reported, or the pinned name
//   windows   the Toplevels belonging to this app — empty means "not running"
//
// THE STANDARDISED-PROTOCOLS LAW, HERE
//   `ToplevelManager` is Quickshell's client for
//   zwlr-foreign-toplevel-management-v1 — a published protocol implemented by
//   labwc, niri, sway, Hyprland and KWin alike. There is no KWin script, no
//   Mutter D-Bus interface and no Hyprland socket anywhere in this dock, and
//   tests/test-shell.sh fails the build if one appears.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/ToplevelManager/)
//
// MATCHING A WINDOW TO AN APP — the part that is genuinely hard
//   A window reports an `appId` ("org.gnome.Nautilus", "firefox", "steam").
//   A pinned slot names a .desktop file. Those two agree less often than you
//   would hope, so we do not try to be clever ourselves; we ask Quickshell:
//
//     DesktopEntries.heuristicLookup(appId)
//
//   which tries an exact id match, then a case-insensitive id match, then
//   matches the appId against each entry's StartupWMClass, exactly and then
//   case-insensitively. (Read out of quickshell's own desktopentry.cpp, since
//   the docs only say "will try to guess".) If it finds an entry, that entry's
//   id IS the app's identity and the window joins whichever tile carries it.
//   If it finds nothing, the window becomes its own tile keyed on its raw
//   appId — visible and clickable, just unnamed, which beats vanishing.
//
// WHY THE MODEL DOES NOT REBUILD WHEN YOU CLICK BETWEEN WINDOWS
//   A QML binding depends on exactly the properties it reads while it runs.
//   The block below reads each window's `appId` and never its `activated`, so
//   focus moving from one window to another does not rebuild the list and does
//   not throw away and recreate every tile. Focus is read by the tiles
//   themselves. Keep it that way — reading `activated` here would make the
//   whole dock flicker on every alt-tab.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Wayland

QtObject {
    id: root

    // Set by the Dock from DockConfig.
    property var pinnedIds: []

    // Every window, live. `.values` rather than the model itself, because
    // ObjectModel's docs are explicit that only `values` updates reactively.
    readonly property var toplevels: ToplevelManager.toplevels.values

    // "org.gnome.Nautilus.desktop" and "org.gnome.Nautilus" and
    // "ORG.GNOME.NAUTILUS" are all the same app. This is the form we compare.
    function normaliseId(id: string): string {
        if (!id)
            return "";
        let text = String(id);
        if (text.toLowerCase().endsWith(".desktop"))
            text = text.slice(0, -8);
        return text.toLowerCase();
    }

    // Find the DesktopEntry for a name out of the pinned list. `byId` wants an
    // exact id, and an id never carries the ".desktop" ending — quickshell
    // builds it from the file's base name — so try the name as written first
    // (in case somebody pinned an id), then with the ending removed, then fall
    // back to the heuristic lookup.
    function pinnedEntry(id: string): var {
        if (!id)
            return null;
        let text = String(id);

        let entry = DesktopEntries.byId(text);
        if (entry)
            return entry;

        if (text.toLowerCase().endsWith(".desktop")) {
            text = text.slice(0, -8);
            entry = DesktopEntries.byId(text);
            if (entry)
                return entry;
        }

        return DesktopEntries.heuristicLookup(text);
    }

    // The ordered tile list. See the header for the shape of each entry.
    readonly property var items: {
        // Touching the application index makes this binding re-run when an app
        // is installed or removed, which is the only way a name in the pinned
        // list can start or stop resolving while the shell is running. The
        // value itself is not used; the dependency is the point.
        void DesktopEntries.applications.values.length;

        const windows = root.toplevels || [];
        const pinnedList = root.pinnedIds || [];

        // ---- 1. group the running windows by the app they belong to --------
        // `Object.create(null)` rather than `{}`: these are keyed on strings we
        // did not choose — appIds from other people's applications. A plain
        // object inherits names like "constructor" and "toString", so an app
        // whose id happened to be one of those would find a function sitting
        // where its bucket should be, and the dock would fall over. An object
        // with no prototype has no such names.
        const buckets = Object.create(null);   // key -> {key, appId, entry, windows}
        const seenOrder = []; // keys, in the order their first window appeared

        for (let i = 0; i < windows.length; i++) {
            const window = windows[i];
            if (!window)
                continue;

            const appId = window.appId || "";
            const entry = appId === "" ? null : DesktopEntries.heuristicLookup(appId);
            const key = root.normaliseId(entry ? entry.id : appId);

            // A window with no appId and no entry has no identity we can group
            // or name. Compositors do report these during start-up. Skipping is
            // better than a nameless tile that appears and vanishes.
            if (key === "")
                continue;

            if (!buckets[key]) {
                buckets[key] = { key: key, appId: appId, entry: entry, windows: [] };
                seenOrder.push(key);
            }
            buckets[key].windows.push(window);
        }

        const out = [];
        const placed = Object.create(null);   // same reasoning as `buckets`

        // ---- 2. the pinned apps, in the order they were pinned -------------
        for (let i = 0; i < pinnedList.length; i++) {
            const raw = pinnedList[i];
            const entry = root.pinnedEntry(raw);

            // Prefer the resolved entry's own id as the key, so a slot pinned
            // as "steam.desktop" and a window reporting "steam" land together.
            const key = root.normaliseId(entry ? entry.id : raw);
            if (key === "" || placed[key])
                continue;

            const bucket = buckets[key];

            // Not installed and not running: draw nothing. A name that does not
            // resolve costs its slot and nothing else — same rule as the KDE
            // dock, and it means a typo can never break the dock.
            if (!entry && !bucket)
                continue;

            placed[key] = true;
            out.push({
                key: key,
                pinned: true,
                entry: entry ? entry : (bucket ? bucket.entry : null),
                appId: bucket ? bucket.appId : String(raw),
                windows: bucket ? bucket.windows : []
            });
        }

        // ---- 3. everything else that is running ----------------------------
        for (let i = 0; i < seenOrder.length; i++) {
            const key = seenOrder[i];
            if (placed[key])
                continue;
            placed[key] = true;

            const bucket = buckets[key];
            out.push({
                key: key,
                pinned: false,
                entry: bucket.entry,
                appId: bucket.appId,
                windows: bucket.windows
            });
        }

        return out;
    }
}
