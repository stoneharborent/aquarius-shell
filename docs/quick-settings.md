# Quick Settings, and the bar's status cluster

*Phase P2. Written on a Mac, where none of it can be run. Read the "What is not
proven" section before believing anything else in this file.*

---

## What was built

Two things, and they are the same thing seen from two distances.

**The Quick Settings panel** — the 330px drawer the V2 design draws hanging under
the right-hand end of the bar. Four toggles in a 2x2 grid (Wi-Fi, Bluetooth,
Focus, and an adaptive fourth), two sliders (sound and brightness), and a battery
line along the bottom.

**The bar's status cluster** — the group of icons left of the clock. It used to
be three empty outlined boxes. Two of the three are now real: the system tray,
and a status button showing live Wi-Fi, sound and battery glyphs that opens the
panel. The Drop and Search slots are still placeholders, because those belong to
other P2 tracks.

```
components/quicksettings/
  QuickSettingsPanel.qml    the 330px drawer's contents
  QuickSettingsPopup.qml    that drawer as a window, anchored under the bar
  QsTile.qml                the look of one toggle — knows nothing about anything
  QsTileSlot.qml            the safety net that loads a tile (READ THIS ONE)
  QsSlider.qml              the look of one labelled slider
  QsGlyph.qml               every line-drawn icon, and where its path data came from
  QsBatteryGlyph.qml        the battery pictogram, with a fill that means something
  QsPlatform.qml            handheld or not, and therefore what the 4th tile is
  TileWifi.qml              Quickshell.Networking
  TileBluetooth.qml         Quickshell.Bluetooth
  TileFocus.qml             services/FocusState — shared, never duplicated
  TilePowerProfile.qml      Quickshell.Services.UPower (PowerProfiles)
  TileGameMode.qml          the OS seam. One command, named in one place.
  SliderVolume.qml          Quickshell.Services.Pipewire
  SliderBrightness.qml      brightnessctl. INTERIM. Read its header.
  BatteryLine.qml           Quickshell.Services.UPower (UPower.displayDevice)
  StatusGlyphNetwork.qml    the bar's Wi-Fi glyph
  StatusGlyphSound.qml      the bar's sound glyph
  StatusGlyphBattery.qml    the bar's battery glyph

components/bar/
  StatusCluster.qml         rewritten: tray + status button + the panel
  TrayItem.qml              one tray application's icon (new)
  BarItem.qml               gained a rightClicked() signal, for tray menus
  TopBar.qml                gained a quickSettingsToggled(bool) signal
```

---

## Service by service: what Quickshell actually offers

Every claim below was checked against the Quickshell documentation, not
remembered. The framework is pre-1.0 and its module list changes between
releases, so "I am fairly sure it has one of those" is not good enough here.

### Wi-Fi — **better than the roadmap expected**

The roadmap says *"NetworkManager over D-Bus"*, which read as "we will be writing
a D-Bus client by hand". We do not have to.

**`Quickshell.Networking` exists.** It is a NetworkManager-backed service with a
QML API — its own description is *"An interface to a network backend (currently
only NetworkManager)"*. So the D-Bus is somebody else's problem, and the
standardised-protocols law is satisfied the same way it is for the tray.

What is used: `Networking.wifiEnabled` (writable — the software rfkill switch),
`Networking.wifiHardwareEnabled`, `Networking.devices` walked for a device whose
`type` is `DeviceType.Wifi`, then that device's `networks` walked for the one
that is `connected`, whose `name` is the SSID.

**⚠️ It arrived in Quickshell v0.3.0.** The changelog's v0.3.0 entry is "Added
network management support", and the v0.2.1 type index has no
`Quickshell.Networking` module at all. ADR 0001 records that Fedora's
`quickshell` package is a 0.2.1 snapshot; Arch has 0.3.1. **So on a plain Fedora
box today, the Wi-Fi tile will not load.** That is the entire reason
`QsTileSlot.qml` exists — see "The quarantine pattern" below.

No `nmcli` was needed. Good.

### Bluetooth — clean, and simpler than the Plasma version

`Quickshell.Bluetooth` is present in **v0.2.1 as well as v0.3.1**.
`Bluetooth.defaultAdapter` gives an adapter with a **writable `enabled`**, a
detailed `state` (`Enabled` / `Enabling` / `Disabled` / `Disabling` / `Blocked`),
and `Bluetooth.devices` for connected device names.

