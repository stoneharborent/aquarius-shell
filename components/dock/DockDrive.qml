// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// DockDrive — one mounted external drive, at the right end of the dock
// =============================================================================
// The right end of the dock is a live list of the removable/external drives
// that are plugged in and mounted (see DockDrives.qml for where that list comes
// from). This is one of them: a dock tile that draws the drive glyph, opens the
// drive in Files when clicked, and offers Eject / Unmount on a right-click.
//
//        ▤          <- the drive glyph, on the slab, no box (same as an app)
//
// It is built to match DockItem.qml exactly — same square tile, same hover lift,
// same press wash, no surface around the icon — so a drive reads as a member of
// the dock rather than as a different kind of thing bolted onto the end. What it
// does NOT have is a running dot: a drive is either mounted (and shown) or not
// (and gone), so there is no second state to indicate.
//
// WHY A GLYPH AND NOT AN ICON
//   A drive has no .desktop entry and no artwork of its own, so there is nothing
//   for Quickshell.iconPath to resolve. The shell draws its own drive mark from
//   QsGlyph, the same vector-glyph vocabulary the Quick Settings tiles and the
//   bar use, so it follows the theme and needs no icon theme installed. The
//   volume's name is carried on the tile's accessibility label and shown at the
//   head of the right-click menu.
//
// HOW IT REACHES THE SYSTEM — and the standardised route it takes
//   Opening and unmounting both go through GVfs/GIO's `gio` command, run
//   detached:
//
//     open    xdg-open <mount path>      -> the user's file manager
//     unmount gio mount -u -f <path>     -> GVfs, which sees the udisks2 mount
//
//   DockDrives.qml carries the full note on why the list is read the way it is
//   and why GIO is the unmount path. The os-image side provides passwordless
//   automount and unmount for removable drives, so neither of these raises a
//   polkit prompt. These are launches / one-shot system requests, the same shape
//   as everything else the shell shells out for, and they use execDetached so a
//   shell reload cannot orphan them — not the Process-command form
//   tests/test-shell.sh section 22 guards.
// =============================================================================
import QtQuick

import Quickshell

import "../bar"
import "../quicksettings"
import "../../theme"

Item {
    id: root

    // The absolute mount point, e.g. /run/media/royce/FIELD SSD.
    property string mountPath: ""

    // The volume's name, which is the mount directory's own name.
    property string mountLabel: ""

    implicitWidth: Theme.dockTileSize
    implicitHeight: Theme.dockTileSize

    Accessible.role: Accessible.Button
    Accessible.name: root.mountLabel
    Accessible.description: qsTr("External drive · click to open, right-click to eject")

    function open(): void {
        if (root.mountPath !== "")
            Quickshell.execDetached(["xdg-open", root.mountPath]);
    }

    function unmount(): void {
        if (root.mountPath !== "")
            Quickshell.execDetached(["gio", "mount", "-u", "-f", root.mountPath]);
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

    // ---- the right-click menu ------------------------------------------------
    // A small popup hanging ABOVE the tile (the dock is at the bottom of the
    // screen), dismissed by a click anywhere else. It shows the drive's name and
    // one action. `grabFocus` is the same dismiss-on-outside-click mechanism
    // Quick Settings uses; see QuickSettingsPopup.qml for the one wrinkle it has.
    PopupWindow {
        id: driveMenu

        function toggle(): void {
            driveMenu.visible = !driveMenu.visible;
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

                MenuRow {
                    width: menuCol.width
                    label: qsTr("Eject / Unmount")
                    onActivated: {
                        root.unmount();
                        driveMenu.visible = false;
                    }
                }
            }
        }
    }
}
