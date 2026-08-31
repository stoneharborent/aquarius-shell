// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// QsGlyph — every small line-drawn icon in the shell, in one file
// =============================================================================
// WHY THE SHELL DRAWS ITS OWN ICONS INSTEAD OF USING THE SYSTEM ICON THEME
//
//   The obvious thing is to ask the icon theme — the same way the KDE widget
//   this ports from asked Breeze for "network-wireless-on". Three reasons that
//   is the wrong call here:
//
//   1. THIS SHELL HAS NO ICON THEME OF ITS OWN, AND CANNOT ASSUME ONE. It runs
//      on a bench machine, in a nested compositor, on whatever Fedora or
//      Bazzite install happens to be there. Breeze may not be installed at all.
//      A missing icon theme name does not warn — it draws nothing, or a generic
//      placeholder, and the panel silently loses its meaning.
//
//   2. RECOLOURING IS THE PROBLEM, NOT LOADING. Quickshell's IconImage is an
//      Image; it has no `color`. Kirigami.Icon had `isMask` and that is what
//      made the KDE tiles follow the theme. Nothing equivalent exists here
//      without a shader pass, and Ice is a LIGHT theme — a dark-on-light
//      symbolic icon set is exactly the case where getting this wrong is
//      invisible on the author's machine and wrong on everybody else's.
//
//   3. THE DESIGN ALREADY DREW THEM. The V2 artboard's Quick Settings panel
//      contains the Wi-Fi, Bluetooth, Focus and Game Mode glyphs as inline SVG
//      path data. Copying that data is more faithful than picking the nearest
//      Breeze name, which is what the Plasma port had to do.
//
//   So: the same choice LogoMark.qml made, for the same reasons, generalised.
//   The paths take Theme colours and repaint instantly when the theme flips.
//
// WHERE THE PATH DATA COMES FROM — read this before editing any of it
//
//   Everything marked "V2" below is copied character for character out of
//   os-image/branding/design-system/"AquariusOS Desktop Shell.html" (the
//   `#ovTray` block). That file is READ-ONLY from this repo's point of view.
//   If a glyph needs to change, it changes in the design system first.
//
//   Everything marked "ours" is a glyph the V2 mock never drew — the mock shows
//   one happy state per tile and no bar cluster at all. Those are drawn here in
//   the same weight and on the same grid so they sit beside the copied ones
//   without looking like a different set. They are a design decision this file
//   is making, and they are labelled so that is obvious.
//
// HOW TO USE IT
//   QsGlyph { glyph: "wifi"; size: Theme.qsChipGlyphSize; color: Theme.ink }
//
//   `size` is the LONGEST side. The glyph keeps the aspect ratio of its own
//   drawing grid, so a 16x12 Wi-Fi fan at size 15 is 15 wide and 11 tall, and
//   sits in the middle of whatever contains it.
//
//   An unknown name draws nothing rather than throwing. tests/test-shell.sh
//   checks that every name used anywhere in components/ exists in the table
//   below, which is the check that actually catches the typo.
// =============================================================================
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    // Which glyph. Must be a key of `art` below.
    property string glyph: ""

    // The longest side, in pixels.
    property int size: 15

    // What colour to draw it in. Always a Theme role at the call site.
    property color color: "transparent"

    // =========================================================================
    // THE GLYPH TABLE
    // =========================================================================
    // Each entry is:
    //   w, h   the drawing grid the paths were drawn on (the SVG viewBox)
    //   s      stroke width on that grid
    //   p      up to three stroked paths
    //   f      one filled path, or absent (used for the Wi-Fi dot)
    //
    // Three stroked paths is not a design principle, it is a QML limitation:
    // a Repeater cannot build ShapePaths (they are not Items) and an
    // Instantiator would have to reparent them by hand. Three fixed slots is
    // the honest, boring way to do it, and no glyph here needs a fourth.
    readonly property var art: ({
        // --- V2: <svg width="15" height="11" viewBox="0 0 16 12"> -------------
        // Three arcs and a dot: the radio-fan Wi-Fi mark.
        "wifi": {
            w: 16, h: 12, s: 1.5,
            p: ["M1.5 4.5a9.5 9.5 0 0 1 13 0M4 7.2a6 6 0 0 1 8 0M6.5 9.8a2.6 2.6 0 0 1 3 0"],
            f: "M7 11a1 1 0 1 0 2 0 1 1 0 1 0-2 0"
        },

        // --- ours -------------------------------------------------------------
        // The V2 mock only ever drew Wi-Fi switched ON. Off is the innermost arc
        // and the dot — the fan collapsed to nothing — with a slash across it.
        // Same grid, same stroke, so the two states are the same drawing.
        "wifi-off": {
            w: 16, h: 12, s: 1.5,
            p: ["M6.5 9.8a2.6 2.6 0 0 1 3 0", "M2.2 1.6 13.8 10.8"],
            f: "M7 11a1 1 0 1 0 2 0 1 1 0 1 0-2 0"
        },

        // --- V2: <svg width="9" height="14" viewBox="0 0 12 18"> ---------------
        // The Bluetooth rune, in one stroke.
        "bluetooth": {
            w: 12, h: 18, s: 1.6,
            p: ["M3 4.5 9 13l-3 3V2l3 3-6 8.5"]
        },

        // --- ours: the rune plus a slash ---------------------------------------
        "bluetooth-off": {
            w: 12, h: 18, s: 1.6,
            p: ["M3 4.5 9 13l-3 3V2l3 3-6 8.5", "M1.5 2.4 10.5 15.6"]
        },

        // --- V2: <svg width="14" height="14" viewBox="0 0 24 24"> --------------
        // The crescent moon: Focus / do not disturb.
        "moon": {
            w: 24, h: 24, s: 1.8,
            p: ["M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"]
        },

        // --- V2: <svg width="14" height="14" viewBox="0 0 24 24"> --------------
        // The game controller.
        "gamepad": {
            w: 24, h: 24, s: 1.8,
            p: [
                "M17.3 5H6.7a4.7 4.7 0 0 0-4.6 4L1.3 14a3 3 0 0 0 5.2 2.4L8.6 14h6.8l2.1 2.4A3 3 0 0 0 22.7 14l-.8-5a4.7 4.7 0 0 0-4.6-4z",
                "M6 9h4M8 7v4"
            ]
        },

        // --- ours ---------------------------------------------------------------
        // The V2 mock's fourth tile is Game Mode, which only exists on a handheld.
        // On a desktop that slot becomes the power profile, and the design has no
        // drawing for it. A dial with a needle is the conventional reading of
        // "performance" and it is drawn here on the same 24-grid at the same
        // weight. See TilePowerProfile.qml for why the tile is adaptive at all.
        "speedometer": {
            w: 24, h: 24, s: 1.8,
            p: ["M3.5 17.5a9.5 9.5 0 1 1 17 0", "M12 15.5 16.8 9"]
        },

        // --- ours ---------------------------------------------------------------
        // The bar's sound glyph. The V2 bar has no sound icon at all — its bar
        // shows Drop, Search, Wi-Fi and battery — so this is new, drawn on a
        // 16-grid to sit beside the 16x12 Wi-Fi fan.
        "speaker": {
            w: 16, h: 16, s: 1.5,
            p: ["M8.6 3 5.1 6.2H2.4v3.6h2.7L8.6 13z", "M11.2 6.1a3.4 3.4 0 0 1 0 3.8"]
        },
        "speaker-mute": {
            w: 16, h: 16, s: 1.5,
            p: ["M8.6 3 5.1 6.2H2.4v3.6h2.7L8.6 13z", "M11.2 6.4 14.4 9.6M14.4 6.4 11.2 9.6"]
        }
    })

    // The entry in force, or a blank one for an unknown name. Drawing nothing is
    // the right failure: a wrong glyph is a lie, a missing glyph is a gap you
    // can see. The test catches the typo before it gets this far.
    readonly property var blank: ({ w: 1, h: 1, s: 0, p: [] })
    readonly property var current: root.art[root.glyph] !== undefined
        ? root.art[root.glyph]
        : root.blank

    // A moveto with nothing after it draws nothing, which is how the unused
    // path slots stay quiet without QML having to reason about empty strings.
    readonly property string noPath: "M0 0"

    readonly property real longestSide: Math.max(root.current.w, root.current.h)
    readonly property real drawScale: root.size / root.longestSide

    implicitWidth: Math.round(root.current.w * root.drawScale)
    implicitHeight: Math.round(root.current.h * root.drawScale)

    Shape {
        // Drawn at the design's own grid size and shrunk, the same way
        // LogoMark.qml does it: curves stay smooth at any size, including on a
        // HiDPI screen, because the shrink happens in the renderer.
        width: root.current.w
        height: root.current.h
        anchors.centerIn: parent
        scale: root.drawScale
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.current.s
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.current.p.length > 0 ? root.current.p[0] : root.noPath }
        }

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.current.s
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.current.p.length > 1 ? root.current.p[1] : root.noPath }
        }

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.current.s
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.current.p.length > 2 ? root.current.p[2] : root.noPath }
        }

        // The one filled shape any glyph needs: the dot under the Wi-Fi fan.
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillColor: root.color
            PathSvg {
                path: root.current.f !== undefined ? root.current.f : root.noPath
            }
        }
    }
}
