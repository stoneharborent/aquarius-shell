# The first run on real hardware

*2026-09-01, on the AquariusOS bench PC (Ryzen 9 9950X3D, RTX 4090, GNOME
session). Everything in this repo had been written on a Mac, where no QML engine
and no Wayland compositor exist. This page is the record of the day it was first
executed: what broke, what was fixed, and — the part that matters — what is now
genuinely proven versus what is still only written down.*

---

## The short version

**It runs, and it responds.** The bar, the dock, Quick Settings, the
notifications panel and Flow Search all draw, all five read real data from the
real machine, and — after the interaction pass later the same day — searching,
launching, cycling windows, toggling, sliding, replying and clearing all do what
they say.

Four failures stopped it loading, and each one had passed every check in
`tests/test-shell.sh` first. A fifth was breaking a component silently. A sixth,
found only by driving it, had silently killed three features in the search
palette since the day that file was written. All are fixed and committed, one
commit each, and the last one now has a test that catches its whole class.

Three defects remain open because they need a decision rather than a fix — they
are listed at the end of the interaction pass below. One of the three, the
keyboard-grab clash between Quick Settings and the search palette, has since
been decided and fixed in code; it has **not** been re-run on this machine.

---

## What broke, in the order the QML engine found it

Each of these stopped the shell dead. The engine reports one at a time, so this
was five runs, not one.

| # | The error on screen | What was actually wrong |
|---|---|---|
| 1 | `theme/Theme.qml: color is not a type` | `color` is not built into QML — it arrives with QtQuick, which none of the three theme singletons imported. |
| 2 | `Cannot assign a value to a signal` | A palette entry was named `onAccent`. QML reads any name shaped `onSomething` as a handler for the signal `Something`. |
| 3 | `Cannot assign to non-existent property "families"` | `font.families` does not exist in the Quickshell build the OS runs (0.2.1 on Qt 6.11). |
| 4 | `Row will not function` | `TrayItem`'s wheel-gesture MouseArea sat directly in a `BarItem`, which puts it in that item's `Row`, anchored. A Row refuses anchored children and then stops laying out **all** of them. |
| 5 | *(no error — it just looked wrong)* | The bar wore a crossed-out Wi-Fi mark on a desk PC that appeared to have no wireless adapter at all. **See the correction below — it has one.** |

Number 4 is the instructive one. It printed a warning rather than an error, so
the shell started and looked more or less right — while every tray icon on the
machine rendered as an empty box. The proof it was doing real damage: the Steam
tray icon draws Steam's logo after the fix and drew nothing before it.

### What this says about the test suite

`tests/test-shell.sh` passed on every one of these. That is not a criticism of
it — it reads the files, and none of these are visible to a reader. It is the
cheap gate. A QML engine found all four load failures in about a minute, and
`tests/test-shell.sh` now says so in its closing note rather than claiming the
files are unverified.

---

## What is proven now

Each of these was seen on screen, with a screenshot, on this machine.

- **The bar draws** — Aquarius mark, active app name, system tray, status
  glyphs, clock.
- **The active app name is live.** Opening a terminal in the nested session
  changed it from *Desktop* to *Foot*. That is the foreign-toplevel protocol
  working, which is the architectural bet the whole shell rests on.
- **The theme follows the system.** The bench machine is set to dark and the
  shell came up Midnight, through the same portal GNOME apps read.
- **Hot reload works.** Save a `.qml` file, the shell reloads in about a second.
  Every fix above was made this way, without restarting anything.
- **The dock** draws the six pinned apps the shipping OS pins — Files, Firefox,
  Steam, Aquarius Editor, Aquarius Writer, Settings — with their real artwork,
  the hairline rule, and the `+` tile. Opening an app added a tile **with the
  running dot underneath it**.
- **Quick Settings reads the real machine**: Wi-Fi *No adapter* (**wrong — see
  the correction below**), Bluetooth
  showing the actually-connected MX Vertical, Performance *Balanced*, and a
  sound slider at the system's real 38%.
- **Flow Search works.** `12.5 * 8` gives 100 with *press Enter to copy*; typing
  letters finds real applications with real icons.
- **The shell is the notification daemon.** `notify-send` in, toast out, and the
  panel groups them by application with counts, a collapse chevron, timestamps,
  *Clear all*, and the footer clock with *Focus until morning*.

## The interaction pass — 2026-09-01, later the same day

The first run proved things DRAW. This pass drove them: keystrokes, clicks and
real D-Bus traffic, checked against the machine rather than against a
screenshot. It found one dead feature, three defects that need a decision, and
proved the rest.

### One bug found and fixed: `Item.palette` shadowed the search overlay's id

