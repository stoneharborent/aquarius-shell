// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// ActiveAppName — the name of whatever app you are using right now
// =============================================================================
// In the V2 design this sits immediately right of the Aquarius mark, in bold:
//
//     [A]  Files    File  Edit  View  Go  Help                     Sat Aug 30 21:47
//          ^^^^^    ^^^^^^^^^^^^^^^^^^^^^^ <- THIS PART IS GONE, ON PURPOSE
//
// WHY THE MENUS ARE GONE
//   The design showed File/Edit/View next to the app name, the way macOS does
//   it. That does not work in 2026 and cannot be made to work. A "global menu"
//   relies on each application exporting its menus over D-Bus, and only Qt apps
//   do. GTK apps, Electron apps (OBS, Discord, VS Code) and every browser export
//   nothing at all — so the bar would sit empty for exactly the applications a
//   creator lives in. Rather than ship a promise the bar cannot keep, the top
//   bar for this shell is: logo, app name, space, status cluster, clock.
//   Nothing else. (Recorded in the custom-DE plan, "Two findings that change the
//   design regardless of path".)
//
// HOW THE NAME IS FOUND, AND WHY IT WORKS ON ANY COMPOSITOR
//   Quickshell's ToplevelManager reports the windows the compositor is willing
//   to talk about, through the standardised zwlr-foreign-toplevel-management-v1
//   protocol — a published protocol, not a private back door into one
//   compositor. `activeToplevel` is the focused one.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/ToplevelManager/)
//
//   A toplevel gives us two useful strings: `appId` (a machine name like
//   "org.kde.dolphin") and `title` (the window's own title bar text, which is
//   usually the document, not the app). We want the app's proper human name, so
//   we take the appId to DesktopEntries — the index of every installed
//   application's .desktop file — and ask what that app calls itself.
//   `heuristicLookup` is used rather than `byId` because appIds and .desktop
//   file names agree less often than you would hope, and it guesses well.
//
//   If the lookup finds nothing, we tidy up the appId ourselves rather than
//   showing the user a reverse-DNS string.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Wayland

import "../../theme"

Text {
    id: root

    // What to show when nothing is focused — an empty desktop, or the moment
    // right after you close the last window.
    property string fallbackText: "Desktop"

    // Long window names must not push the clock off the screen. Past this many
    // pixels the name is cut with an ellipsis.
    property int maximumWidth: 240

    readonly property var toplevel: ToplevelManager.activeToplevel
    readonly property string appId: root.toplevel ? root.toplevel.appId : ""

    readonly property var entry: root.appId === ""
        ? null
        : DesktopEntries.heuristicLookup(root.appId)

    readonly property string appName: {
        if (root.entry && root.entry.name)
            return root.entry.name;
        if (root.appId !== "")
            return root.tidyAppId(root.appId);
        return root.fallbackText;
    }

    // "org.kde.dolphin" -> "Dolphin". Last dot-separated piece, first letter
    // raised. Crude, but only ever used when the proper lookup already failed,
    // and much kinder than showing the raw string.
    function tidyAppId(id: string): string {
        const pieces = id.split(".");
        const last = pieces[pieces.length - 1];
        if (last.length === 0)
            return id;
        return last.charAt(0).toUpperCase() + last.slice(1);
    }

    text: root.appName

    font.family: Theme.fontBody
    font.pixelSize: Theme.fsCaption
    font.weight: Font.DemiBold          // the design's 600
    color: Theme.ink
    textFormat: Text.PlainText
    elide: Text.ElideRight
    width: Math.min(root.implicitWidth, root.maximumWidth)

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Active application: %1").arg(root.appName)
}
