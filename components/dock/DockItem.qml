// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// DockItem — one app in the dock: its icon, and its running dots
// =============================================================================
//
//                                  ICON     <- hovered: the icon rises 6px and
//                                              grows to 108%, over 120ms on
//          ICON                              the design's curve
//                                    ●
//            ●                             <- running: a centred dot. Accent
//                                             if it is the app you are in,
//                                             quiet ink if it is merely open.
//
// THERE IS NO BOX AROUND THE ICON. Look for "THERE IS NO TILE SURFACE" below
// before you add one back — that is a decision Royce made at the bench on
// 2026-09-04, not something nobody got round to.
//
// THE RUNNING DOT, AND WHY IT IS FINALLY RIGHT
//   The design has always asked for a small round mark, centred, sitting just
//   under a running app's tile:
//
//       .dock-ico i { bottom:-7px; left:50%; margin-left:-2px;
//                     width:4px; height:4px; border-radius:50%;
//                     background: var(--starlight) }
//
//   The KDE version of this dock could not draw it. Plasma builds a tile out of
//   nine pieces of one SVG and stretches the middle ones, so a dot drawn in the
//   middle piece comes out as a bar the width of the tile, and a dot drawn in a
//   corner piece stays welded to that corner. There is no piece that is both
//   fixed-size and centred, so that dock shipped a 2px underline instead and
//   wrote the compromise down (FORK-NOTES.md, B2, and the long note in the
//   theme's tasks.svg).
//
//   None of that is true here. This is a rectangle with a radius, centred on
//   the tile with an anchor. The design, drawn as drawn.
//
//   ONE DELIBERATE EXTENSION: one dot per window, up to three. A dock that
//   shows the same single dot whether an app has one window or nine is hiding
//   something the person needs when they click. With one window — the common
//   case, and the case the design draws — this is pixel-for-pixel the design's
//   single centred dot. Beyond three the dots would out-measure the tile, so
//   three is the cap.
//
//   The dot does NOT rise with the tile. In the design's HTML it does, but only
//   because it is a CSS child inheriting the tile's transform, not because
//   anybody decided it should. A running mark that jumps about reads as noise.
//   Same call the KDE dock made, for the same reason.
//
// THE HOVER LIFT
//   translateY(-4px) scale(1.08) over --dur-fast on --ease-out. The KDE version
//   had to lift the ICON ONLY and leave the tile still, because moving the tile
//   dragged Plasma's highlight artwork off the dock's border. That constraint
//   does not exist here either, so the whole `tile` Item lifts — which since the
//   surface was removed on 2026-09-04 means the icon and the press wash, and is
//   still what the CSS says. There is no artwork left that could be dragged
//   anywhere, so this can never come back.
//
// WHAT A CLICK DOES
//   nothing running    -> launch the app
//   one window, focused, not minimised
//                      -> minimise it (click the tile again to come back)
//   one window, otherwise
//                      -> un-minimise and focus it
//   several windows    -> focus the next one after whichever is focused now,
//                         wrapping round. Click again to keep walking them.
//   middle click       -> always launch a NEW copy, the usual dock convention
//
//   Cycling rather than opening a window picker is a decision, not an oversight:
//   a picker needs a popup, a layout and a keyboard story, and this dock does
//   not have those yet. Cycling is honest, obvious after one try, and the whole
//   behaviour is the `activate()` function below when the picker arrives.
//
//   Requests to activate, minimise and close are exactly that — requests. The
//   Toplevel docs are clear that a compositor may ignore any of them.
//   (https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/Toplevel/)
//
// WHAT A RIGHT-CLICK DOES — new on 2026-09-06
//   Until this change, nothing. Royce found it on the bench in four words:
//   "right click on the apps does nothing". Every dock anybody has used offers a
//   menu there, and the drives at the other end of this very dock already had
//   one, so a tile that ignored the right button was the odd one out.
//
//   Now it opens a small menu above the tile:
//
//       ┌──────────────────────────┐
//       │  Firefox                 │   <- the app's name, quiet, not clickable
//       ├──────────────────────────┤
//       │  New Window              │   <- "Open" when nothing is running
//       │  Remove from Dock        │   <- "Keep in Dock" when it is not pinned
//       ├──────────────────────────┤
//       │  Quit                    │   <- only while windows are open
//       └──────────────────────────┘
//
//   It is drawn the same way the drive menu next to it is — a PopupWindow with
//   `grabFocus`, hanging above the tile — and out of the same MenuRow the
//   Aquarius menu at the top-left of the screen uses, so all three menus in this
//   shell are one design rather than three. Esc closes it, a click anywhere else
//   closes it, and opening it closes every other overlay (services/Overlays.qml).
//
//   THIS FILE STILL KNOWS NOTHING ABOUT ANY PARTICULAR APP. The menu is built
//   from what a DesktopEntry offers everybody — a name, and the ability to run —
//   plus the two things this tile already knew: whether it is pinned, and which
//   windows it owns. The one app-specific fact in the shell (that GNOME's
//   Settings cannot be started the ordinary way) stays where it was, behind
//   SettingsLauncher.ownsDesktopEntry(), and "Open" goes through the same
//   launch() the left button does, so it inherits that without knowing about it.
//
//   PINNING WRITES A FILE, and DockConfig.qml owns that entirely: this file
//   calls `pin()` or `unpin()` and does not know the path, the format, or that
//   there is a file at all. The list changes, the model rebuilds, the tile moves
//   or leaves. See that file's header for what happens on disk.
//
//   QUIT closes every window this app owns, through the Wayland toplevel's own
//   `close()` — which, like activate and minimise above, is a REQUEST. An
//   application with unsaved work is entitled to put up a dialog and stay, and
//   that is correct behaviour, not a failed Quit.
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Widgets