The search palette used `id: palette`, and every QML `Item` also has a built-in
`palette` property. An object's own property wins over the file's ids, so in the
result delegate `palette.selectedIndex` meant `Item.palette.selectedIndex` —
undefined. `index === undefined` is false, silently, so **three features had
never worked once**: the selected row was never drawn, its "open" hint chip
never appeared, and `awaitingConfirm` never armed, which is the confirm-twice
guard on destructive session actions.

The arrow keys had been working perfectly the whole time. Nothing on screen said
so. Found by painting the selected row bright red and watching nothing happen.

`tests/test-shell.sh` section 26 now fails on any id spelled like a property
every QML object has, so this class cannot come back quietly.

### Proven by driving it

| What | How it was checked |
|---|---|
| Search launches an app | Enter on a result: window count 0 to 1, palette closed itself, bar changed to the app's name, dock grew a tile with a running dot |
| Search does arithmetic | `2^10` then Enter: the system clipboard contained `1024` |
| Arrow keys | Down moves the accent wash from row 0 to row 1 (after the fix above) |
| Escape | Closes the palette; `isOpen` returns false |
| Dock cycles windows | Two windows of one app, click its tile: focus moved from window 3 to window 2 |
| Quick Settings' Focus tile | Toggles on and off, and `focus.json` on disk follows it both ways |
| The sound slider reads | Setting the volume externally to 50% moved the slider to 50% live |
| The sound slider writes | Clicking a quarter along the track set the real volume to 0.23 |
| Notification action buttons | Clicking "Open folder" delivered `open` back to the sending program, which exited |
| Notification inline reply | Typed a reply, pressed Send, and the bus carried `NotificationReplied (3, 'yes, exported this morning')`, then the notification closed |
| Clear all | Empties the panel, which then says "You're all caught up." and drops the Clear all link |

### Found, not fixed — these need a decision

*(Defect 1 has since been decided and fixed in code — see the note under it. The
fix has not been re-run on hardware.)*

1. **Quick Settings open stops the search palette receiving any keys.**
   Reproducible. Quick Settings is a `PopupWindow` with `grabFocus: true`, which
   takes an input grab from the compositor. Open it, then open the palette: the
   palette appears, with a blinking text cursor, and every keystroke goes
   somewhere else. Nothing says so. The obvious intent is that opening the
   palette should dismiss Quick Settings — but the panel lives inside the bar's
   per-screen `Variants`, so wiring that is a real change, not a one-liner.

   **DECIDED AND FIXED — NOT RE-RUN ON HARDWARE (2026-09-01, Royce's call).**
   The rule is *one exclusive overlay at a time*: opening Flow Search, Quick
   Settings or the notifications panel closes the other two, in every direction,
   on every screen. It lives in a new shared singleton, `services/Overlays.qml`
   — each overlay registers a way to be closed when it is created, unregisters
   when it is destroyed, and calls `Overlays.claim()` on its open path before
   its surface goes up. A list rather than a single "which one is open" value,
   because Quick Settings exists once per monitor and "close it" has to mean all
   of them.

   Symmetric on purpose, so the mirror case (palette open, click the status
   cluster) is not left for somebody to re-find. The notifications panel is
   included even though it takes no compositor grab: it lands in the same corner
   and covers the screen with a click-catcher.

   **What was verified, and how:** the singleton's own logic was *executed*
   under Quickshell 0.2.1 on Qt 6.11 — registering, refusing a duplicate,
   `claim()` closing everybody but the caller, `closeAll()`, `unregister()` —
   and the whole shell was loaded in the nested niri harness, where all three
   overlays were seen registering themselves at start-up and the configuration
   loaded with no errors. `tests/test-shell.sh` gained section 27, which fails
   if any of the three stops registering, unregistering or claiming.

   **What was NOT verified — the thing the defect is actually about.** Nobody
   has opened Quick Settings on this machine and then pressed the search key to
   see whether the keystrokes now land. Driving the palette from outside was not
   possible in that session (`qs ipc` would not attach to the harness's
   instance from inside the container), so the behaviour stays unproven until
   the next bench run. `docs/flow-search.md` step 9b and
   `docs/quick-settings.md` step 6b are that test, written out.

   One thing found by running it, worth knowing on its own:
   **`Component.onCompleted` needs `import QtQuick`.** It is an attached type.
   `NotificationLayer.qml` draws nothing and so had never imported QtQuick, and
   giving it a `Component.onCompleted` made Quickshell refuse the entire file
   with "Non-existent attached object" — a message that says nothing about
   imports. Section 27 checks for that too.

2. **The Bluetooth tile can stick in a transitional state indefinitely.** After
   a toggle it read "Turning on..." with an off glyph, for half an hour, while
   the adapter was in fact powered with two devices connected. The tile mirrors
   Quickshell's `adapter.state` and `adapter.enabled` faithfully and both were
   stale, so this is Quickshell 0.2.1's Bluetooth service rather than our
   binding. Worth noting the same long-lived process had also drifted on volume
   (tile 38%, machine 30%). **Restarting the shell corrected both.** Whether
   this is the alpha service or the container's grip on the buses is open — and
   it is a good reason to check a suspicious reading against the machine before
   calling it a shell bug.

3. **Clicking the dock tile of an app with one focused window does nothing on
   niri.** The code asks that window to minimise, which is right by the protocol
   — and niri has no concept of minimising, so the request is ignored. A dead
   click is the kind of small lie this shell is not supposed to tell. What
   should it do on a compositor with no minimise?

4. Minor: the inline reply's placeholder hint
   (`x-kde-reply-placeholder-text`) is not picked up — the field says "Reply"
   rather than "Reply to Bianca".

Not a bug, recorded so nobody re-finds it: clicking a toast that has already
timed out does nothing, which looks exactly like a broken button.

---

## What is still NOT proven

- **Both gates.** P1's *does it feel better than the themed panel?* and P2's
  *OBS records, Steam desktop works, a full workday survives* are judgement
  calls that need Royce at the machine, not a screenshot.
- **The real login session.** Everything above ran in the nested harness. The
  session in `session/` — picking Aquarius at the login screen — has still never
  been logged into. That is the next real step, and `docs/session.md` has it.
- **Dragging a dock tile to reorder**, and the `+` tile's app grid (which does
  not exist yet — it opens the search palette instead).
