// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SearchField — the one box, and the magnifier next to it
// =============================================================================
// The whole premise of Flow Search is in this file: there is ONE input, it has
// no prefix, no mode, no colon-command, and nothing you have to learn. You type
// what you want. Working out what that was is SearchEngine.qml's job, not the
// person's.
//
//   ⌕  kd|
//   ─────────────────────────────────────────────────────
//
// WHY TextInput AND NOT TextField
//   TextField comes from QtQuick.Controls, which brings a whole style engine
//   with it and then has to be argued out of drawing its own background,
//   placeholder and focus ring in somebody else's design language. TextInput is
//   the plain one: a cursor, a string, and no opinions. Everything visible here
//   is ours and comes from Theme.
//
// THE MAGNIFIER
//   Drawn with QtQuick.Shapes from the design's own SVG, the same way
//   components/bar/LogoMark.qml does and for the same reason — Qt's SVG
//   renderer cannot follow the `stroke` colour we want, but a Shape takes a
//   theme colour and repaints when the theme changes. The design's icon is:
//
//     <circle cx="11" cy="11" r="7"/>   <path d="M20 20l-4-4"/>
//
//   drawn on a 24x24 grid with a 2.2-wide round-capped stroke. The circle is
//   written below as the two half-arcs an SVG circle expands into, because
//   PathSvg is the one path type this repo has already proven it can spell.
// =============================================================================
import QtQuick
import QtQuick.Shapes

import "../../theme"

Item {
    id: root

    // The text in the box. Two-way: the palette clears it on open, the person
    // changes it by typing.
    property alias text: input.text

    // Shown in the quiet ink when the box is empty.
    property string placeholder: qsTr("Search apps, do sums, run actions")

    // Raised for the keys this field does not handle itself, so the palette can
    // move the selection and act on it without stealing focus from the input.
    signal moveSelection(int delta)
    signal accept()
    signal dismiss()

    implicitHeight: Math.max(glass.height, input.implicitHeight)
        + Theme.searchFieldPaddingV * 2

    function takeFocus() {
        input.forceActiveFocus();
    }

    // ---- the magnifier ---------------------------------------------------------
    Item {
        id: glass

        anchors.left: parent.left
        anchors.leftMargin: Theme.searchFieldPaddingH
        anchors.verticalCenter: parent.verticalCenter

        width: Theme.searchIconSize
        height: Theme.searchIconSize

        Shape {
            width: 24
            height: 24
            anchors.centerIn: parent
            scale: Theme.searchIconSize / 24
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            // The lens.
            ShapePath {
                strokeColor: Theme.accent
                fillColor: "transparent"
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M4 11a7 7 0 1 0 14 0a7 7 0 1 0 -14 0" }
            }

            // The handle.
            ShapePath {
                strokeColor: Theme.accent
                fillColor: "transparent"
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M20 20l-4-4" }
            }
        }
    }

    // ---- the box ------------------------------------------------------------------
    TextInput {
        id: input

        anchors.left: glass.right
        anchors.leftMargin: Theme.searchFieldGap
        anchors.right: parent.right
        anchors.rightMargin: Theme.searchFieldPaddingH
        anchors.verticalCenter: parent.verticalCenter

        font.family: Theme.fontBody
        font.pixelSize: Theme.fsSubhead        // design 17px; the ladder's nearest step
        color: Theme.ink
        selectionColor: Theme.accentWash
        selectedTextColor: Theme.ink

        // One line, no rich text, no newlines to worry about.
        activeFocusOnPress: true
        selectByMouse: true
        clip: true

        Accessible.role: Accessible.EditableText
        Accessible.name: qsTr("Search")
        Accessible.description: root.placeholder

        // The keys the LIST owns rather than the box. Handled here because this
        // is where focus lives — moving focus to the list on every arrow press
        // would mean the person could no longer type, which is the opposite of
        // what a search box is for.
        //
        // Everything not named below falls through to TextInput untouched, so
        // Home, End, word-jumps, selection and undo all still work.
        //
        // Each handler names its `event` parameter and accepts it. Both matter:
        // Qt 6 warns about handlers that use the implicit `event`, and an
        // unaccepted arrow key carries on to Qt's focus navigation, which in a
        // window with one focusable item means focus quietly goes nowhere and
        // typing stops.
        Keys.onUpPressed: event => { root.moveSelection(-1); event.accepted = true; }
        Keys.onDownPressed: event => { root.moveSelection(1); event.accepted = true; }
        Keys.onEscapePressed: event => { root.dismiss(); event.accepted = true; }
        Keys.onReturnPressed: event => { root.accept(); event.accepted = true; }
        Keys.onEnterPressed: event => { root.accept(); event.accepted = true; }

        // Tab walks the list too. In a palette there is nowhere else for focus
        // to go, so the usual "move to the next control" would just lose it.
        Keys.onTabPressed: event => { root.moveSelection(1); event.accepted = true; }
        Keys.onBacktabPressed: event => { root.moveSelection(-1); event.accepted = true; }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            visible: input.text.length === 0
            text: root.placeholder
            font: input.font
            color: Theme.inkMute
            textFormat: Text.PlainText
        }
    }
}
