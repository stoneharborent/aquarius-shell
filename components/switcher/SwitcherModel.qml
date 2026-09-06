// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SwitcherModel — what the app switcher shows, and in what order
// =============================================================================
// ONE LIST IN, ONE LIST OUT
//
//   in    every window the compositor is willing to tell us about
//   out   `entries` — what the panel draws, already in the right order
//
// The dock has a model too (components/dock/DockModel.qml) and this is NOT a
// copy of it. They answer different questions:
//
//   the dock       "which apps are on this machine, pinned first, in a stable
//                   order that does not move under the mouse"
//   this file      "which windows have I used most recently"
//
//   A dock that reordered itself as you worked would be unusable; a switcher
//   that did NOT would be pointless. So the two orderings are genuinely
//   different and neither can be built from the other. What they DO share —
//   working out which application a window belongs to — is shared for real, in
//   services/AppIdentity.qml, which both import. There is no third copy of that
//   matching logic anywhere.
//
// =============================================================================
// THE TWO SHAPES, AND WHY THERE ARE TWO
// =============================================================================
// AquariusOS asks "Mac or Windows?" once, at first login, and that one answer
// sets the keyboard style AND this:
//
//   Mac profile      Command-Tab switches between APPLICATIONS. Five windows of
//                    one editor are ONE tile with a "5" on it. Press Down and
//                    the five appear underneath. That is what a Mac does.
//   Windows profile  Alt-Tab switches between WINDOWS. Five windows of one
//                    editor are five rows. That is what Windows does.
//
// `grouped` is which of the two we are in. The AppSwitcher sets it from
// services/KeyProfile.qml, which reads ~/.config/aquarius/keys.conf live — so
// running `aq keys windows` changes this without a logout.
//
// EVERY ENTRY IS THE SAME SHAPE either way, so the panel does not need two
// versions of everything:
//
//   key       the canonical app id, lower case: "org.gnome.nautilus"
//   entry     the DesktopEntry, or null if we could not identify the app
//   appId     the raw appId the compositor reported
//   name      what to call it on screen
//   icon      a path into the icon theme, or "" if there is no artwork
//   windows   the Toplevels this entry stands for — the app's windows in the
//             Mac profile, and a list of exactly ONE in the Windows profile
//
// A Windows-profile entry also carries `title`, the window's own name.
//
// =============================================================================
// THE ORDER: MOST RECENTLY USED
// =============================================================================
// `mru` is the list of windows in the order they were last focused, most recent
// first. It is kept up to date by watching ToplevelManager.activeToplevel: every
// time focus lands somewhere, that window moves to the front.
//
// ⚠️ WHY OPENING THE SWITCHER DOES NOT DISTURB IT
//   The panel is a layer-shell surface, not a window, so taking the keyboard
//   does not make the app you were in stop being the active TOPLEVEL. labwc
//   keeps its `active_view` while a layer surface holds keyboard focus (read
//   seat_focus() in labwc's src/seat.c), so `activeToplevel` does not change
//   while you are choosing, and the order does not shuffle under you mid-press.
//   If that ever stops being true, the symptom is unmistakable: the first tap
//   of Tab would take you nowhere, because the app you are in would have
//   swapped places with the one you wanted.
//
// A WINDOW NOBODY HAS EVER FOCUSED — something just opened, or something that
// was already open when the shell started — is not in `mru` at all. Those go on
// the END, in the order the compositor lists them. They are the least recently
// used thing on the machine, which is exactly where they belong.
//
// NOT PROVEN ON HARDWARE. Checked statically (tests/test-shell.sh section 38).
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Wayland

import "../../services"

