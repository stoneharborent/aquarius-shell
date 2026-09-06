// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// DockDrives — the live list of mounted external drives, right of the apps
// =============================================================================
// This is what replaced the dashed "+" at the end of the dock on 2026-09-06
// (Royce's call). Instead of a button that opened the app grid, the right end of
// the dock now shows the removable/external drives that are plugged in and
// mounted right now — one tile per drive, with a separator before them so they
// read as their own group. Plug a drive in and a tile appears; unplug it and the
// tile goes. When nothing is plugged in, this draws nothing at all — no
// separator, no placeholder. (Search did not live only on the "+": it is on
// Super+Space and on the desktop's right-click menu, so nothing was lost.)
//
// =============================================================================
// WHERE THE LIST COMES FROM — the standardised route, and why THIS one
// =============================================================================
// The task was to read the mounts through a standard route — UDisks2 over D-Bus,
// or the GVfs/GIO volume monitor — and pick whatever the shipped Quickshell can
// do cleanly. The shipped build (quickshell 0.2.1 git, Qt 6.11) has NEITHER a
// UDisks2 QML service NOR a GIO volume-monitor binding — the probed module list
// is Networking, Bluetooth, UPower, PowerProfiles, Pipewire, SystemTray,
// ToplevelManager, DesktopEntries and Greetd, and no storage service among them.
// So there is no D-Bus object to bind to from QML without hand-rolling a client,
// which the standardised-protocols law is there to avoid.
//
// What IS clean, standard and reactive is watching the directory udisks2 mounts
// removable drives INTO. udisks2 (the same daemon a GIO/D-Bus client would end
// up talking to) auto-mounts a removable volume at:
//
//     /run/media/<user>/<volume label>
//
// so that directory's SUBFOLDERS are exactly "the external drives mounted right
// now". Qt's own FolderListModel watches a directory and updates the moment a
// mount appears or disappears — no polling, no shelling out, no compositor-
// specific anything. It is a plain reading of the mount table's user-facing face,
// and it is compositor-agnostic by construction.
//
// The trade, written down honestly so nobody has to rediscover it: this reads
// the RESULT of a mount (the folder udisks made) rather than talking to udisks
// directly, so it depends on the os-image side auto-mounting removable drives to
// /run/media (which it does, passwordless) and on Qt.labs.folderlistmodel being
// present. If either is missing the list is simply empty — the Loader in Dock.qml
// makes a missing Qt.labs module cost this one feature and nothing else. When a
// UDisks2 or GIO binding lands in a future Quickshell, this file is the one place
// that changes; the tiles and the dock do not.
//
// Unmounting takes the GVfs/GIO road (`gio mount -u`), in DockDrive.qml, because
// that is the one unmount command that works from a mount PATH — which is all a
// directory listing gives us — without first resolving the backing device.
//
// =============================================================================
// ⚠️ THE TRAP THIS FILE IS BUILT AROUND — read this before changing anything
// =============================================================================
// WHAT WENT WRONG. On the bench on 2026-09-06 the dock drew, at its right end,
// "a bunch of random folders instead of external drives" — about thirty tiles,
// with nothing plugged into the machine at all. They were the folders in Royce's
// HOME directory.
//
// WHY. Not a mistake in the path, and not a mistake in udisks2. It is what Qt's
// FolderListModel does when the folder it is given does not exist AT THE MOMENT
// THE MODEL IS CREATED. From Qt's own source, qquickfolderlistmodel.cpp, in
// componentComplete():
//
//     QString localPath = QQmlFile::urlToLocalFileOrQrc(d->currentDir);
//     if (localPath.isEmpty() || !QDir(localPath).exists())
//         setFolder(QUrl::fromLocalFile(QDir::currentPath()));
//
// Read that last line slowly. When the directory is missing, the model does not
// go empty and it does not complain: it silently re-points itself at the PROCESS'S
// CURRENT WORKING DIRECTORY. The shell is started from the session, whose working
// directory is the user's home — so every folder in the home directory became a
// "drive".
//
// And /run/media/<user> is missing far more often than not: udisks2 CREATES that
// directory when it mounts the first removable volume and REMOVES it after the
// last one is unmounted. So on a machine with nothing plugged in at login — the
// normal case — the model was always born pointing at the wrong place.
//
// It could not recover, either. `folder` was bound to a constant string, so once
// the fallback had fired nothing ever re-evaluated it; plugging a drive in later
// changed nothing. (And the mirror-image is also true, which is why a later
// setFolder() is not the fix: setFolder() called with a missing directory just
// empties the model. The silent substitution happens ONLY at completion.)
//
// HOW THIS FILE MAKES IT IMPOSSIBLE. A model is never created pointing at a
// directory this file has not just seen exist. It is a chain of three watchers,
// each one only brought into being while the level above it says its directory
// is there:
//
//     /run                     always exists on Linux — so this model, the only
//       │                      one created unconditionally, can never fall back
//       │
//       ├─ is there a "media" in it?  ── no ──▶  nothing below exists. Empty list.
//       │                             yes
//       ▼
//     /run/media               created by a Loader, torn down the moment "media"
//       │                      disappears from /run
//       │
//       ├─ is there a "<user>" in it? ── no ──▶  nothing below exists. Empty list.
//       │                             yes
//       ▼
//     /run/media/<user>        the real list. Created by a Loader, and destroyed
//                              again when the directory goes.
//
// Because each level is created only while its directory is present and destroyed
// when it goes, the componentComplete fallback has nothing to fall back FROM —
// and because a Loader creates a fresh model each time it becomes active, plugging
// a drive in an hour after login builds the list properly rather than being
// ignored. That is the recovery the old single constant-bound model did not have.
//
// BELT AND BRACES. Guards can be reasoned about wrongly, and a directory can
// vanish in the instant between the check and the creation. So each created model
// also CHECKS ITS OWN FOLDER once it is complete: it reads `folder` back and, if
// it is not exactly the directory that was asked for, the model is marked
// unhealthy, `console.warn` says so once, and the list is treated as empty —
// hasDrives goes false and not one tile is drawn. Reading `folder` back is what
// catches the fallback, because the fallback works by writing a different value
// into that very property.
//
// WHAT AN HONEST READING OF THE GUARD IS. The existence checks re-run whenever
// the listing above them changes size, which is what happens when a directory is
// created or removed. A directory swapped for another in the same instant, with
// the count landing back where it started, would not be noticed until the next
// change — the health check is the net under that. And a username containing
// characters a URL has to escape would make the read-back comparison fail and the
// list stay empty; that fails safe (nothing drawn) rather than wrong (somebody's
// home directory drawn), which is the trade this file exists to make.
// =============================================================================
import QtQuick
import Qt.labs.folderlistmodel

