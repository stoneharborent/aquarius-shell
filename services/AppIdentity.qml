// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// AppIdentity — "which application is this window?", answered in one place
// =============================================================================
// THE QUESTION
//
//   A window tells the compositor what it is with a short string called an
//   `appId`: "org.gnome.Nautilus", "firefox", "steam_app_1234". A menu entry —
//   the thing that gives an application its name and its icon — is a .desktop
//   file with an id of its own. Those two agree less often than you would hope,
//   and the whole desktop depends on matching them:
//
//     the dock          groups every window of one app onto one tile
//     the app switcher  does the same thing, in a different order
//     the top bar       names the app you are in
//
//   Three components, one question. Before this file there were three answers,
//   written out longhand in three places, and components/dock/DockConfig.qml
//   said so in its own comments:
//
//       "DockModel.qml has the same function, for the same reason, and the two
//        must agree — a name this file thinks is pinned and that file thinks is
//        not would put a menu item in front of somebody that does nothing. They
//        are eight lines each and neither imports the other; if a third copy
//        ever appears, that is the moment to give it a home of its own."
//
//   The app switcher was the third copy. This is the home.
//
// WHAT IS IN HERE AND WHAT IS NOT
//
//   In here: identity. Given an appId or a pinned name, what application is it,
//   what is its canonical key, what is it called, and what is its icon.
//
//   Not in here: anything about windows, order, focus or drawing. This file
//   never looks at ToplevelManager and holds no state at all — every function
//   is a pure answer to its arguments. That is what makes it safe for three
//   components with three different ideas of ordering to share.
//
// WHY heuristicLookup AND NOT SOMETHING OF OUR OWN
//
//   Quickshell's `DesktopEntries.heuristicLookup(appId)` tries an exact id
//   match, then a case-insensitive id match, then matches the appId against
//   each entry's StartupWMClass, exactly and then case-insensitively. (Read out
//   of quickshell's own desktopentry.cpp, since the docs only say "will try to
//   guess".) That is more tries than we would have thought of, it is the same
//   guess every other Quickshell shell makes, and when it improves upstream we
//   get the improvement.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell/DesktopEntries/)
//
// NOT PROVEN ON HARDWARE. Checked statically (tests/test-shell.sh section 38).
// =============================================================================
pragma Singleton

import Quickshell

Singleton {
    id: root

    // -------------------------------------------------------------------------
    // normaliseId — the form two spellings of one app are compared in
    // -------------------------------------------------------------------------
    // "org.gnome.Nautilus.desktop", "org.gnome.Nautilus" and "ORG.GNOME.NAUTILUS"
    // are one application written three ways, and all three turn up: a pinned
    // list accepts either ending, and a desktop entry's own id never carries
    // one (quickshell builds it from the file's base name).
    function normaliseId(id: string): string {
        if (!id)
            return "";
        let text = String(id);
        if (text.toLowerCase().endsWith(".desktop"))
            text = text.slice(0, -8);
        return text.toLowerCase();
    }

    // -------------------------------------------------------------------------
    // lookup — appId (from a window) -> DesktopEntry, or null
    // -------------------------------------------------------------------------
    function lookup(appId: string): var {
        if (!appId)
            return null;
        return DesktopEntries.heuristicLookup(String(appId));
    }

    // -------------------------------------------------------------------------
    // lookupPinned — a name a PERSON wrote -> DesktopEntry, or null
    // -------------------------------------------------------------------------
    // Different from `lookup` because the input is different. A pinned slot
    // names a .desktop file, so the exact id is tried first — `byId` wants an
    // exact id and an id never carries the ".desktop" ending — then the name
    // with the ending removed, and only then the heuristic guess.
    function lookupPinned(id: string): var {
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

    // -------------------------------------------------------------------------
    // keyFor — the one string that says "these windows are the same app"
    // -------------------------------------------------------------------------
    // If the entry was found, ITS id is the identity, so a window reporting
    // "steam" and a slot pinned as "steam.desktop" land on the same tile. If it
    // was not found, the window's own appId is its identity — visible and
    // clickable, just unnamed, which beats vanishing.
    //
    // An empty string means "no identity at all". Compositors do report
    // appId-less windows during start-up, and the callers all drop those.
    function keyFor(appId: string, entry: var): string {
        return root.normaliseId(entry ? entry.id : appId);
    }

    // -------------------------------------------------------------------------
    // tidyAppId — "org.kde.dolphin" -> "Dolphin"
    // -------------------------------------------------------------------------
    // Last dot-separated piece, first letter raised. Crude, and only ever
    // reached when the proper lookup already failed — but much kinder than
    // showing somebody a raw reverse-DNS string.
    function tidyAppId(id: string): string {
        if (!id)
            return "";
        const pieces = String(id).split(".");
        const last = pieces[pieces.length - 1];
        if (last.length === 0)
            return String(id);
        return last.charAt(0).toUpperCase() + last.slice(1);
    }

    // -------------------------------------------------------------------------
    // displayName — what to call this application on screen
    // -------------------------------------------------------------------------
    function displayName(entry: var, appId: string): string {
        if (entry && entry.name)
            return entry.name;
        if (appId)
            return root.tidyAppId(appId);
        return "";
    }

    // -------------------------------------------------------------------------
    // iconPath — the application's artwork, out of the icon theme
    // -------------------------------------------------------------------------
    // Quickshell resolves an icon name against the icon theme Qt is using, so
    // our icons are the same artwork every other application on the machine
    // shows. `true` as the second argument means "give me an empty string if it
    // does not exist" rather than the missing-texture image — which is what
    // lets a caller know its two-letter fallback is needed.
    // (https://quickshell.org/docs/v0.3.1/types/Quickshell/ - iconPath)
    function iconPath(entry: var, appId: string): string {
        const name = entry && entry.icon ? entry.icon : appId;
        if (!name)
            return "";
        return Quickshell.iconPath(String(name), true);
    }
}