QtObject {
    id: root

    // Set by AppSwitcher from KeyProfile. True = Mac profile = group by app.
    property bool grouped: true

    // ---- the raw material ----------------------------------------------------
    // `.values` rather than the model itself, because ObjectModel's docs are
    // explicit that only `values` updates reactively.
    readonly property var toplevels: ToplevelManager.toplevels.values

    // The window that has focus right now, or null. Watched below.
    readonly property var activeWindow: ToplevelManager.activeToplevel

    // ---- the most-recently-used list -----------------------------------------
    // Plain JavaScript array of Toplevel objects, newest first. It is a
    // `property var` rather than a local so that it survives as object state and
    // so that reassigning it notifies whatever is bound to it.
    //
    // It is allowed to hold windows that have since closed — filtering happens
    // on read, in `windows` below. Trying to prune it as windows disappear would
    // mean listening for destruction on every window in the list, which is a lot
    // of wiring to avoid a filter that has to run anyway.
    property var mru: []

    // Focus moved. Put that window at the front.
    //
    // `filter` first, then put it at the head: that both moves an existing entry
    // and adds a new one, with no branch and no chance of the same window
    // appearing twice.
    onActiveWindowChanged: {
        const now = root.activeWindow;
        if (!now)
            return;
        root.mru = [now].concat(root.mru.filter(win => win !== now));
    }

    // ---- every live window, most recently used first --------------------------
    readonly property var windows: {
        const live = root.toplevels || [];
        const recent = root.mru || [];

        const out = [];

        // 1. the ones we have a focus history for, newest first — but only if
        //    they are still open. A closed window is still in `mru`; see above.
        for (let i = 0; i < recent.length; i++) {
            const win = recent[i];
            if (win && live.indexOf(win) !== -1)
                out.push(win);
        }

        // 2. everything else, in the compositor's own order. Never focused (or
        //    focused before this shell started), so: least recent.
        for (let i = 0; i < live.length; i++) {
            const win = live[i];
            if (win && out.indexOf(win) === -1)
                out.push(win);
        }

        return out;
    }

    // ---- what the panel draws -------------------------------------------------
    readonly property var entries: {
        // Touching the application index makes this re-run when an app is
        // installed or removed, which is the only way an appId can start or stop
        // resolving to a name and an icon while the shell is running. The value
        // is not used; the dependency is the point. (Same trick as DockModel.)
        void DesktopEntries.applications.values.length;

        const ordered = root.windows;
        const out = [];

        // `Object.create(null)` rather than `{}`: these are keyed on strings we
        // did not choose — appIds from other people's applications. A plain
        // object inherits names like "constructor" and "toString", so an app
        // whose id happened to be one of those would find a function sitting
        // where its bucket should be. An object with no prototype has no such
        // names. (Same reasoning, and the same trap, as DockModel.qml.)
        const seen = Object.create(null);   // key -> index into `out`

        for (let i = 0; i < ordered.length; i++) {
            const win = ordered[i];
            if (!win)
                continue;

            const appId = win.appId || "";
            const entry = AppIdentity.lookup(appId);
            const key = AppIdentity.keyFor(appId, entry);

            // A window with no appId and no entry has no identity we can group,
            // name or draw. Compositors do report these during start-up.
            // Skipping is better than a nameless tile that appears and vanishes.
            if (key === "")
                continue;

            if (root.grouped && seen[key] !== undefined) {
                // Another window of an app we have already placed. It joins that
                // app's tile and does NOT move the tile — the tile's position is
                // set by its most recently used window, which is the first one
                // we met.
                out[seen[key]].windows.push(win);
                continue;
            }

            seen[key] = out.length;
            out.push({
                key: key,
                entry: entry,
                appId: appId,
                name: AppIdentity.displayName(entry, appId),
                icon: AppIdentity.iconPath(entry, appId),
                title: win.title || "",
                windows: [win]
            });
        }

        return out;
    }

    // -------------------------------------------------------------------------
    // Which entry is the one you are in right now
    // -------------------------------------------------------------------------
    // Used to decide what the panel opens on. Because `entries` is built from a
    // most-recently-used list and the window you are in was focused most
    // recently of all, this is nearly always 0 — but "nearly always" is not
    // "always" (nothing focused at all, or a window with no identity), so it is
    // worked out rather than assumed.
    readonly property int currentIndex: {
        const now = root.activeWindow;
        if (!now)
            return -1;
        const list = root.entries;
        for (let i = 0; i < list.length; i++) {
            if (list[i].windows.indexOf(now) !== -1)
                return i;
        }
        return -1;
    }

    // -------------------------------------------------------------------------
    // siblings — every window of the same application as this one
    // -------------------------------------------------------------------------
    // This is what Command-` uses, and it is deliberately NOT in
    // most-recently-used order. Order it by recency and Command-` stops being a
    // cycle: pressing it moves a window to the front of the MRU list, so the
    // next press would send you straight back where you came from and two
    // windows would be all you ever saw. The compositor's own order is the order
    // the windows were opened in, it does not change as you work, and going
    // round it is a genuine round trip through all of them.
    function siblings(win: var): var {
        if (!win)
            return [];

        const entry = AppIdentity.lookup(win.appId || "");
        const key = AppIdentity.keyFor(win.appId || "", entry);
        if (key === "")
            return [];

        const live = root.toplevels || [];
        const out = [];
        for (let i = 0; i < live.length; i++) {
            const other = live[i];
            if (!other)
                continue;
            const otherEntry = AppIdentity.lookup(other.appId || "");
            if (AppIdentity.keyFor(other.appId || "", otherEntry) === key)
                out.push(other);
        }
        return out;
    }

    // -------------------------------------------------------------------------
    // nextSibling — the window Command-` should go to
    // -------------------------------------------------------------------------
    // The one after `win` in the stable order above, wrapping round at the end.
    // Returns null when this app has only the one window, which is the signal to
    // do nothing at all rather than to flash a panel saying so.
    function nextSibling(win: var): var {
        const all = root.siblings(win);
        if (all.length < 2)
            return null;
        const at = all.indexOf(win);
        if (at === -1)
            return all[0];
        return all[(at + 1) % all.length];
    }

    // -------------------------------------------------------------------------
    // go — put this window in front of you
    // -------------------------------------------------------------------------
    // Un-minimising FIRST and then activating is deliberate and in that order:
    // `activate()` on a minimised window is not defined by the protocol to
    // restore it, so a switcher that only activated would leave you looking at
    // the same screen having apparently done nothing. The spec is explicit that
    // minimised windows are listed and are restored on go.
    function goTo(win: var): void {
        if (!win)
            return;
        if (win.minimized)
            win.minimized = false;
        win.activate();
    }
}