- **Launching a pinned dock app.** The six pinned entries are host applications,
  and inside the distrobox their commands do not exist, so the launch path was
  proven through the search palette instead. Both go through the same
  `entry.execute()`.
- **The Focus timer expiring**, and Focus surviving a shell restart.
- **Destructive session actions** — log out, restart, shut down. Deliberately
  never triggered on Royce's own machine; the confirm-twice guard protecting
  them was fixed above but has still never been seen to arm.
- **More than one monitor**, and plugging one in or out while running.
- **labwc.** Only niri has been used. The compositor comparison the roadmap
  wants has not started.

---

## What the harness needed before any of this was possible

Four things, all now automatic in `run-nested.sh` — see `harness/README.md`.

1. **Its own compositor config.** niri was reading the user's `~/.config/niri`,
   and niri's stock default starts waybar and throws a hotkey card over
   everything. Both were in every screenshot. The harness now passes `-c` and
   the nested desktop contains nothing but our shell.
2. **The system message bus.** In a distrobox the shell could not reach it, so
   battery, network, Bluetooth and power profile were all blank.
3. **The machine's applications.** `XDG_DATA_DIRS` inside a distrobox names
   directories that do not exist there, which is why the dock was empty.
4. **A private session bus** (`AQ_PRIVATE_BUS=1`) for notifications, because
   only one program per bus can be the notification daemon and GNOME already is.

Two traps worth knowing about, neither of them a bug in the shell:

- **The fonts are on the machine but not in the container.** One fontconfig file
  pointing at `/run/host/usr/share/fonts` fixes it; `harness/README.md` has it.
- **A grey rectangle in the middle of a screenshot is niri's overview**, opened
  by the pointer touching the top-left hot corner — which is exactly what
  happens if you park the pointer at 0,0 to get a known position before
  clicking. The harness config now turns hot corners off. This one cost an
  afternoon of hunting for a bug in our own compositing.

---

## Open questions for Royce

Not bugs — decisions.

1. ~~**The two empty squares in the bar.** They are deliberate placeholders for
   *Drop* and *Search*. But Flow Search now exists, so the Search one could
   simply open it. Wire it up, or keep both as placeholders until Drop is real?~~
   **ANSWERED 2026-09-04 — neither. Remove them.** Royce, after using the
   desktop on the 55" bench monitor: *"remove the placeholder squares in the top
   right bar."* Search already opens from the Aquarius mark and the dock's `+`,
   so its slot was holding space for something that had arrived; Drop gets a
   real bar item on the day Drop exists. The standing rule now: a bar item that
   is not yet clickable does not get drawn. See `docs/quick-settings.md`, "What
   the cluster draws".

   He asked for one other thing in the same breath, which was not on this list:
   *"remove the clear borders around the apps in the dock."* Each dock icon was
   sitting in its own bordered pane. That is gone too — `docs/dock.md`, "No box
   around the icon".
2. **Fuzzy search breadth.** Typing `fi` returns Starfield, DaVinci Resolve and
   Alacritty — the matcher weighs several fields, not just the name. Right call,
   or should the name carry more weight?
3. **Text truncation in the Quick Settings tiles.** *MX Vertical ·…* and
   *Notifications…* both clip. Live with it, widen the tiles, or shorten what
   they say?

