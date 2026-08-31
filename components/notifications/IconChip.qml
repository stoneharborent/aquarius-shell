// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// IconChip — the rounded square at the left of a notification
// =============================================================================
// The design (class `.ni` in the V2 shell artboard): 34x34, 9px corners, a quiet
// box with something identifying inside it.
//
//     ┌──────┐
//     │ icon │   34 x 34, radius 9, a wash of the ink colour
//     └──────┘
//
// THREE THINGS CAN GO IN IT, IN THIS ORDER OF PREFERENCE
//
//   1. THE NOTIFICATION'S OWN PICTURE. A screenshot thumbnail, an album cover,
//      the avatar of whoever messaged you. Quickshell hands this over as
//      `Notification.image`, already resolved to something an Image can load —
//      raw pixel data sent over D-Bus becomes an `image://` URL, a file path
//      stays a file path. It is used AS IS; we never go and fetch anything.
//
//   2. THE SENDING APPLICATION'S ICON. `Notification.appIcon` is an icon NAME
//      most of the time ("firefox", "org.gnome.Screenshot"), which has to be
//      looked up in the current icon theme before it means anything. That is
//      what `Quickshell.iconPath(name, true)` does; the `true` asks it to return
//      an empty string when the icon does not exist rather than the pink
//      missing-texture square, which is what lets us fall through to (3).
//
//      Some applications send a path or a file: URL in that field instead. Both
//      shapes are recognised below rather than being passed to the theme lookup,
//      where they would simply fail.
//
//   3. THE FIRST LETTERS OF ITS NAME. Drawn in the accent colour, which is
//      exactly what the design does for the chat application in the artboard
//      (`<span class="ni" style="color:#D678E8">Ds</span>`). A notification with
//      no icon at all still gets something you can tell apart at a glance.
//
// WHY ClippingRectangle AND NOT Rectangle
//   A photograph dropped into a rounded box has to be cut to that rounding, and
//   plain Rectangle does not clip its children to its own corners. Quickshell's
//   ClippingRectangle does. It needs Qt 6.7 or newer, which Fedora 42 and up
//   satisfy comfortably.
//   https://quickshell.org/docs/v0.3.1/types/Quickshell.Widgets/ClippingRectangle/
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Widgets

import "../../theme"

ClippingRectangle {
    id: root

    // The Notification this chip belongs to — the usual way to drive it.
    property var notification: null

    // The other way, for a place that has an icon name and an application name
    // but no single notification behind them: the header of a group. Ignored
    // whenever `notification` is set.
    property string iconName: ""
    property string label: ""

    // Chips are the design's 34px in the panel; a caller may ask for smaller.
    property int size: Theme.notifChipSize

    // Whether to paint the rounded box behind the icon. On a group header the
    // icon sits on the panel itself and a box around it would read as a second
    // notification rather than as a label.
    property bool chrome: true

    // The glyph inside is drawn in the accent colour, except on a critical
    // notification where it takes the danger colour instead.
    property color tint: Theme.accent

    implicitWidth: root.size
    implicitHeight: root.size
    radius: Theme.radiusMd
    color: root.chrome ? Theme.hoverWash : "transparent"

    // ---- 1. the notification's own picture ---------------------------------
    readonly property string imageSource: {
        if (!root.notification)
            return "";
        const image = root.notification.image;
        return image ? image : "";
    }

    // ---- 2. the sending application's icon ---------------------------------
    readonly property string iconSource: {
        const raw = root.notification ? root.notification.appIcon : root.iconName;
        if (!raw || raw.length === 0)
            return "";
        // Already a location rather than a name.
        if (raw.charAt(0) === "/")
            return "file://" + raw;
        if (raw.indexOf("://") !== -1)
            return raw;
        // A name. Look it up in whatever icon theme the session is using, and
        // take an empty answer rather than a missing-texture square.
        return Quickshell.iconPath(raw, true);
    }

    // ---- 3. the fallback -----------------------------------------------------
    readonly property string initials: {
        const name = root.notification ? root.notification.appName : root.label;
        if (!name || name.length === 0)
            return "?";
        return name.substring(0, 2);
    }

    Image {
        anchors.fill: parent
        source: root.imageSource
        visible: root.imageSource.length > 0
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // A notification image is small and arrives at whatever size the sender
        // felt like. Smoothing is the difference between a readable thumbnail
        // and a blocky one.
        smooth: true
        mipmap: true
    }

    IconImage {
        anchors.centerIn: parent
        // Inside a box, the icon is inset so the box reads as a chip. Without
        // one, it fills the space it was given. Written as a proportion rather
        // than a fixed inset because these are used at 34px and at 16px, and a
        // fixed 12px inset would leave 4 pixels of icon at the smaller size.
        implicitSize: root.chrome ? Math.round(root.size * 0.65) : root.size
        source: root.iconSource
        visible: root.imageSource.length === 0 && root.iconSource.length > 0
        asynchronous: true
    }

    Text {
        anchors.centerIn: parent
        text: root.initials
        visible: root.imageSource.length === 0 && root.iconSource.length === 0
        font.family: Theme.fontDisplay
        font.pixelSize: root.size >= Theme.notifChipSize ? Theme.fsCaption : Theme.fsMonoSm
        font.weight: Font.DemiBold
        color: root.tint
        textFormat: Text.PlainText
    }
}