This is genuinely less work than the KDE widget, which needed *two* operations to
turn Bluetooth on (clear the rfkill soft block, then power each adapter) and
silently did nothing if you only did one. Here it is one writable property, and
the rfkill case is reported as `state === Blocked` and said out loud in the
subtitle rather than swallowed.

### Battery and power profiles — exactly as advertised

`Quickshell.Services.UPower`, present in **v0.2.1 as well as v0.3.1**.

- `UPower.displayDevice` — UPower's own aggregate device, which is the right
  thing for a desktop to display and already handles two-battery machines.
  `isLaptopBattery` is the documented test for "is this a real battery", and it
  is what hides the whole battery line on a desktop tower.
- `PowerProfiles.profile` is writable, and `hasPerformanceProfile` is the
  daemon's own answer to "can this machine actually go fast".
- `degradationReason` reports thermal throttling, so the tile can say "On, but
  throttled" instead of claiming a performance mode the laptop is not delivering.

**Two things the Plasma version had that Quickshell does not expose:**

1. **`isTlpInstalled`.** If somebody installs TLP it takes over power management
   and power-profiles-daemon is ignored. The Plasma applet detected that and
   disabled its control. There is no equivalent here, so the tile will offer a
   switch TLP quietly overrides. Not worth a hand-rolled D-Bus probe for a case
   that does not arise on Bazzite, which ships power-profiles-daemon.
2. **`configuredProfile`** — the user's own idea of "normal". Without it,
   returning from Performance would mean hardcoding Balanced, which quietly
   promotes anybody who runs Power Saver as their normal state. `TilePowerProfile`
   remembers what the profile *was* when it switched to Performance and puts that
   back. That is forgotten on shell reload, and then Balanced is the fallback.

### Sound — one trap, and it is a bad one

`Quickshell.Services.Pipewire`, present in **v0.2.1 as well as v0.3.1**.
`Pipewire.defaultAudioSink` is the output actually in use; its `audio` gives a
writable `volume` and `muted`.

**⚠️ `PwNodeAudio.volume` and `.muted` are documented, in bold, as INVALID unless
the node is bound with a `PwObjectTracker`.** Quickshell leaves pipewire objects
unbound by default and only fetches the full property set for objects you have
asked it to track. Without the tracker, the slider reads zero and writes nowhere,
**with no warning of any kind**. This is the single most likely cause of "the
volume slider does nothing" on the first bench run. It is called out at length in
`SliderVolume.qml` and `StatusGlyphSound.qml`, both of which include the tracker.

`defaultAudioSink` — not `preferredDefaultAudioSink` — because a volume slider
must move the thing making noise right now, not express a preference. The docs
warn it may briefly go null when the default changes (plugging in headphones), so
every read is guarded.

### Brightness — **there is no service. This one shells out.**

I checked the full v0.3.1 module index. It lists Bluetooth, DBusMenu, Hyprland,
I3, Io, Networking, Greetd, Mpris, Notifications, Pam, Pipewire, Polkit,
SystemTray, UPower, Wayland, Widgets and WindowManager. **There is no brightness
or backlight type in any of them**, and UPower's types are batteries and power
profiles only.

The three options were:

| | Approach | Verdict |
|---|---|---|
| a | Write `/sys/class/backlight/*/brightness` | Needs root or a udev rule, and picking the device is the same guessing game |
| b | logind's `org.freedesktop.login1.Session.SetBrightness` over D-Bus | Correct, unprivileged, the right long-term answer — **but Quickshell exposes no generic D-Bus client type**, so it is not reachable from QML today |
| c | `brightnessctl` via `Quickshell.Io.Process` | Exists for exactly this; packaged everywhere; Fedora ships udev rules letting the `video` group set brightness without root |

**(c), clearly labelled as interim.** When Quickshell grows either a brightness
service or a generic D-Bus type, `SliderBrightness.qml` is replaced wholesale and
nothing else in the shell changes — which is why the shelling-out is quarantined
in one file behind the plain `QsSlider` interface.

`tests/test-shell.sh` section 14 mechanically enforces that only two files in
`components/` may build a command line: this one, and the Game Mode handoff.

### System tray — exactly what ADR 0001 bought Quickshell for

