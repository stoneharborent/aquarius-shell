// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// TileFocus — do-not-disturb, shared with the notification pipeline
// =============================================================================
// ⚠️ THIS TILE OWNS NO STATE. IT READS AND WRITES services/FocusState.qml.
//
//   Focus is one switch with two faces: this tile turns it on, and the
//   notification server consults it before showing a toast. If each of those
//   kept its own boolean, the desktop would end up in the state where the panel
//   says Focus is on and the toasts keep arriving — the single most common bug
//   in do-not-disturb implementations, and the reason services/FocusState.qml
//   exists as a singleton rather than as a property on somebody's component.
//
//   The notifications track owns that file's evolution (persistence, the
//   until-morning schedule). This tile only calls `toggle()` and reads
//   `enabled`. Do not add Focus state here, and do not read it from anywhere
//   else either — tests/test-shell.sh checks that no second copy appears.
//
// WHY THERE IS NO "UNAVAILABLE" STATE
//   The KDE version dimmed this tile when KDE's notification server was not
//   running, because that server was the thing holding the state. Here the state
//   is ours and it exists whether or not anything is listening to it, so the
//   tile always works. What it CANNOT yet do is stop a notification, because the
//   notification server does not exist yet — that is the notifications track's
//   P2 work, and it consumes this same singleton. Said plainly in
//   docs/quick-settings.md rather than pretended away with a fake availability
//   check.
//
// WHICH WAY ROUND THE SUBTITLE READS
//   The design puts "Notifications on" under an UNLIT Focus tile. That is
//   deliberate and it is kept: the subtitle describes the state of your
//   NOTIFICATIONS, not the state of the tile. It is the thing a person actually
//   wants to know at a glance, and inverting it to "Focus off" would say the
//   same thing twice.
// =============================================================================
import QtQuick

import "../../services"

QsTile {
    id: root

    title: qsTr("Focus")
    glyph: "moon"

    available: true
    active: FocusState.enabled

    subtitle: root.active ? qsTr("Notifications off") : qsTr("Notifications on")

    onActivated: FocusState.toggle()
}
