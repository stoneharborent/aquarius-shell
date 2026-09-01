// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// TrayItem — one application's icon in the system tray
// =============================================================================
// THE PROTOCOL, AND WHY THIS FILE IS SHORT
//   The system tray is StatusNotifierItem: applications register themselves on
//   D-Bus and a "host" — us — displays them. It is a published interface that
//   KDE, GNOME-with-an-extension, and every wlroots-based shell speak, so it
//   satisfies the standardised-protocols law without argument.
//
//   Implementing a host by hand is a notorious multi-week job with a very long
//   tail of applications that get the spec slightly wrong. Quickshell has done
//   it: `Quickshell.Services.SystemTray` (present since v0.2.1), which is one of
//   the specific reasons ADR 0001 chose Quickshell over LayerShellQt.
//
//   Verified against
//   https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.SystemTray/:
//
//     SystemTray (singleton)  items : ObjectModel<SystemTrayItem>
//     SystemTrayItem          icon : string  (usable directly as an Image source)
//                             id, title, tooltipTitle, tooltipDescription
//                             hasMenu, onlyMenu, menu : QsMenuHandle
//                             activate(), secondaryActivate(), scroll(),
//                             display(parentWindow, relativeX, relativeY)
//
//   Merely referencing the SystemTray singleton is what makes Quickshell start
//   tracking the tray at all — it is lazy on purpose.
//
// THE THREE GESTURES, AND WHY THEY ARE THESE THREE
//   left click   activate()          — what the application calls its main action
//   right click  the menu            — where every tray application puts its
//                                      Quit, its Settings and its real controls
//   scroll       scroll()            — mixers and volume applets use this
//
//   `onlyMenu` is the case where an application says it has no meaningful click
//   action, only a menu. Left-clicking those opens the menu instead, which is
//   what every other tray does and what their users expect.
//
// WHY QsMenuAnchor AND NOT display()
//   `display()` asks the application to draw its own platform menu at a position
//   relative to a window. `QsMenuAnchor` renders the same menu through
//   Quickshell, anchored the same way this shell anchors everything else. The
//   second one is the one that can eventually be made to look like the rest of
//   the shell. Both go through DBusMenu, so neither is more or less standard.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

import "../../theme"

BarItem {
    id: root

    // The SystemTrayItem this icon stands for.
    required property SystemTrayItem item

    interactive: true

    Accessible.role: Accessible.Button
    Accessible.name: root.item.title !== "" ? root.item.title : root.item.id
    Accessible.description: root.item.tooltipDescription

    onClicked: {
        if (root.item.onlyMenu)
            root.openMenu();
        else
            root.item.activate();
    }

    onRightClicked: root.openMenu()

    function openMenu() {
        if (!root.item.hasMenu)
            return;
        menuAnchor.open();
    }

    QsMenuAnchor {
        id: menuAnchor

        menu: root.item.menu

        anchor {
            item: root
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: Theme.qsPopupGap
        }
    }

    IconImage {
        implicitSize: Theme.barTrayIconSize

        // The application's OWN artwork, at its own colours. This is the one
        // place in the shell that does not follow the theme, and it must not:
        // a tray icon is somebody else's brand mark, and recolouring Steam's
        // logo to Aquarius Blue would be both wrong and slightly rude.
        source: root.item.icon

        // These icons are small and change rarely, which is exactly what
        // IconImage is documented as being for.
        asynchronous: true

        MouseArea {
            // The scroll gesture. It is a separate MouseArea rather than a
            // change to BarItem's, because scrolling is meaningless on every
            // other bar item and a wheel handler that swallows events it does
            // not use is a good way to break scrolling somewhere else later.
            //
            // IT MUST LIVE INSIDE THE ICON, not beside it.
            //   Anything nested directly in a BarItem lands in that item's
            //   content `Row`, and a Row will not accept a child that uses
            //   anchors — it refuses to lay ANY of its children out and says so:
            //
            //     QML Row: Cannot specify left, right, horizontalCenter, fill
            //     or centerIn anchors for items inside Row. Row will not function.
            //
            //   That is what this component did until 2026-09-01, when the shell
            //   was first run on real hardware with a real tray in it: two tray
            //   icons on the machine, two broken rows, two warnings a run.
            //   Sitting inside the icon, `parent` is the icon, the anchor is
            //   legal, and the target is the same artwork the user is aiming at.
            //   As a bonus it no longer takes a slot of its own in the row.
            //
            // BarItem's own MouseArea sits above this one but does not handle
            // wheel events, and an unhandled wheel event falls through — which
            // is how this gets to see it at all.
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function (event) {
                if (event.angleDelta.y !== 0)
                    root.item.scroll(event.angleDelta.y, false);
                if (event.angleDelta.x !== 0)
                    root.item.scroll(event.angleDelta.x, true);
            }
        }
    }
}
