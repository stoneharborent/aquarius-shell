pragma Singleton
import QtQuick
import Quickshell

// Focus (do-not-disturb) — the ONE shared switch between Quick Settings and
// the notification pipeline. Quick Settings flips it; the notification server
// consults it before showing a toast.
//
// Ownership: the notifications track owns this file's evolution (persistence,
// the until-morning schedule). Other components only read `enabled` and call
// the functions — never duplicate this state elsewhere.
Singleton {
    id: root

    // True while Focus is on: no toasts, notifications go straight to the panel.
    property bool enabled: false

    // Epoch milliseconds when Focus should switch itself back off.
    // 0 means "no schedule" — Focus stays on until turned off by hand.
    property double until: 0

    function toggle() {
        if (enabled) turnOff(); else turnOn(0);
    }

    // deadline: epoch ms to auto-disable at, or 0 for indefinite.
    function turnOn(deadline) {
        until = deadline;
        enabled = true;
    }

    function turnOff() {
        enabled = false;
        until = 0;
    }
}