---

## 2026-09-02 — the session boots

*The second real milestone, and it is worth being precise about which half
succeeded.*

**The session boots. The shell did not start.**

What was seen, on the AquariusOS bench PC (`aquarius-os-gnome-nvidia`, built
2026-09-01, Fedora 44, GDM):

- `session/install-session.sh` ran and put its five pieces in place.
- **GDM listed the session**, from
  `/usr/local/share/wayland-sessions/aquarius.desktop`. This was the single
  assumption the whole "no changes to the OS image" story rested on, and it
  holds — GDM walks `/usr/local/share` as well as `/usr/share`.
- The launcher ran, found its configuration and the shell, and started niri.
- **niri 26.04 came up** with our config on a 4K output and stayed up for
  eighteen minutes. Windows, keys, the compositor: fine.
- **No bar.** And `~/.local/state/aquarius-session/session.log` contained
  *only* niri's output — not one line from the shell.

### Why: the layered Quickshell could not start at all

```
qs: symbol lookup error: qs: undefined symbol: _ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6
```

Fedora rebuilt `quickshell` on 2026-08-31 against `qt6-qtbase` **6.11.2**, which
had just reached the updates repository. The AquariusOS image contains
**6.11.1**. `rpm-ostree` can layer a package on top of the image; it cannot
change the Qt underneath it. So the layered `-5.fc44` build asks the image's
older Qt for a private function it does not have and dies instantly.

This is **structural, not bad luck**: a layered Quickshell works only when the
repository's build happens to have been compiled against the image's Qt, and
nothing coordinates those two things. The `-3.fc44` build (against 6.11.1) works
— it is what the `aq-shell` distrobox has been running all along, which is why
every harness run has been fine.

Both fixes, with copy-pasteable commands, are in
[`session.md` § The Qt ABI trap](session.md#the-qt-abi-trap): layer the matching
older RPM from Koji (quick, and undone by the next update), or bake `quickshell`
into the OS image so it is built against the image's own Qt (proper).

### Two blind spots made an eighteen-minute failure invisible

Neither of these is the Qt problem. Both are ours, and both are fixed.

1. **The pre-flight only looked for the file.** `aq_need qs` ran `command -v qs`,
   which passes for a binary that cannot start. The launcher now **runs
   `qs --version`** (with a timeout) and refuses to start the session if that
   fails, printing the real error text and both fixes.

2. **The compositor threw the shell's output away.** `spawn-at-startup "qs"`
   gave the shell `/dev/null` for stdout and stderr, so its error never reached
   the log. This was **measured, not assumed**: on niri 26.04 a spawned program
   was asked what its own three file descriptors pointed at and answered
   `/dev/null` for stdin, stdout and stderr. Both compositor configurations now
   start the shell through `sh` and append its output to the session log, with
   every line prefixed `[shell]` so it is tellable from the compositor's.

   Verified end to end the same day: niri 26.04 started with this repo's own
   config and `AQ_LOG` set, and the shell's start-up lines arrived in that file,
   prefixed. Nested, from a terminal — not yet from GDM.

`tests/test-shell.sh` section 29 now fails if either blind spot comes back.

### Still not proven

Everything the shell does in a real session. The bar has never drawn outside the
nested harness. Fix the Qt mismatch, log in again, and this page gets its third
entry.

---

## Correction, 2026-09-02: the Wi-Fi readings on this page are wrong

Defects 5 and the "Wi-Fi *No adapter*" reading above both rest on the belief that
the bench PC has no wireless card. It has one. Probed against the host's system
bus, NetworkManager reports **`wlp7s0`**, `DeviceType.Wifi`,
`wifiHardwareEnabled: true`, disconnected.

Two things conspired to hide it:

1. **`Networking.devices` is empty for the first moment of the shell's life** and
   fills in asynchronously. Any reading taken at start-up says "no wireless".
2. **`TileWifi.qml` said `ConnectionState.Connecting`**, which is the Quickshell
   0.3.x spelling. The shipped build calls that enum `DeviceConnectionState`, so
   the moment the adapter arrived and the subtitle re-evaluated, QML threw
   `ReferenceError: ConnectionState is not defined` and killed the binding —
   freezing the tile on the start-up value, *No adapter*, for good.

So this was a sixth defect on the day, sitting under a fifth that was not really
a defect at all. It is fixed; the whole story is in
[`quick-settings.md`](quick-settings.md), and `tests/test-shell.sh` section 28
now fails the build if any file names an enum namespace the shipped Quickshell
does not have.

The lesson worth keeping: **a reading taken from a service at start-up is not a
reading of the machine.** The bench list on this page should be worked through
again a few seconds after the bar appears, not at the first frame.
