// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// StatusGlyphSound — the sound glyph in the top bar
// =============================================================================
// A read-only mirror of the same PipeWire default sink the Quick Settings Sound
// slider drives. It shows one thing: whether sound is muted.
//
// ⚠️ THE PwObjectTracker BELOW IS NOT OPTIONAL. `PwNodeAudio.muted` is
// documented as invalid unless the node is bound, and an unbound node reports a
// resting value with no warning at all. Without those three lines this glyph
// would say "not muted" forever. The same trap is written up at length in
// SliderVolume.qml.
//
// WHY IT IS ONLY MUTED / NOT MUTED, AND NOT A THREE-STEP VOLUME LADDER
//   The design's bar has no sound glyph at all — it shows Drop, Search, Wi-Fi
//   and battery — so everything about this one is an addition. An addition
//   should be the smallest one that earns its place. "Is my machine silent" is
//   the question a bar can answer at a glance and the one people actually get
//   caught out by; "am I at 40% or 60%" is what the panel is for.
// =============================================================================
import QtQuick

import Quickshell.Services.Pipewire

import "../../theme"

QsGlyph {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: root.sink !== null ? root.sink.audio : null

    readonly property bool silent:
        root.sinkAudio === null || root.sinkAudio.muted || root.sinkAudio.volume === 0

    glyph: root.silent ? "speaker-mute" : "speaker"
    size: Theme.barGlyphSize
    color: root.silent ? Theme.inkMute : Theme.ink

    Accessible.role: Accessible.StaticText
    Accessible.name: root.silent ? qsTr("Sound muted") : qsTr("Sound on")

    // See the warning at the top. Three lines, and the glyph is dead without
    // them.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
}
