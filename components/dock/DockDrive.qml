// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// DockDrive — one mounted external drive, at the right end of the dock
// =============================================================================
// The right end of the dock is a live list of the removable/external drives
// that are plugged in and mounted (see DockDrives.qml for where that list comes
// from). This is one of them: a dock tile that draws the drive glyph, opens the
// drive in Files when clicked, and offers Unmount and Eject on a right-click.
//
//        ▤          <- the drive glyph, on the slab, no box (same as an app)
//
// It is built to match DockItem.qml exactly — same square tile, same hover lift,
// same press wash, no surface around the icon — so a drive reads as a member of
// the dock rather than as a different kind of thing bolted onto the end. What it
// does NOT have is a running dot: a drive is either mounted (and shown) or not
// (and gone), so there is no second state to indicate.
//
// The right-click menu below is the PATTERN the app tiles copied when they grew
// one of their own (DockItem.qml, 2026-09-06): a PopupWindow with `grabFocus`,
// hanging above the tile, drawn out of the Aquarius menu's own MenuRow. If you
// change the shape of one, look at the other.
//
// WHY A GLYPH AND NOT AN ICON
//   A drive has no .desktop entry and no artwork of its own, so there is nothing
//   for Quickshell.iconPath to resolve. The shell draws its own drive mark from
//   QsGlyph, the same vector-glyph vocabulary the Quick Settings tiles and the
//   bar use, so it follows the theme and needs no icon theme installed. The
//   volume's name appears on hover, in the accessibility label, and at the
//   head of the right-click menu.
//
// TWO WAYS TO PUT A DRIVE AWAY, AND THEY ARE NOT THE SAME THING
//   (FEATURES 019, Royce, 2026-09-14. Until then the menu said one thing,
//   "Eject / Unmount", which promised a power-off it never did.)
//
//     Unmount  closes the drive's files. The drive stays switched on and
//              udisks2 still knows it is there, so it stays in the Files
//              sidebar with a MOUNT icon and one click brings it back — no
//              unplugging, no password. The dock tile goes, because
//              DockDrives.qml lists the folders under /run/media/<you> and that
//              folder has just gone. This is the macOS behaviour Royce asked
//              for, and it is what the old single menu item already did.
//     Eject    unmount AND power the drive off, so the light goes out and the
//              cable can come out. Two steps in order, which QML cannot do on
//              its own (it can start a command; it cannot wait for one), so
//              this one goes through eject-drive.py.
//
//   A MAC (APFS) DRIVE GETS ONLY ONE ITEM — Eject. It was opened by apfs-fuse
//   in your own session rather than by udisks2, so there is no powered drive
//   object behind it and nothing to leave sitting in Files: closing it IS
//   putting it away. Offering both names for one action would be a menu telling
//   a small lie. services/MountTable.qml is what knows which kind this is.
//
// HOW IT REACHES THE SYSTEM — and the standardised route it takes
//   All three actions are `execDetached` one-shots:
//
//     open    open-drive.py <mount path> -> xdg-open at the files' folder
//     unmount gio mount -u -f <path>     -> GVfs, which sees the udisks2 mount
//     eject   eject-drive.py <path>      -> unmount, then `udisksctl power-off`
//
//   DockDrives.qml carries the full note on why the list is read the way it is
//   and why GIO is the unmount path. The os-image side provides passwordless
//   automount, unmount AND power-off for removable drives (its polkit rule,
//   49-aquarius-udisks.rules, grants all three to the person at the screen), so
//   none of these raises a prompt. These are launches / one-shot system
//   requests, the same shape as everything else the shell shells out for, and
//   they use execDetached so a shell reload cannot orphan them — not the Process-command form
//   tests/test-shell.sh section 22 guards.
// =============================================================================
import QtQuick

import Quickshell

import "../bar"
import "../quicksettings"
import "../../services"
import "../../theme"

