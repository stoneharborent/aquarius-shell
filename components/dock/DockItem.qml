// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// DockItem — one app in the dock: its tile, its icon, and its running dots
// =============================================================================
//
//        ┌────────┐            ┌────────┐   <- hovered: the whole tile rises
//        │        │            │  ICON  │      4px and grows to 108%, over
//        │  ICON  │            │        │      120ms on the design's curve
//        │        │            └────────┘
//        └────────┘                ●         <- running: a centred dot, in
//            ●                                  the accent colour
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
//   does not exist here either, so the WHOLE TILE lifts — background, border and
//   icon together — which is what the CSS actually says.
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
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Widgets

import "../../theme"

Item {
    id: root

    // One entry from DockModel.items. See that file for the shape.
    required property var modelData

    readonly property var entry: root.modelData ? root.modelData.entry : null
    readonly property var windows: root.modelData && root.modelData.windows
        ? root.modelData.windows
        : []
    readonly property string appId: root.modelData ? (root.modelData.appId || "") : ""

    readonly property bool running: root.windows.length > 0

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
        if (root.entry && root.entry.name)
            return root.entry.name;
        if (root.appId !== "")
            return root.tidyAppId(root.appId);
        return qsTr("Unknown application");
    }

    // Quickshell resolves an icon name against the icon theme Qt is using, so
    // the dock's icons match every other application on the machine. `true` as
    // the second argument means "give me an empty string if it does not exist"
    // rather than the missing-texture image — which is what lets the two-letter
    // fallback below know it is needed.
    // (https://quickshell.org/docs/v0.3.1/types/Quickshell/ - iconPath)
    readonly property string iconSource: {
        const name = root.entry && root.entry.icon ? root.entry.icon : root.appId;
        if (!name)
            return "";
        return Quickshell.iconPath(name, true);
    }

    // The design draws two-letter placeholders in the tiles ("Fi", "St", "Kd"),
    // so when there is no icon we can fall back to exactly what it drew.
    readonly property string initials: root.appName.slice(0, 2)

    // "org.gnome.Nautilus" -> "Nautilus". Only reached when the proper lookup
    // already failed. Same routine as components/bar/ActiveAppName.qml.
    function tidyAppId(id: string): string {
        const pieces = id.split(".");
        const last = pieces[pieces.length - 1];
        if (last.length === 0)
            return id;
        return last.charAt(0).toUpperCase() + last.slice(1);
    }

    // ---- what a click does ---------------------------------------------------

    function launch(): void {
        if (root.entry) {
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

        // The tile's own surface. The design paints a translucent pane with a
        // blur behind it; this shell does not do glass — the top bar dropped it
        // for the same reason (BarItem.qml, and the Plasma theme's "Glass
        // removed" note). A recessed solid surface reads the same on Ice and
        // survives being over a busy wallpaper.
        Rectangle {
            anchors.fill: parent
            radius: Theme.dockTileRadius
            color: Theme.surfaceAlt
            border.width: Theme.hairline
            border.color: Theme.line
        }

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
                color: Theme.accent

                // Focused app: the dot is at full strength. Running but not
                // focused: quieter. The two numbers are the ones the Plasma
                // theme used for its `focus` and `normal` states, kept so the
                // two docks say the same thing while both exist.
                opacity: root.active
                    ? Theme.dockDotOpacityActive
                    : Theme.dockDotOpacity
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
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: function (mouse) {
            if (mouse.button === Qt.MiddleButton)
                root.launch();
            else
                root.activate();
        }
    }
}
