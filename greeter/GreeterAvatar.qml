// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// GreeterAvatar — the round mark that stands for a person
// =============================================================================
// A circle in the Aquarius blue with the person's initials in it. "Royce
// Adkins" gives RA.
//
// ⚠️ IT DOES NOT SHOW THE PHOTOGRAPH FROM SETTINGS > USERS, AND THAT IS A
// DECISION, NOT AN OVERSIGHT. Here is the reasoning, so nobody has to work it
// out again:
//
//   1. Those photographs are plain files under /var/lib/AccountsService/icons/,
//      and across every Linux distribution they have a long history of ending
//      up with permissions a login screen cannot read. A silently missing
//      picture is the single most reported bug in this area.
//   2. Making a square photograph round in Qt needs either an effects module
//      this shell does not otherwise import or a hand-written shader. Adding an
//      import for a decoration means that if that module is ever missing, the
//      WHOLE LOGIN SCREEN fails to load — and a login screen that does not
//      appear is not a computer you can use. That is a bad trade for a round
//      picture.
//   3. Initials are never missing, never unreadable, and tell two accounts
//      apart at a glance, which is the entire job.
//
// aquarius-greeter-info already reports where each person's picture is, so the
// day this is worth doing, the information is already here and this is the only
// file that changes.
// =============================================================================
import QtQuick

import "../theme"

Item {
    id: root

    // The person, exactly as GreeterState hands them over: { name, real, icon }.
    // Null is allowed and draws an empty circle — which is what the screen looks
    // like for the half-second before the list of accounts has been read.
    property var person: null

    // How big the circle is. The card uses the big one, the list of people the
    // small one, and the letters inside scale with it.
    property int size: Theme.greeterAvatarSize
    property int glyphSize: Theme.greeterAvatarGlyphSize

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property string initials: {
        if (root.person === null)
            return "";
        const words = String(root.person.real || root.person.name || "")
            .trim().split(/\s+/).filter(word => word.length > 0);
        if (words.length === 0)
            return "";
        if (words.length === 1)
            return words[0].charAt(0).toUpperCase();
        return (words[0].charAt(0) + words[1].charAt(0)).toUpperCase();
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.accentWash
        border.width: Theme.hairline
        border.color: Theme.lineStrong

        Text {
            anchors.centerIn: parent
            text: root.initials
            color: Theme.accent
            font.family: Theme.fontDisplay
            font.pixelSize: root.glyphSize
            font.weight: Font.DemiBold
            textFormat: Text.PlainText
        }
    }
}