`Quickshell.Services.SystemTray`, present in **v0.2.1 as well as v0.3.1**.
StatusNotifierItem — a published interface — with `activate()`,
`secondaryActivate()`, `scroll()`, and a `menu` handle that `QsMenuAnchor` can
display through DBusMenu.

Writing an SNI host by hand is a notorious multi-week job with a long tail of
misbehaving applications. This was one of the specific reasons ADR 0001 chose
Quickshell over LayerShellQt, and it paid off here: `TrayItem.qml` is about
thirty lines of actual code.

### Focus — ours, and deliberately shared

`services/FocusState.qml`, the singleton this branch found already in the repo.
`TileFocus.qml` **reads `enabled` and calls `toggle()`, and holds no state of its
own.** The notifications track owns that file's evolution.

`tests/test-shell.sh` section 13 fails the build if any component grows its own
copy of the Focus boolean, because a panel that says Focus is on while the toasts
keep arriving is the single most common bug in do-not-disturb implementations.

**Honest limitation:** turning Focus on does not yet stop a notification, because
there is no notification server yet. That is the notifications track's P2 work,
and it consumes the same singleton.

---

## Design decisions worth writing down

### The quarantine pattern — every tile is loaded, not imported

**A QML file that imports a module which is not installed does not warn and carry
on. It fails to load, completely.** If that file is `import`ed by the panel, the
*panel* fails. One missing module takes everything with it, and the person seeing
a blank panel has no way to tell which of a dozen files caused it.

So each tile is its own file, loaded through `QsTileSlot.qml`, and a failure
costs one dimmed placeholder with the right name on it. The 2x2 grid keeps its
shape — a hole in a grid reads as broken, a dimmed tile reads as "your computer
does not have this", which is the truth.

The same reasoning applies to the bar's three status glyphs: each is a separate
loaded file, because if `StatusGlyphNetwork.qml` were imported into
`StatusCluster.qml`, a Quickshell without the Networking module would cost the
bar its **tray and its clock** as well as its Wi-Fi glyph.

This pattern is lifted from the KDE Wave-2 widget's `AqTileSlot.qml`, which
solved the same problem for the same reason.

### The icons are drawn, not loaded from an icon theme

The KDE widget asked Breeze for `network-wireless-on`. This shell draws its own
paths in `QsGlyph.qml`. Three reasons:

1. **There is no icon theme to assume.** This runs on a bench machine in a nested
   compositor on whatever install happens to be there. A missing icon theme name
   does not warn — it draws nothing or a generic placeholder.
2. **Recolouring is the actual problem.** Quickshell's `IconImage` is an `Image`
   and has no `color`. Kirigami.Icon's `isMask` is what made the KDE tiles follow
   the theme, and nothing equivalent exists here without a shader pass. Ice is a
   **light** theme, which is exactly the case where getting this wrong is
   invisible on the author's machine.
3. **The design already drew them.** The V2 artboard contains the Wi-Fi,
   Bluetooth, Focus and Game Mode glyphs as inline SVG path data. Copying that is
   more faithful than picking the nearest Breeze name.

Same choice `LogoMark.qml` already made, generalised. Path data marked "V2" in
`QsGlyph.qml` is copied character for character from the design system; path data
marked "ours" is a state the design never drew (every "off" variant, the speaker,
the speedometer) and is labelled so that is obvious.

The one exception: **tray icons keep the application's own artwork at its own
colours**, through `IconImage`. A tray icon is somebody else's brand mark, and
recolouring Steam's logo to Aquarius Blue would be both wrong and slightly rude.

### The adaptive fourth tile

Carried over unchanged from the KDE widget, including the reasoning:

- **Game Mode on a handheld, Performance on everything else.** A gamer presses
  Game Mode to play; a creator presses Performance before a render. The square
  keeps its meaning even though the mechanism differs.
- **Decided when the panel opens, not when the image is built.** AquariusOS
  builds three images from one recipe and the Containerfile's standing rule is no
  per-variant branching. The test is `/usr/share/ublue-os/image-info.json`'s
  `image-name` containing "deck" — the same test Bazzite's own
  `bazzite-user-setup` uses, so the tile appears exactly when Bazzite's own
  "Return to Gaming Mode" launcher does.