Item {
    id: root

    // The absolute mount point, e.g. /run/media/royce/FIELD SSD.
    property string mountPath: ""

    // The volume's name, which is the mount directory's own name.
    property string mountLabel: ""

    implicitWidth: Theme.dockTileSize
    implicitHeight: Theme.dockTileSize

    // Which kind of drive this is, which decides whether the menu offers one
    // item or two. Read from the kernel's mount table through
    // services/MountTable.qml; if that could not be read the answer is false,
    // which gives the ordinary two-item menu — the common case, and the one
    // where being wrong costs nothing (both items close the drive).
    readonly property bool macDrive: root.mountPath !== ""
        && MountTable.isMacDrive(root.mountPath)

    Accessible.role: Accessible.Button
    Accessible.name: root.mountLabel
    Accessible.description: root.macDrive
        ? qsTr("Mac drive · click to open, right-click to eject it")
        : qsTr("External drive · click to open, right-click to unmount or eject it")

    function open(): void {
        if (root.mountPath !== "")
            Quickshell.execDetached(["python3", Quickshell.shellDir + "/components/dock/open-drive.py", root.mountPath]);
    }

    // Close the drive's files and leave it switched on: it disappears from the
    // dock and stays in Files with a re-mount icon. Not offered for a Mac drive
    // — see the header.
    function unmount(): void {
        if (root.mountPath !== "")
            Quickshell.execDetached(["gio", "mount", "-u", "-f", root.mountPath]);
    }

    // Close it AND power it off, so it is safe to unplug. The script does the
    // two steps in order and picks the right unmount for the kind of drive.
    function eject(): void {
        if (root.mountPath !== "")
            Quickshell.execDetached(["python3", Quickshell.shellDir + "/components/dock/eject-drive.py", root.mountPath]);
    }

    // ---- one overlay at a time -----------------------------------------------
    // This menu takes a compositor grab, exactly as Quick Settings does, so it
    // belongs in the shell's one-exclusive-overlay-at-a-time registry like
    // everything else that does. It was left out when this file was written on
    // 2026-09-06 and put in the same day the app tiles next door grew a menu of
    // their own — with two kinds of menu in one dock, "opening one closes the
    // other" stopped being a nicety.
    //
    // Registering is per INSTANCE, and there is one per drive per monitor, which
    // is why services/Overlays.qml keeps a list. Unregistering is not optional:
    // this object is destroyed when the drive is unplugged or the monitor is,
    // and a closer left in the registry would be called on a destroyed object.
    // A tile is built when a drive is mounted, so this is also the moment the
    // mount table has just changed: reading it here is what gives `macDrive` an
    // answer, since nothing watches a /proc file.
    Component.onCompleted: {
        Overlays.register(root, () => root.closeMenu());
        MountTable.refresh();
    }
    Component.onDestruction: Overlays.unregister(root)

    function closeMenu(): void {
        driveMenu.visible = false;
    }

    // ---- the tile, which lifts on hover (identical to DockItem) ---------------
    Item {
        id: tile

        anchors.fill: parent

        readonly property bool lifted: pointer.containsMouse

        scale: tile.lifted ? Theme.dockHoverScale : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeOut
            }
        }

        transform: Translate {
            y: tile.lifted ? -Theme.dockLift : 0

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durFast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }

        // Pressed feedback, the same wash and corner as an app tile's.
        Rectangle {
            anchors.fill: parent
            radius: Theme.dockTileRadius
            color: Theme.pressWash
            visible: pointer.pressed
        }

        QsGlyph {
            anchors.centerIn: parent
            glyph: "drive"
            size: Theme.dockDriveGlyphSize
            color: Theme.ink
        }
    }

    MouseArea {
        id: pointer

        // Fills the item, not the lifting tile — see the note in DockItem.qml.
        anchors.fill: parent

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                driveMenu.toggle();
            else
                root.open();
        }
    }

    // A separate, input-transparent surface keeps the label above the dock
    // without stealing the pointer or keyboard from the tile underneath.
    PopupWindow {
        anchor {
            item: root
            edges: Edges.Top
            gravity: Edges.Top
            margins.bottom: Theme.logoMenuGapUnderBar + Theme.dockLift
        }
        visible: pointer.containsMouse && !pointer.pressed
            && !driveMenu.visible && root.mountLabel !== ""
        grabFocus: false
        mask: Region {}
        color: "transparent"
        implicitWidth: labelCard.implicitWidth
        implicitHeight: labelCard.implicitHeight

        Rectangle {
            id: labelCard
            implicitWidth: Math.min(driveLabel.implicitWidth + Theme.logoMenuRowPaddingH * 2,
                                    Theme.logoMenuMinWidth * 2)
            implicitHeight: driveLabel.implicitHeight + Theme.logoMenuPaddingV * 2
            radius: Theme.logoMenuRadius
            color: Theme.surface
            border.width: Theme.hairline
            border.color: Theme.lineStrong

            Text {
                id: driveLabel
                anchors.centerIn: parent
                width: parent.implicitWidth - Theme.logoMenuRowPaddingH * 2
                text: root.mountLabel
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                font.family: Theme.fontBody
                font.pixelSize: Theme.fsCaption
                color: Theme.ink
            }
        }
    }

    // ---- the right-click menu ------------------------------------------------
    // A small popup hanging ABOVE the tile (the dock is at the bottom of the
    // screen), dismissed by a click anywhere else. It shows the drive's name and
    // one action. `grabFocus` is the same dismiss-on-outside-click mechanism
    // Quick Settings uses; see QuickSettingsPopup.qml for the one wrinkle it has.
    PopupWindow {
        id: driveMenu

        function toggle(): void {
            if (driveMenu.visible) {
                driveMenu.visible = false;
                return;
            }
            // Before the surface goes up, so anything else holding the keyboard
            // has already let go by the time this asks for its grab.
            Overlays.claim(root);
            driveMenu.visible = true;
        }

        anchor {
            item: root
            edges: Edges.Top
            gravity: Edges.Top
            margins.bottom: Theme.logoMenuGapUnderBar
        }

        implicitWidth: menuCard.implicitWidth
        implicitHeight: menuCard.implicitHeight

        color: "transparent"
        visible: false
        grabFocus: true

        Rectangle {
            id: menuCard

            // Fixed width, the same reasoning as LogoMenu's card — a content
            // width would make the Column and the rows size each other. The
            // drive name in the header row elides if it does not fit.
            implicitWidth: Theme.logoMenuMinWidth
            implicitHeight: menuCol.implicitHeight + Theme.logoMenuPaddingV * 2

            radius: Theme.logoMenuRadius
            color: Theme.surface
            border.width: Theme.hairline
            border.color: Theme.lineStrong

            Column {
                id: menuCol

                x: 0
                y: Theme.logoMenuPaddingV
                width: menuCard.implicitWidth
                spacing: 0

                // The drive's name, as a quiet non-clickable header, so the menu
                // says which drive it is about.
                MenuRow {
                    width: menuCol.width
                    label: root.mountLabel
                    disabled: true
                }

                MenuRow {
                    width: menuCol.width
                    isSeparator: true
                }

                // UNMOUNT — closes the files, leaves the drive switched on
                // and in the Files sidebar with a re-mount icon. Hidden for a
                // Mac drive, where it would be a second name for Eject.
                MenuRow {
                    width: menuCol.width
                    visible: !root.macDrive
                    label: qsTr("Unmount")
                    onActivated: {
                        root.unmount();
                        // The mount table has just changed; read it again so
                        // the next tile to appear gets a fresh answer.
                        MountTable.refresh();
                        driveMenu.visible = false;
                    }
                }

                // EJECT — unmount, then power the drive down so the cable can
                // come out. The one item a Mac drive gets.
                MenuRow {
                    width: menuCol.width
                    label: qsTr("Eject")
                    onActivated: {
                        root.eject();
                        MountTable.refresh();
                        driveMenu.visible = false;
                    }
                }
            }
        }
    }
}