import "../bar"
import "../../services"
import "../../theme"

Item {
    id: root

    // One entry from DockModel.items. See that file for the shape.
    required property var modelData

    // The dock's DockConfig, handed down by Dock.qml. It is passed rather than
    // reached for because it is not a singleton: there is exactly ONE of it for
    // the whole shell (Dock.qml's header says why — two docks reading the same
    // file separately would be two chances to disagree), and a delegate cannot
    // see an id declared two files up. Null means the pin/unpin rows are simply
    // not offered, which is the right answer for anything that instantiates a
    // DockItem without one.
    property var config: null

    readonly property var entry: root.modelData ? root.modelData.entry : null
    readonly property var windows: root.modelData && root.modelData.windows
        ? root.modelData.windows
        : []
    readonly property string appId: root.modelData ? (root.modelData.appId || "") : ""

    readonly property bool running: root.windows.length > 0

    // Is this tile in the pinned list? Read off the model rather than asked of
    // DockConfig, because the model has already done the matching — it is what
    // decided this tile is a pinned slot rather than a running app that happens
    // to be open — and two answers to one question is how a tick ends up beside
    // a menu item that does nothing.
    readonly property bool pinned: root.modelData
        ? root.modelData.pinned === true : false

    // The name to write into (or strike out of) the pinned list. A desktop
    // entry's own id, which is what that file holds: the dock is a list of
    // applications, not of windows, and an appId reported by a window is not a
    // thing that can be launched later. No entry means no id and no pinning —
    // which is only ever true of a running window nothing could identify.
    readonly property string pinId: root.entry && root.entry.id
        ? String(root.entry.id) : ""

    readonly property bool canPin: root.config !== null && root.pinId !== ""

    // True while one of this app's windows is the focused one. This is the only
    // place `activated` is read, on purpose — see the note in DockModel.qml
    // about why the model must not read it.
    readonly property bool active: {
        for (let i = 0; i < root.windows.length; i++) {
            if (root.windows[i] && root.windows[i].activated)
                return true;
        }
        return false;
    }

    // The app's human name. Falls back to tidying the appId, the same way the
    // top bar's ActiveAppName does, rather than showing a reverse-DNS string.
    readonly property string appName: {
        const name = AppIdentity.displayName(root.entry, root.appId);
        return name === "" ? qsTr("Unknown application") : name;
    }

    // Quickshell resolves an icon name against the icon theme Qt is using, so
    // the dock's icons match every other application on the machine. `true` as
    // the second argument means "give me an empty string if it does not exist"
    // rather than the missing-texture image — which is what lets the two-letter
    // fallback below know it is needed.
    // (https://quickshell.org/docs/v0.3.1/types/Quickshell/ - iconPath)
    readonly property string iconSource: AppIdentity.iconPath(root.entry, root.appId)

    // The design draws two-letter placeholders in the tiles ("Fi", "St", "Kd"),
    // so when there is no icon we can fall back to exactly what it drew.
    readonly property string initials: root.appName.slice(0, 2)

    // ---- what a click does ---------------------------------------------------

    function launch(): void {
        if (root.entry) {
            // ONE PROGRAM ON THE MACHINE CANNOT BE STARTED THE ORDINARY WAY.
            // GNOME's Settings app reads XDG_CURRENT_DESKTOP and exits at once
            // unless it says GNOME, which in an Aquarius session it deliberately
            // does not — so running its .desktop entry, which is all
            // `execute()` does, gets a tile that flashes and nothing else. That
            // is the dock half of the bench report on 2026-09-06 ("Nor does its
            // icon in the dock"). services/SettingsLauncher.qml holds both the
            // fact and the fix; the dock only asks whether this is that entry,
            // so no per-app knowledge lands in here. Every other entry on the
            // machine takes the ordinary road below.
            if (SettingsLauncher.ownsDesktopEntry(root.entry)) {
                SettingsLauncher.open("");
                return;
            }
            root.entry.execute();
        } else {
            // No .desktop entry means no command to run. This can only happen
            // for a tile that exists BECAUSE something is running, so there is
            // nothing sensible to launch and saying so is better than silence.
            console.warn("aquarius-shell: dock has no launcher for", root.appId);
        }
    }

    function activate(): void {
        const open = root.windows;

        if (open.length === 0) {
            root.launch();
            return;
        }

        if (open.length === 1) {
            const only = open[0];
            if (only.activated && !only.minimized) {
                only.minimized = true;
            } else {
                only.minimized = false;
                only.activate();
            }
            return;
        }

        // Several windows: step to the one after whichever is focused. If none
        // of them is focused, index -1 + 1 lands on the first, which is right.
        let current = -1;
        for (let i = 0; i < open.length; i++) {
            if (open[i].activated) {
                current = i;
                break;
            }
        }
        const next = open[(current + 1) % open.length];
        next.minimized = false;
        next.activate();
    }

    // Close every window this app owns.
    //
    // `slice()` first: closing a window makes the compositor drop it, which
    // rebuilds the list this loop is walking. Iterating the live one would skip
    // windows — the classic "delete while iterating" bug, and on a five-window
    // app it would leave two or three of them open, which reads as Quit being
    // unreliable rather than as a bug in a loop.
    //
    // close() is a REQUEST (see the header). An app with unsaved work may put up
    // a dialog and stay open, and that is right.
    function quitAll(): void {
        const open = root.windows.slice();
        for (let i = 0; i < open.length; i++) {
            if (open[i])
                open[i].close();
        }
    }

    // ---- geometry ------------------------------------------------------------
    // The item is exactly one tile. The dots hang BELOW it, outside these
    // bounds, into the dock's bottom padding — nothing clips them, and the
    // padding was measured with room for them. See Theme's dock block.
    implicitWidth: Theme.dockTileSize
    implicitHeight: Theme.dockTileSize

    Accessible.role: Accessible.Button
    Accessible.name: root.appName
    Accessible.description: root.running
        ? qsTr("%n window(s) open", "", root.windows.length)
        : qsTr("Not running")

    // ---- the tile, which is the part that lifts -------------------------------
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

        // THERE IS NO TILE SURFACE. THIS IS DELIBERATE — 2026-09-04.
        //   Until today each tile painted its own recessed pane: Theme.surfaceAlt
        //   with a hairline of Theme.line around it, straight off the V2
        //   artboard. On the bench, on a 55" screen, that read as a row of
        //   little boxes with icons trapped inside them rather than as a row of
        //   icons — six visible outlines competing with the six pieces of
        //   artwork they were supposed to be framing, and the dock's own slab
        //   already drawing the only frame the group needs. Royce called it and
        //   he is right: "remove the clear borders around the apps in the dock".
        //
        //   So the icon sits on the slab, and the slab is the box. This is what
        //   every dock people already use does — macOS, the GNOME dash, Latte —
        //   for the same reason: an app icon is artwork somebody designed to be
        //   looked at, and a second outline around it is noise.
        //
        //   NOTHING WAS LOST. The tile still lifts and grows on hover, still
        //   flashes on press (below), and still carries its running dot; those
        //   are the three things the surface was NOT doing. And this is a
        //   subtraction, not a new opinion — the tile's radius token stays
        //   because the press wash and the "+" tile still shape themselves to
        //   it, so putting the surface back is one Rectangle.

        // Pressed feedback. The design has none — a web mock rarely does — but
        // a dock that does not acknowledge the mouse going down feels broken.
        // The same wash the top bar uses when a bar item is pressed.
        Rectangle {
            anchors.fill: parent
            radius: Theme.dockTileRadius
            color: Theme.pressWash
            visible: pointer.pressed
        }

        IconImage {
            id: icon

            anchors.centerIn: parent
            implicitSize: Theme.dockTileSize - Theme.dockTileInset * 2
            source: root.iconSource
            asynchronous: true
            visible: root.iconSource !== ""
        }

        // The two-letter fallback, drawn exactly as the design draws it.
        Text {
            anchors.centerIn: parent
            visible: !icon.visible
            text: root.initials
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.dockGlyphSize
            font.weight: Font.DemiBold      // the design's 600
            color: Theme.ink
            textFormat: Text.PlainText
        }
    }

    // ---- the running dots, centred under the tile ----------------------------
    Row {
        id: dots

        // Centred on the ITEM, not on the tile — the tile moves when hovered
        // and the dots stay put. Anchoring to the item is what keeps them still.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: Theme.dockDotGap

        spacing: Theme.dockDotGap
        visible: root.running

        Repeater {
            // At most three. Beyond that the row of dots would be wider than
            // the tile it belongs to and stop reading as a mark under an icon.
            model: Math.min(root.windows.length, 3)

            delegate: Rectangle {
                width: Theme.dockDotSize
                height: Theme.dockDotSize
                radius: Theme.dockDotSize / 2

                // Focused app: the accent. Open but not focused: the quiet ink.
                //
                // These used to be ONE colour at two opacities (0.55 and 0.8,
                // the Plasma theme's numbers). That worked while the dot had a
                // slab-bordered tile above it doing half the talking. With the
                // tiles gone the dot is the whole message, and a 55%-opaque
                // accent dot on Ice's near-white panel measures 1.9:1 — a mark
                // you cannot see from a sofa. Both states are solid now and the
                // hue carries the difference; the arithmetic, and the contrast
                // each state lands at on each theme, is in Theme.qml where the
                // two tokens used to be.
                color: root.active ? Theme.accent : Theme.inkMute
            }
        }
    }

    MouseArea {
        id: pointer

        // Fills the ITEM, not the tile. If it followed the lift, the pointer
        // would leave it the instant the tile moved, the tile would drop, and
        // the whole thing would judder. It must not move.
        anchors.fill: parent

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root.toggleMenu();
            else if (mouse.button === Qt.MiddleButton)
                root.launch();
            else
                root.activate();
        }
    }

    // =========================================================================
    // The right-click menu
    // =========================================================================
    // Built the same way the Aquarius menu is: a plain array of rows, drawn by
    // one Repeater of MenuRow. `separator: true` is a rule rather than a row you
    // can land on; `disabled` greys a row and makes it ignore the mouse.
    //
    // The rows are a BINDING, not a list built once when the menu opens, so a
    // menu that is on screen when the last window closes loses its Quit item
    // instead of offering one that would do nothing.
    readonly property var menuItems: {
        const out = [];

        // The app's name, as a quiet header, so the menu says what it is about.
        // Exactly what the drive menu does with the volume's name.
        out.push({ id: "header", title: root.appName, disabled: true });
        out.push({ separator: true });

        if (root.entry) {
            // "Open" reads wrong for an app that is already open, and "New
            // Window" reads wrong for one that is not. Both run the same thing.
            out.push({
                id: "launch",
                title: root.running ? qsTr("New Window") : qsTr("Open")
            });

            if (root.canPin) {
                out.push({
                    id: root.pinned ? "unpin" : "pin",
                    title: root.pinned ? qsTr("Remove from Dock")
                                       : qsTr("Keep in Dock")
                });
            }

            if (root.running)
                out.push({ separator: true });
        }

        // Nothing to quit when nothing is running, and an item that cannot do
        // anything is worse than an item that is not there.
        if (root.running)
            out.push({ id: "quit", title: qsTr("Quit") });

        return out;
    }

    function runMenu(id: string): void {
        if (id === "launch") {
            // The same road the left and middle buttons take, so the one
            // app-specific fact in the shell — that GNOME's Settings has to be
            // started with an altered environment — is applied here without this
            // menu knowing it exists. See launch(), above.
            root.launch();
        } else if (id === "pin") {
            if (root.canPin)
                root.config.pin(root.pinId);
        } else if (id === "unpin") {
            if (root.canPin)
                root.config.unpin(root.pinId);
        } else if (id === "quit") {
            root.quitAll();
        }
    }

    // ---- opening and closing -------------------------------------------------
    // ⚠️ THE CLICK-THE-TILE-AGAIN-TO-CLOSE PROBLEM, which is not ours and is
    // well known. `grabFocus: true` asks the compositor to dismiss the popup
    // when the user clicks anywhere outside it — and the tile that opened it is
    // "outside". So a second right-click closes the menu (compositor) and then
    // immediately reopens it (this file), and the menu appears never to close.
    //
    // The fix is the one QuickSettingsPopup.qml already uses and documents:
    // remember when the popup last dismissed itself and ignore an open request
    // that arrives within a few frames of that. It is a heuristic, not a
    // protocol, and it is on the unproven list until a real compositor has been
    // in front of it.
    property double lastDismissedAt: 0
    readonly property int reopenGuardMs: 250

    function openMenu(): void {
        if (appMenu.visible)
            return;
        if (Date.now() - root.lastDismissedAt < root.reopenGuardMs)
            return;

        // Before the surface goes up, so anything else holding the keyboard has
        // already let go by the time this asks the compositor for its grab.
        Overlays.claim(root);
        appMenu.visible = true;
    }

    function closeMenu(): void {
        appMenu.visible = false;
    }

    function toggleMenu(): void {
        if (appMenu.visible)
            root.closeMenu();
        else
            root.openMenu();
    }

    // ---- one overlay at a time ----------------------------------------------
    // Per INSTANCE, and there is one instance per app per monitor, which is
    // exactly why services/Overlays.qml keeps a list rather than a single "which
    // one is open" string. Unregistering is not optional: Variants destroys a
    // screen's docks when that monitor is unplugged, and a closer left behind
    // would be called on a destroyed object.
    Component.onCompleted: Overlays.register(root, () => root.closeMenu())
    Component.onDestruction: Overlays.unregister(root)

    PopupWindow {
        id: appMenu

        // Above the tile, because the dock is at the bottom of the screen —
        // the same anchor the drive menu at the other end of the dock uses.
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

        // Dismiss on a click anywhere else. See the note above for the wrinkle.
        grabFocus: true

        onVisibleChanged: {
            if (appMenu.visible) {
                menuCard.hoveredIndex = -1;
                // The keyboard, for Esc. A compositor holding a popup grab sends
                // key events to the grabbing surface, so the card can have them —
                // but this is the half of the menu NOT PROVEN on hardware, and it
                // is the half that matters least: a click anywhere else closes
                // the menu whether or not Esc is ever delivered.
                Qt.callLater(() => menuCard.forceActiveFocus());
            } else {
                root.lastDismissedAt = Date.now();
            }
        }

        Rectangle {
            id: menuCard

            // Which row the pointer is on, so a row lights under the mouse the
            // way the Aquarius menu's rows do. -1 is none.
            property int hoveredIndex: -1

            // Fixed width, the same reasoning as LogoMenu's card and the drive
            // menu's: a width derived from the rows would have the Column and
            // the rows sizing each other. A long app name elides.
            implicitWidth: Theme.logoMenuMinWidth
            implicitHeight: menuCol.implicitHeight + Theme.logoMenuPaddingV * 2

            radius: Theme.logoMenuRadius
            color: Theme.surface
            border.width: Theme.hairline
            // A stronger hairline stands in for the design's drop shadow — the
            // same call every other card in this shell makes.
            border.color: Theme.lineStrong

            focus: true

            Keys.onEscapePressed: root.closeMenu()

            Column {
                id: menuCol

                x: 0
                y: Theme.logoMenuPaddingV
                width: menuCard.implicitWidth
                spacing: 0

                Repeater {
                    model: root.menuItems

                    delegate: MenuRow {
                        required property int index
                        required property var modelData

                        width: menuCol.width

                        isSeparator: modelData.separator === true
                        disabled: modelData.disabled === true
                        label: modelData.title !== undefined ? modelData.title : ""
                        selected: index === menuCard.hoveredIndex

                        onHovered: menuCard.hoveredIndex = index
                        onActivated: {
                            // Close FIRST. Quit and the pin toggle both change
                            // the very things this menu is drawn from — the
                            // window list, and whether this tile exists at all —
                            // and a menu that is still on screen while its own
                            // tile is being taken out from under it is a menu
                            // hanging in mid-air.
                            root.closeMenu();
                            root.runMenu(modelData.id !== undefined
                                         ? modelData.id : "");
                        }
                    }
                }
            }
        }
    }
}
