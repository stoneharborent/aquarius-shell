// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// QuickSettingsPopup — the panel as a window, hanging under the bar
// =============================================================================
// The panel itself (QuickSettingsPanel.qml) is just an Item and knows nothing
// about windows. This file is the part that makes it a real popup: a separate
// Wayland surface, positioned under the status cluster, that goes away when you
// click somewhere else.
//
// WHY A PopupWindow AND NOT AN Item DRAWN INSIDE THE BAR
//   The bar is 30 pixels tall. Anything drawn inside it is clipped to 30 pixels.
//   A panel that hangs below the bar has to be its own surface, and on Wayland
//   a surface that positions itself relative to another surface is exactly what
//   a popup is. Quickshell's PopupWindow is that, spelled portably — the same
//   arrangement as PanelWindow being layer-shell underneath.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell/PopupWindow/)
//
// HOW IT IS POSITIONED
//   `anchor.item` is the bar item that was clicked. The anchor rectangle then
//   defaults to that item's own dimensions, and two flags decide the rest:
//
//     edges:   Bottom | Right   which corner of the BAR ITEM to hang from
//     gravity: Bottom | Left    which way the PANEL grows from there
//
//   Together: the panel's top-right corner sits under the bar item's
//   bottom-right corner, and it grows downwards and leftwards. With the 8px top
//   margin that is the design's "right:12px; top:38px" on a 30px bar — 30 + 8.
//
//   The 12px from the right edge of the screen comes from the bar's own
//   `barPaddingH` (10) plus the item's padding, not from a number set here; the
//   panel lines up with the right-hand end of the bar's contents, which is what
//   the design is actually showing.
//
// ⚠️ THE CLICK-THE-BUTTON-AGAIN-TO-CLOSE PROBLEM
//   `grabFocus: true` makes the compositor dismiss the popup when the user
//   clicks anywhere outside it. That is the behaviour everybody expects, and it
//   creates one well-known wrinkle: clicking the button that OPENED the popup is
//   also "outside", so the compositor closes it and then the button's own click
//   handler opens it again. The panel flickers and never closes.
//
//   The fix here is the usual one: remember when the popup last closed itself,
//   and ignore an open request that arrives within a few frames of that. It is a
//   heuristic, not a protocol, and it is one of the things that needs a real
//   compositor to confirm — it is on the unproven list in docs/quick-settings.md.
//
//   Quickshell notes that Hyprland's HyprlandFocusGrab can do this properly.
//   This shell will not import that: it is a compositor-specific module and the
//   standardised-protocols law forbids it. A slightly clumsy portable answer
//   beats an elegant one that only works on one window manager.
// =============================================================================
import QtQuick

import Quickshell

import "../../services"
import "../../theme"

// A Scope, not an Item, and that matters: this thing has no size and must not
// take part in any layout. The bar's status cluster is a Row, and an Item
// declared inside a Row gets a slot and a spacing gap even when it draws
// nothing. Scope is Quickshell's own "container that is not a visual item",
// so a Row containing one is a Row containing nothing extra.
Scope {
    id: root

    // The bar item the panel hangs from.
    property Item anchorItem: null

    // Whether the panel is on screen. Read it, or use toggle().
    readonly property bool open: popup.visible

    // Milliseconds since the epoch when the popup last dismissed itself. See the
    // long note above.
    property double lastDismissedAt: 0

    // How close to a self-dismissal an open request has to be to be treated as
    // the same click. Two frames at 60Hz is about 33ms; 250ms is generous
    // without being long enough for a person to deliberately click twice.
    readonly property int reopenGuardMs: 250

    // ---- one overlay at a time ----------------------------------------------
    // This popup's `grabFocus: true` is the thing that broke the search palette
    // on the bench (defect 1 in docs/first-run-on-hardware.md): a compositor
    // input grab is exclusive, so while this is open nothing else in the shell
    // can be typed into. The shell's answer is a rule rather than a special
    // case — opening any exclusive overlay closes the others — and
    // services/Overlays.qml holds it. Read that file's header first.
    //
    // Registering happens per INSTANCE, and there is one instance per monitor
    // (TopBar builds a whole bar per screen with Variants, and each bar carries
    // one of these anchored to its own status cluster). That is exactly why the
    // registry keeps a list: "close Quick Settings" has to mean every screen's.
    // Unregistering matters for the same reason — unplug a monitor and this
    // object is destroyed while the registry would otherwise still hold it.
    Component.onCompleted: Overlays.register(root, () => root.hide())
    Component.onDestruction: Overlays.unregister(root)

    function show() {
        if (Date.now() - root.lastDismissedAt < root.reopenGuardMs)
            return;

        // Before the surface goes up, so the palette (or the notifications
        // panel) has already let go of the keyboard by the time this asks the
        // compositor for its grab.
        Overlays.claim(root);

        popup.visible = true;
    }

    function hide() {
        popup.visible = false;
    }

    function toggle() {
        if (popup.visible)
            root.hide();
        else
            root.show();
    }

    PopupWindow {
        id: popup

        anchor {
            item: root.anchorItem
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: Theme.qsPopupGap
        }

        // The window is exactly as big as the panel wants to be.
        //
        // implicitWidth / implicitHeight, NOT width / height: QsWindow's docs
        // say plainly that "setting this property is deprecated, set
        // implicitWidth instead" for both. It is also the arrangement that
        // cannot loop — the panel's own width and height follow its implicit
        // size, which is what an Item does unless told otherwise, so the panel
        // is never sized FROM the window.
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight

        // The popup's own background must be transparent, because the panel
        // inside it draws a rounded rectangle. Without this the corners would be
        // squared off by the window behind them.
        color: "transparent"

        visible: false

        // Dismiss on a click anywhere else. See the note at the top for the one
        // wrinkle this creates.
        grabFocus: true

        onVisibleChanged: {
            if (!popup.visible)
                root.lastDismissedAt = Date.now();
        }

        QuickSettingsPanel {
            id: panel

            // Anything that would otherwise poll in the background only polls
            // while the panel is actually being looked at.
            live: popup.visible
        }
    }
}