import Quickshell

import "../../theme"

Row {
    id: root

    // True when at least one external drive is mounted AND the model listing it
    // passed its own health check. Dock.qml binds the drives Loader's visibility
    // to this, so an empty — or a distrusted — list adds no separator and no gap
    // to the dock.
    readonly property bool hasDrives:
        driveLoader.item !== null
        && driveLoader.item !== undefined
        && driveLoader.item.healthy === true
        && driveLoader.item.count > 0

    spacing: Theme.dockGap

    // ---- the three directories, named once -----------------------------------
    // The current user, for building the /run/media/<user> path. udisks2 mounts
    // per user under their own name.
    readonly property string user: {
        const u = Quickshell.env("USER");
        return (u === null || u === undefined) ? "" : String(u);
    }

    // Level 1. /run exists on every running Linux system — it is a tmpfs the
    // init system mounts before anything else — so a model pointed here cannot
    // take the fallback described in the header.
    readonly property string runRoot: "file:///run"

    // Level 2. Created by udisks2 when it first needs it; removed again when the
    // last removable volume is unmounted.
    readonly property string mediaBase: "file:///run/media"

    // Level 3, the real one. The udisks2 removable-mount root for THIS user, as
    // a file URL. Empty when there is no USER in the environment, which leaves
    // the chain unbuilt and shows nothing rather than guessing.
    readonly property string mediaRoot:
        root.user === "" ? "" : root.mediaBase + "/" + root.user

    // ---- the two questions the chain asks ------------------------------------

    // "Does this listing contain a directory with exactly this name?"
    //
    // The loop reads `model.count`, which is what makes the answer LIVE: a QML
    // binding that calls this function re-evaluates whenever the count changes,
    // and a directory appearing or disappearing is exactly a count change. The
    // per-row `get()` calls are not properties and create no dependency of their
    // own, so the count read is doing the work — see the honest note in the
    // header about the one case that hides from it.
    function listingHas(model, name): bool {
        if (model === null || model === undefined || name === "")
            return false;

        for (let i = 0; i < model.count; i++) {
            if (String(model.get(i, "fileName")) === name)
                return true;
        }
        return false;
    }

    // "Is this model really listing the directory we asked it for?"
    //
    // THE ONE CHECK THAT CATCHES THE TRAP. Qt's fallback works by writing a
    // different value into `folder`, so reading `folder` back after completion
    // and comparing it to what was asked for is a direct question about whether
    // the fallback fired. A trailing slash is ignored because Qt may or may not
    // put one there; anything else different means this listing is somebody
    // else's directory and must not be shown.
    function folderIsExactly(model, expected): bool {
        if (model === null || model === undefined)
            return false;

        const actual = root.withoutTrailingSlash(String(model.folder));
        if (actual === root.withoutTrailingSlash(expected))
            return true;

        console.warn("aquarius-shell: dock drives: asked for", expected,
                     "but the model is listing", actual,
                     "- Qt's FolderListModel silently lists the process's working"
                     + " directory when the folder it is given does not exist,"
                     + " so this listing is being ignored and no drive tiles are"
                     + " drawn.");
        return false;
    }

    function withoutTrailingSlash(text): string {
        const s = String(text);
        return (s.length > 1 && s.charAt(s.length - 1) === "/")
            ? s.slice(0, s.length - 1) : s;
    }

    // ---- level 1: /run, watched unconditionally ------------------------------
    // The only model in this file created without a guard, because it is the only
    // one whose directory is always there. Everything else hangs off what it sees.
    FolderListModel {
        id: runDir

        folder: root.runRoot

        // Only directories: subfolders, no files, no "." / "..".
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        showHidden: false
    }

    // ---- level 2: /run/media, only while it exists ---------------------------
    // A Loader rather than a plain FolderListModel with an `active`-like guard,
    // because FolderListModel has no such guard: the only way to stop it listing
    // the wrong directory is for it not to be created at all. `visible: false`
    // keeps this Loader out of the Row's layout entirely — a Positioner skips
    // invisible children, so it costs neither width nor a spacing gap.
    Loader {
        id: mediaLoader

        visible: false
        active: root.listingHas(runDir, "media")
        sourceComponent: mediaDirComponent
    }

    Component {
        id: mediaDirComponent

        FolderListModel {
            id: mediaDir

            folder: root.mediaBase

            showDirs: true
            showFiles: false
            showDotAndDotDot: false
            showHidden: false

            // Same read-back check the real model does. If this one has been
            // substituted, the level below is never created — which is the point
            // of checking a level that draws nothing itself.
            property bool healthy: false
            Component.onCompleted:
                mediaDir.healthy = root.folderIsExactly(mediaDir, root.mediaBase)
        }
    }

    // ---- level 3: /run/media/<user>, the real list ---------------------------
    // Created only when the level above is healthy AND actually contains a
    // directory named after this user — and destroyed again the moment it does
    // not, which is what makes the list recover when a drive is plugged in long
    // after login.
    Loader {
        id: driveLoader

        visible: false
        active: root.mediaRoot !== ""
                && mediaLoader.item !== null
                && mediaLoader.item !== undefined
                && mediaLoader.item.healthy === true
                && root.listingHas(mediaLoader.item, root.user)
        sourceComponent: driveModelComponent
    }

    Component {
        id: driveModelComponent

        FolderListModel {
            id: driveModel

            folder: root.mediaRoot

            // Only the mounted-drive directories: subfolders, no files, no
            // "." / "..".
            showDirs: true
            showFiles: false
            showDotAndDotDot: false
            showHidden: false

            property bool healthy: false
            Component.onCompleted:
                driveModel.healthy = root.folderIsExactly(driveModel, root.mediaRoot)
        }
    }

    // ---- what is drawn -------------------------------------------------------
    // The rule that sets the drives apart from the apps, drawn only when there is
    // at least one drive — the same 1px × dockSeparatorHeight rule the "+" used
    // to sit behind. It is the first VISIBLE child, so the parent dock's own
    // dockGap sits between the last app and it.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.hairline
        height: Theme.dockSeparatorHeight
        color: Theme.lineStrong
        visible: root.hasDrives
    }

    Repeater {
        // Note what the model is: not `driveLoader.item` but the item ONLY when
        // the whole chain is healthy. A model that failed its read-back check
        // draws no tiles at all, rather than drawing whatever it happens to be
        // listing.
        model: root.hasDrives ? driveLoader.item : null

        delegate: DockDrive {
            required property string fileName
            required property string filePath

            mountLabel: fileName
            mountPath: filePath
        }
    }
}