- Rejected: Night Light (a comfort setting, not a "the machine is about to work
  hard" one), Airplane mode (duplicates the two tiles either side of it), three
  tiles on desktops (a hole in a 2x2 grid).

### Game Mode is a seam, not a feature

**The shell does not implement Game Mode and must not.** Switching a Bazzite
machine into the Steam session ends the desktop session and starts another one.

Everything the shell knows about it is one property in one file:

```qml
// components/quicksettings/TileGameMode.qml
property var osCommand: ["/usr/bin/return-to-gamemode"]
```

If the OS renames that, or replaces it with a D-Bus call or a systemd unit, that
one line changes and nothing else moves. The command is run with
`startDetached()` — the one place in this repo that does — because its job is to
tear down the session Quickshell is running in, and a tracked child would be
killed mid-switch.

**The tile is a door, not a switch.** `active` is always false, because from
inside a desktop session Game Mode never is. Faking a toggle for an irreversible
action would be the worst kind of interface lie.

### The design's "All settings" link is deliberately missing

The V2 footer ends with an "All settings" link; the KDE port pointed it at
`systemsettings`. This shell has no settings app — that is Phase P3 — and a link
that opens nothing is worse than no link. When P3 ships one it goes on the right
of the battery line.

### Deviations from the design, in full

| Design | What was built | Why |
|---|---|---|
| Colour: dark "Flow State" palette, `rgba(255,255,255,.07)` washes etc. | Ice/Midnight tokens at the same percentages | The repo's standing rule. Ice is the OS's identity now; the geometry carries over unchanged, the colour does not. |
| Tile subtitle: primary text at 72% opacity | `Theme.inkSoft` | The theme has a named role for second-tier text. A theme with an answer should not be overridden by an opacity trick, and the role survives a theme flip. |
| Panel background: translucent with a 24px backdrop blur | Solid `Theme.surface` | Same call `BarItem.qml` already made for the bar ("Glass removed", `os-image/docs/plasma-style.md`), kept so the two shells look like one product while both exist. Blur is also a per-compositor capability, and this shell may not assume one. |
| Slider handle shadow: `0 1px 4px rgba(0,0,0,.5)` | A slightly larger, very faint circle one pixel lower | A real blur means `QtQuick.Effects` and an offscreen render pass on a 16px dot. At that size the cheap version reads the same. |
| Fourth tile: Game Mode | Adaptive — Game Mode or Performance | See above. |
| Footer: battery line + "All settings" | Battery line only | See above. |
| Bar: Drop, Search, Wi-Fi + battery | Drop and Search still placeholder outlines; tray + Wi-Fi/sound/battery real | Drop and Search are other P2 tracks. Their slots are kept so the clock does not shift sideways when they land. |
| Bar has no sound glyph | Added one (muted / not muted only) | "Is my machine silent" is the question a bar can answer at a glance and the one people get caught out by. Not a volume ladder — that is what the panel is for. |
| Text sizes 10.5px / 11.5px | 11 / 12 | Qt's `font.pixelSize` wants whole numbers. Same rounding the existing `fsSmall` and `fsMono` already do. |

### New theme tokens

Nine colour roles, added to **both** `Ice.qml` and `Midnight.qml` in the same
sitting, each with a comment saying which colour at what percentage:

`tileIdle` · `tileHover` · `tileChip` · `tileDisabled` · `tileActive` ·
`tileActiveHover` · `trackIdle` · `handleFill` · `handleShadow`

Plus, in `Theme.qml`: the whole `QUICK SETTINGS` geometry block (`qs*`),
`barGlyphSize`, `barTrayIconSize`, and one type step, `fsMicro` (11).

---

## What is NOT proven

**Nothing in this branch has been executed.** There is no QML engine, no Wayland
compositor, no D-Bus and no PipeWire on macOS. What has been checked is that
`tests/test-shell.sh` passes — brackets balance, no compositor-specific imports,
no raw colour outside `theme/`, both palettes declare the same roles, every glyph
name exists, Focus is not duplicated, and only the two documented files run a
command — and that every Quickshell type, property, signal and enum variant used
here appears in the published documentation for the version it is attributed to.

That is real, and it is not the same as working. Specifically unproven:

**Structural**

1. That any of this parses. `qmllint` needs Qt; CI would run it, and this repo
   still has no remote.
2. That `PopupWindow` anchored with `anchor.item` to a bar item positions where
   the design wants. `edges: Bottom|Right` + `gravity: Bottom|Left` is the
   documented way to say "hang from that corner, grow down and left", but the
   result is a compositor's decision.
3. That declaring `QuickSettingsPopup` (a `Scope`) as a child of the status
   cluster's `Row` gives the `PopupWindow` inside it the right parent window. The
   docs' example nests a `PopupWindow` directly in a `PanelWindow`; this is one
   level further out.
4. That a `PopupWindow` with `color: "transparent"` actually renders with
   transparent corners on the first frame. The docs warn a window that starts
   opaque can never become transparent later; starting transparent should be
   fine, but `surfaceFormat.opaque` may need setting explicitly.
5. That the `implicitWidth`/`implicitHeight` chain from `QuickSettingsPanel` up
   to the window does not loop or collapse to zero.

**Behavioural**

6. **The click-the-button-again-to-close problem.** `grabFocus: true` dismisses
   the popup on any outside click — including a click on the button that opened
   it, which then reopens it. The 250ms guard in `QuickSettingsPopup.qml` is a
   heuristic, not a protocol, and needs a real compositor to tune or confirm.
   (Quickshell notes Hyprland's `HyprlandFocusGrab` does this properly; that
   module is forbidden here by the standardised-protocols law.)
7. Whether writing `BluetoothAdapter.enabled = true` also lifts an rfkill **soft**
   block. The docs only say the property is "true if the adapter is currently
   enabled". Bench test: `rfkill block bluetooth`, then press the tile.
8. The **range of `PwNodeAudio.volume`**. The docs never state it. Everything
   about how it is used says 0.0–1.0 with 1.0 = 100%, but that is an assumption.
9. Whether `PwObjectTracker { objects: [Pipewire.defaultAudioSink] }` re-binds
   correctly when the default sink changes (headphones in, headphones out).
10. Whether `UPower.displayDevice.isLaptopBattery` is false on a desktop tower —
    i.e. whether the battery line and bar glyph actually hide.
11. Whether `brightnessctl -m -c backlight i` prints the five comma-separated
    fields this parser expects on Royce's hardware, and whether the user is in a
    group the udev rules let write brightness. On a machine with no backlight the
    read should fail and the slider should hide — also unproven.
12. Whether the 60ms write debounce is enough to keep dragging the brightness
    slider from spawning a storm of subprocesses.
13. Whether the tray's right-click reaches `QsMenuAnchor` at all: `BarItem`'s
    MouseArea now accepts both buttons, and `TrayItem`'s scroll MouseArea sits
    *under* it relying on unhandled wheel events falling through.
14. Whether an `ObjectModel` used directly as a `Repeater` model (the tray) works
    as the docs imply, and whether `.values` bindings really do stay reactive.
15. `QsGlyph`'s unused path slots are fed `"M0 0"`. A moveto with nothing after
    it *should* draw nothing; not verified against Qt's `PathSvg`.
16. Whether `Shape.CurveRenderer` is available and behaves in this Qt build —
    `LogoMark.qml` already assumed it, so this is inherited, not new.
17. Whether `services/qmldir`'s **versionless** singleton line
    (`singleton FocusState FocusState.qml`, no `1.0`) is accepted. `theme/qmldir`
    writes its entries *with* a version. Versionless qmldir entries are legal in
    Qt 6, but if the Focus tile comes up as a placeholder saying "FocusState is
    not a type", that line is the first place to look. It was not changed here —
    it belongs to the notifications track.
18. Whether `onLoaded` on `FileView` binds to the **signal** rather than the
    same-named readonly property's change handler. Both exist on that type. The
    signal is what is wanted, and QML should prefer it.

**Cosmetic / correctness**

19. Whether 330px is right on a real screen, or is an artboard number — the same
    open question the roadmap already asks about the bar's 30px.
20. Whether the drawn glyphs read cleanly at 15px on a light ground.
21. The battery duration strings ("6 hr", "45 min") are marked for translation
    but assembled in English shapes. A proper localisation pass is P3.

---

## How to test it on the bench

Prerequisites, on a Linux box with a Wayland session (see `harness/README.md` for
the long version):

```bash
sudo dnf install quickshell niri brightnessctl
```

**⚠️ Check the Quickshell version first. This matters.**

```bash
qs --version
```

- **0.3.0 or newer** — everything in this branch can work.
- **0.2.1 (what Fedora's package was)** — `Quickshell.Networking` does not exist.
  The Wi-Fi tile will show a dimmed "Wi-Fi — Unavailable" placeholder and the
  bar's Wi-Fi glyph will be missing. **That is the designed behaviour, not a
  bug** — but do not spend an afternoon debugging it. To get 0.3.x:
  `sudo dnf copr enable errornointernet/quickshell`.

Then:

```bash
./harness/run-nested.sh
```

Work through this list, in order, and write down what actually happens:

**The bar**

1. Does the status cluster draw: two empty outlined slots, then any tray icons,
   then Wi-Fi + sound + battery glyphs, then the clock?
2. On a machine with no battery, does the battery glyph take **no space** — i.e.
   do the glyphs sit flush without a gap where it would be?
3. Open something with a tray icon (`nm-applet`, Steam, Discord). Does it appear?
   Does left-clicking it do its thing? Does **right-clicking** open its menu?
   Does scrolling over a volume applet change the volume?

**Opening and closing**

4. Click the status button. Does the panel appear **under the right-hand end of
   the bar**, about 8px below it, with rounded corners and no square box behind
   them?
5. Click somewhere else on the desktop. Does it close?
6. Click the status button **again while it is open**. Does it close and stay
   closed? (This is unproven item 6. If it flickers or refuses to close, the
   250ms guard needs tuning — the number is in `QuickSettingsPopup.qml`.)
7. Plug in a second monitor. Does each bar get its own panel, anchored to its own
   screen?

**The tiles**

8. Wi-Fi: does the subtitle show your actual network name? Turn it off — does the
   glyph change, does the subtitle say "Off", does the bar's glyph go quiet?
9. `rfkill block wifi` from a terminal, then look: does the tile dim and say
   "Blocked by hardware"?
10. Bluetooth: does the subtitle list connected device names? Turn it off and on.
    Then `rfkill block bluetooth` and press the tile — **does it come back on?**
    (Unproven item 7.)
11. Focus: does it light up? Does it stay lit if you close and reopen the panel?
12. Fourth tile: on a desktop it should say **Performance**. Press it, then check
    `powerprofilesctl get` in a terminal. Press it again — does it go back to
    what it was, not blindly to balanced?
13. On a handheld image only: does the fourth tile say **Game Mode**? Does
    pressing it actually switch to the Steam session? (Have a way back first.)

**The sliders**

14. Sound: does it show your real volume when the panel opens? Drag it — does the
    volume change **while dragging**, not just on release? Drag to zero — does it
    mute, and does the bar's sound glyph change? Drag back up — does it unmute?
15. Plug in headphones with the panel open. Does the slider follow the new
    default sink, or does it go dead? (Unproven item 9.)
16. Brightness: on a laptop, does it show the real brightness and change the
    screen? Run `brightnessctl -m -c backlight i` by hand and compare. Press the
    keyboard's brightness keys with the panel open — does the slider catch up
    within about four seconds?
17. On a desktop with no backlight: is the Brightness row **absent**, with the
    panel simply shorter?

**The footer**

18. Laptop: does the battery line read plausibly, and does the pictogram's fill
    match the number? Unplug it — does it change to "about N hr left" within a
    minute or so? Let it drop under 25% if you can — does the fill go amber?
19. Desktop: is the whole footer, hairline included, absent?

**Both themes**

20. Flip `dark` in `theme/Theme.qml` and save. Does everything repaint, including
    the tile washes, the slider handle and the battery? Anything that stays the
    wrong colour is a token that was read from the wrong place.

---

## If you change something here

- **Colour goes in `theme/`, both files, same sitting.** `tests/test-shell.sh`
  fails the build if Ice and Midnight disagree about which roles exist.
- **A new glyph goes in `QsGlyph.qml`'s table**, with a comment saying whether it
  came from the design system or was drawn here. Section 12 of the test checks
  every name asked for exists.
- **Do not add a second Focus boolean.** Section 13 checks.
- **Do not add a third file that runs a command** without writing down why, here
  and in section 14's allow-list. Section 14 checks.
- **Never import `Quickshell.Hyprland` or `Quickshell.I3`**, however tempting
  `HyprlandFocusGrab` looks for unproven item 6. Section 3 checks.
