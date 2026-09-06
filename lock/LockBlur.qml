// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LockBlur — the one file in this shell that imports QtQuick.Effects
// =============================================================================
// WHY THIS IS A FILE OF ITS OWN, FOR FOUR LINES OF QML
//
// A blur in Qt needs `QtQuick.Effects`, and an import that fails does not fail
// quietly: the WHOLE FILE that contains it refuses to load. Everywhere else in
// this shell that would have been a shrug — the panel draws without its shadow
// (see components/search/FlowSearch.qml), the slider dot draws without its
// glow. Here it would not be a shrug. A lock screen whose QML will not load is
// a screen the compositor covers in a flat colour and never lets go of, and
// the way out of that is the power button.
//
// So the import lives HERE, alone, and LockVeil.qml pulls this file in through
// a Loader. A Loader that cannot load its file reports `Loader.Error` and
// carries on; the veil then falls back to the unblurred wallpaper under a
// heavier wash, which is a slightly worse-looking lock screen rather than an
// unusable computer.
//
// Is that likely? No. Fedora 44 ships Qt 6.10, and `QtQuick.Effects` has been
// part of Qt since 6.5 — the build the operating system installs has it, and
// the image build checks for the folder by name. The Loader is here for the
// other cases: the nested harness on somebody else's machine, a plain Fedora
// clone, a future Qt that moves it. On a lock screen, "unlikely" is not the
// same as "cannot happen".
//
// -----------------------------------------------------------------------------
// HOW MultiEffect BLURS SOMETHING
// -----------------------------------------------------------------------------
// It does not blur what is behind it — nothing in Qt does. It takes another
// item as its `source`, renders that item off-screen, and draws the blurred
// result in its own place. So the wallpaper picture in LockVeil.qml is made
// invisible and handed to this, which draws it instead.
//
//   blurEnabled  turn it on at all
//   blur         0 to 1 — how much of the maximum to use. 1 is all of it.
//   blurMax      the radius, in pixels, that `blur: 1` means. This is the
//                number from the design: 18.
// =============================================================================
import QtQuick
import QtQuick.Effects

MultiEffect {
    id: root

    // The item to blur. LockVeil hands the wallpaper over once this has loaded.
    // Nothing is drawn until it does, which is correct: an unset source draws
    // nothing rather than drawing wrongly.
    property Item plate: null

    // How wide the blur is, in pixels. Passed in rather than read from Theme
    // here, so that this file has exactly one job and one reason to fail.
    property int blurWidth: 0

    source: root.plate
    blurEnabled: true
    blur: 1.0
    blurMax: root.blurWidth
}
