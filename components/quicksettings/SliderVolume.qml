// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SliderVolume — the Sound slider, on PipeWire
// =============================================================================
// Verified against https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/:
//
//   Pipewire (singleton)  defaultAudioSink : PwNode   (the output in use)
//                         defaultAudioSource : PwNode (the input)
//                         nodes : ObjectModel<PwNode>
//                         ready : bool
//   PwNode                audio : PwNodeAudio   (null if not an audio node)
//   PwNodeAudio           volume : real   (WRITABLE)
//                         muted : bool    (WRITABLE)
//                         volumes, channels
//   PwObjectTracker       objects : list<QtObject>
//
// Present in Quickshell v0.2.1 as well as v0.3.1.
//
// ⚠️ THE ONE THING THAT WILL BITE ANYBODY WHO SKIPS THE DOCS
//
//   `PwNodeAudio.volume` and `.muted` are documented, in bold, as INVALID unless
//   the node is bound with a PwObjectTracker. Quickshell leaves pipewire objects
//   unbound by default and only fetches the full property set for objects you
//   have asked it to track — a deliberate cost-saving choice, since a busy
//   machine has dozens of nodes.
//
//   Without the tracker below, this slider reads zero and writes nowhere, with
//   no warning of any kind. It is the single most likely reason for "the volume
//   slider does nothing" on a first bench run, so it is called out here rather
//   than left as a mysterious four-line block.
//
// WHY defaultAudioSink AND NOT preferredDefaultAudioSink
//   `defaultAudioSink` is what PipeWire is ACTUALLY using and what applications
//   are actually playing through. `preferredDefaultAudioSink` is a hint we would
//   be giving PipeWire about what we would like the default to be. A volume
//   slider must move the thing making noise right now, so it is the former.
//
//   The docs warn that this property may briefly become null when the default
//   changes — plugging in headphones, for instance. Every read below is guarded
//   for that, and the slider hides itself rather than snapping to 0% while the
//   switch happens.
//
// WHAT IS NOT PROVEN
//   The docs do not state the RANGE of `volume`. Everything about how it is used
//   here — and how every other Quickshell shell uses it — says 0.0 to 1.0 with
//   1.0 meaning 100%. That is an assumption until the bench says otherwise, and
//   it is on the list in docs/quick-settings.md.
// =============================================================================
import QtQuick

import Quickshell.Services.Pipewire

QsSlider {
    id: root

    label: qsTr("Sound")

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: root.sink !== null ? root.sink.audio : null

    // No sink, or a sink that is not an audio node, means nothing to control.
    // The row hides itself and the panel gets shorter — unlike a tile, a missing
    // slider misaligns nothing.
    available: root.sinkAudio !== null

    // A muted machine shows the slider at zero, because that is what the volume
    // effectively is. Showing 64% next to silence is the thing people file bugs
    // about.
    value: root.available ? (root.sinkAudio.muted ? 0 : root.sinkAudio.volume) : 0

    onMoved: function (newValue) {
        if (!root.available)
            return;

        root.sinkAudio.volume = newValue;

        // Dragging to zero mutes, and dragging up off zero unmutes. Without
        // this, pulling the slider off zero on a muted machine changes the
        // number and produces no sound, which reads as a broken slider.
        root.sinkAudio.muted = (newValue === 0);
    }

    // THE FOUR LINES WITHOUT WHICH NONE OF THE ABOVE WORKS. See the note at the
    // top. The docs say the list "may contain nulls", so no guard is needed for
    // the moment the default sink is being swapped.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
}
