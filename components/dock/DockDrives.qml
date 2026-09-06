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
// =============================================================================
import QtQuick
import Qt.labs.folderlistmodel

import Quickshell

import "../../theme"

Row {
    id: root

    // True when at least one external drive is mounted. Dock.qml binds the
    // drives Loader's visibility to this, so an empty list adds no separator and
    // no gap to the dock.
    readonly property bool hasDrives: driveModel.count > 0

    spacing: Theme.dockGap

    // The current user, for building the /run/media/<user> path. udisks2 mounts
    // per user under their own name.
    readonly property string user: {
        const u = Quickshell.env("USER");
        return (u === null || u === undefined) ? "" : String(u);
    }

    // The udisks2 removable-mount root for this user, as a file URL. Empty when
    // there is no USER in the environment, which unloads the model and shows
    // nothing rather than guessing.
    readonly property string mediaRoot:
        root.user === "" ? "" : "file:///run/media/" + root.user

    FolderListModel {
        id: driveModel

        folder: root.mediaRoot

        // Only the mounted-drive directories: subfolders, no files, no "." / "..".
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        showHidden: false
    }

    // The rule that sets the drives apart from the apps, drawn only when there is
    // at least one drive — the same 1px × dockSeparatorHeight rule the "+" used
    // to sit behind. It is the first child, so the parent dock's own dockGap sits
    // between the last app and it.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.hairline
        height: Theme.dockSeparatorHeight
        color: Theme.lineStrong
        visible: root.hasDrives
    }

    Repeater {
        model: driveModel

        delegate: DockDrive {
            required property string fileName
            required property string filePath

            mountLabel: fileName
            mountPath: filePath
        }
    }
}
