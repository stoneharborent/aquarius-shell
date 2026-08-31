// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// TilePowerProfile — "Performance", the desktop half of the adaptive 4th tile
// =============================================================================
// The design's fourth square is Game Mode. Game Mode only exists on a handheld.
// On a desktop or a laptop this file fills that square instead. QsPlatform.qml
// carries the full reasoning for why the slot is adaptive at all; the short
// version is that a gamer presses Game Mode to play and a creator presses
// Performance before a render, so the square keeps its meaning even though the
// mechanism differs.
//
// Verified against https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.UPower/:
//
//   PowerProfiles (singleton)  profile : PowerProfile        (WRITABLE)
//                              hasPerformanceProfile : bool
//                              degradationReason : PerformanceDegradationReason
//                              holds : list
//   PowerProfile               Performance | Balanced | PowerSaver
//
// Present in Quickshell v0.2.1 as well as v0.3.1.
//
// TWO THINGS THE PLASMA VERSION HAD THAT QUICKSHELL DOES NOT EXPOSE
//
//   1. `isTlpInstalled`. If somebody installs TLP it takes over power management
//      and power-profiles-daemon's settings are ignored. The Plasma applet
//      detected that and disabled its own control. Quickshell has no equivalent
//      property, so this tile cannot detect it and will offer a switch that TLP
//      quietly overrides. On the list in docs/quick-settings.md; not worth a
//      hand-rolled D-Bus probe for a case that does not arise on Bazzite, which
//      ships power-profiles-daemon and not TLP.
//
//   2. `configuredProfile` — the user's own idea of "normal". The Plasma tile
//      returned to that rather than hardcoding Balanced, so a person who runs
//      Power Saver as their normal state did not get quietly promoted every time
//      they used the tile. Quickshell does not expose it, so this file remembers
//      what the profile was when it was switched to Performance and puts it
//      back. That is better than hardcoding Balanced and worse than knowing the
//      user's preference — it is forgotten when the shell reloads, and then
//      Balanced is the fallback.
// =============================================================================
import QtQuick

import Quickshell.Services.UPower

QsTile {
    id: root

    title: qsTr("Performance")

    // A machine with no supported CPU scaling driver runs power-profiles-daemon
    // with a placeholder that offers "balanced" and nothing else — a switch with
    // nowhere to switch to. This property is the daemon's own answer to "can
    // this machine actually go fast", which is exactly the question.
    available: PowerProfiles.hasPerformanceProfile

    active: PowerProfiles.profile === PowerProfile.Performance

    glyph: "speedometer"

    // What to go back to when Performance is switched off. See note 2 above.
    property int restoreProfile: PowerProfile.Balanced

    subtitle: {
        if (!root.available)
            return qsTr("Unavailable");

        // power-profiles-daemon tells us when the machine is thermally or
        // electrically throttled. Saying "On" while the laptop is too hot to
        // deliver it would be a small lie, and this is the one place the user
        // can be told.
        if (root.active
                && PowerProfiles.degradationReason !== PerformanceDegradationReason.None) {
            return qsTr("On, but throttled");
        }

        switch (PowerProfiles.profile) {
        case PowerProfile.Performance: return qsTr("On");
        case PowerProfile.PowerSaver:  return qsTr("Power saver");
        default:                       return qsTr("Balanced");
        }
    }

    onActivated: {
        if (!root.available)
            return;

        if (root.active) {
            PowerProfiles.profile = root.restoreProfile;
        } else {
            root.restoreProfile = PowerProfiles.profile;
            PowerProfiles.profile = PowerProfile.Performance;
        }
    }
}
