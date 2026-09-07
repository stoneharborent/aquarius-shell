# The app switcher — hold the key, tap Tab, let go

*Phase R6. Lives in `components/switcher/`. Built to the spec Royce decided on
6 September 2026.*

---

## What it is

Hold **Command** and tap **Tab**. A panel appears in the middle of the screen
with the applications you have open, one big icon each. Keep holding Command and
keep tapping Tab to walk along them. Let go of Command and you are in the one
you stopped on.

That is the whole feature. It is the thing every desktop has, and until now
AquariusOS had labwc's plain list of window titles instead.

```
 the whole desktop, gently dimmed
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│       ┌──────────────────────────────────────────┐           │
│       │  ┌────┐  ┏━━━━┓  ┌────┐  ┌────┐          │           │
│       │  │ ▇▇ │  ┃ ▇▇ ┃  │ ▇▇ │  │ ▇▇ │  ← the one you are  │
│       │  └────┘  ┗━━━━┛  └────┘  └────┘     on is outlined  │
│       └──────────────────────────────────────────┘           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

The panel is **the dock's slab, lifted into the middle of the screen** — same
fill, same corner, same hairline. It is **solid, not glass**: that was decided,
and there is no blur in the code.

---

## The keys

AquariusOS asks **"Mac or Windows?"** once, at first login. That one answer sets
your copy-and-paste keys *and* the switcher. You can change it at any time:

```
aq keys mac
aq keys windows
```

Nothing else has to be changed, and nothing has to be restarted.

| | Mac style | Windows style |
|---|---|---|
| Switch | **⌘Tab** — between **applications** | **Alt+Tab** — between **windows** |
| Backwards | ⌘⇧Tab | Alt+⇧Tab |
| The windows of one app | **↓** opens them under the row | — (they are already listed) |
| Windows of one app, no panel | **⌘`** | — |
| Cancel | Esc | Esc |
| Go | let go of ⌘ | let go of Alt |

**Why the two styles list different things.** On a Mac, ⌘Tab moves between
*apps*: five windows of one editor are one icon. On Windows, Alt+Tab moves
between *windows*: five windows are five entries. Both are right, in their own
world, and AquariusOS gives you whichever world you chose.

You can also use the mouse: click an icon to go to it, click anywhere else to
cancel.

### What is **not** here yet

* **Window thumbnails.** The tiles are icons. Live previews of each window need a
  screen-capture protocol and a lot of care about performance; they are a later
  job.
* **The workspace overview** (⌃↑ on the Mac style, Win+Tab on the Windows
  style). The keys are reserved for it and nothing is bound to them yet.
* **Touch and controller navigation.**

---

## The hard part: knowing you let go

This is the part worth reading, because it is the only genuinely difficult thing
in the feature and the answer is not obvious.

### Why it is hard

On Wayland, **keyboard shortcuts belong to the window manager, not to
applications**. That is the design of the platform, not a gap in it: an
application cannot ask to be told about ⌘Tab, because letting any program listen
for any key is how keyloggers work.

So ⌘Tab is a line in labwc's configuration file, and all that line can do is
*run a command*. Ours runs one that sends a message to the shell:

```
qs ipc call switcher next
```

Which is fine for "the key went down". But a switcher also has to know when the
key comes **up**, and "run a command when a key is released" is not a thing
labwc's configuration can express in a way that helps here.

### The three approaches, and what was actually checked

The build spec named three, in order, and asked for the first that worked. All
three were checked against the *exact* versions AquariusOS builds — labwc
0.20.2 (commit `97f2887`, pinned as `LABWC_COMMIT` in the os-image repository's
`aquarius-os.env`) and Quickshell 0.3.1.

#### (a) A labwc keybind that fires on release — **rejected**

labwc really does have this. `labwc-config(5)` documents an `onRelease`
attribute on `<keybind>`, with this example:

```xml
<keybind key="Super_L" onRelease="yes">
  <action name="Execute" command="rofi -show drun" />
</keybind>
```

and the sentence next to it is the reason we cannot use it:

> The example below will trigger the launch of rofi when the super key is
> pressed & released, **without interference from other multi-key combinations
> that include the super key**.

That is the exact opposite of what a switcher needs. It is built for "tap Super
on its own to open a launcher", and it deliberately stays quiet if you pressed
anything else while Super was down.

Reading the code confirms it is not a documentation quirk. In
`src/input/keyboard.c`, labwc remembers **one** keybind — the last one that
matched a key press:

* you press Super → nothing matches, the memory is emptied;
* you press Tab → `W-Tab` matches, the memory now holds `W-Tab`, and its action
  runs straight away;
* you let go of Super → the memory still holds `W-Tab`, which is not an
  on-release binding, so nothing fires.

There is no arrangement of `onRelease` bindings that changes this, because there
is only ever one slot.

#### (b) Aquarius Keys (the xremap engine) emitting it — **rejected**

Aquarius Keys sits below the compositor, at the level of the raw keyboard, so at
first glance it is the natural place to notice a key coming up. Two things rule
it out, and either one on its own would be enough:

1. **In the Windows style the remapper does not run at all.** That is written
   into `windows.yaml` in the os-image repository as a deliberate safety
   property: the profile has no rules, and `/usr/libexec/aquarius-keys-run`
   starts nothing when there are none, so that nothing sits between you and your
   keyboard for no benefit. Alt+Tab could therefore never be served this way.
2. **In the Mac style, watching the Super key means taking it.** A remapper
   claims a key in order to act on it, and the one thing Super has to keep doing
   is being a modifier for every other shortcut on the machine.

#### (c) The shell watching the key itself — **chosen**

This is what is built, and it works because of a specific and checkable detail
of how labwc handles key releases.

* **The modifier on its own is bound to nothing.** Only ⌘Tab is a keybind.
  There is a warning in `rc.xml` saying never to bind `Super_L` or `Alt_L` on
  their own, and this is why.
* **labwc forwards the releases of keys it did not swallow.** Its
  `handle_key_release()`, in `src/input/keyboard.c`, says a release is always
  forwarded to clients when the matching press was not bound — the comment above
  it gives the reason as avoiding stuck keys. Since nothing swallowed the Super
  *press*, the Super *release* is passed on to whatever surface holds the
  keyboard.
* **The panel holds the keyboard.** It is a layer-shell surface asking for
  `keyboardFocus: Exclusive`, which labwc honours (`layer_try_set_focus()` in
  `src/layers.c`), and when labwc hands the keyboard over it passes along the
  keys that are currently held down (`seat_focus()` in `src/seat.c` calls
  `wlr_seat_keyboard_enter` with the pressed-but-not-swallowed keycodes).

So: you hold Command, tap Tab, the panel goes up and takes the keyboard, and
when you let Command go the release arrives at the panel as an ordinary key
event. `Keys.onReleased` in `components/switcher/AppSwitcher.qml` is the whole
mechanism, and it listens for four key names — `Meta`, `Super_L`, `Super_R` and
`Alt` — so that it covers both profiles without needing to know which one is on.

Two other things fall out of the same choice, both of them checked rather than
hoped for:

* **The panel appears on the monitor your pointer is on.** The window does not
  say which screen it wants, and labwc places a layer surface with no output on
  `output_nearest_to_cursor()` (`src/layers.c`). That is exactly the rule the
  spec asked for, decided by the only thing that knows where your pointer is.
* **Opening the switcher does not shuffle the list under you.** The panel is a
  layer surface, not a window, so the app you were in stays the *active window*
  while you choose (`seat_focus()` does not change labwc's `active_view`). If
  that were not true, the first tap of Tab would take you nowhere.

### The one rough edge, said plainly

There is a gap of a few tens of milliseconds between Tab going down and the
panel having the keyboard: a small program has to start, talk to the shell, and
the compositor has to put a surface on screen. **Let go inside that gap — a
really fast tap — and the release lands somewhere else and the panel does not
see it.**

It never becomes a trap. Three ways out, all of them things you would try
anyway:

* press **Esc**;
* **click** the app you wanted, or click anywhere else to cancel;
* press **⌘Tab again** — by then the panel certainly has the keyboard, so the
  next release lands on it.

If this turns out to be common in real use, the proper fix is upstream in labwc:
a keybind that fires on a modifier's release *regardless* of what was pressed in
between. That is a small change to `handle_compositor_keybindings()` and it
would suit every other Wayland shell that wants an alt-tab.

**This is the thing to watch for on the bench.** It is a known limit, not a bug
to hunt.

### The second edge — the arrows, and Aquarius Keys (found on the bench, 2026-09-07)

⌘↓ under ⌘Tab went to the app instead of opening its windows. Aquarius Keys
turns ⌘↓ into Ctrl+End and ⌘↑ into Ctrl+Home everywhere — the Mac "end of
document" habit — and to send that chord it lets go of ⌘ for a few
milliseconds and then presses it again. The panel saw the release and did what
a release means.

The panel now waits sixty milliseconds after the modifier comes up before it
commits, and calls that off if the modifier comes back down or any key arrives
in between. It also reads Ctrl+End and Ctrl+Home as ↓ and ↑, so what the remap
delivers still does what you pressed. The cost is sixty milliseconds on every
switch, below what a hand notices; the alternative was taking ⌘↓ away from
every document, which is the wrong trade. Windows mode is not affected —
Alt+↓ is not remapped.

---

## What it lists, and in what order

* **Most recently used first.** The app you are in is the first tile, so the
  selection starts on the **second** one and a single tap-and-release flips you
  back to what you were doing a moment ago — exactly as it does on a Mac.
* **⇧ opens on the last one** instead, which is the same idea from the other
  end.
* **Applications with no window open are not listed.** A pinned dock icon for
  something that is not running has nothing to switch to.
* **Minimised windows are listed, and are restored when you go to them.**
* **Full-screen applications and games are listed like anything else.**
* **Nothing from the lock screen or the login screen ever appears.**
* A tile shows a small number in its top-right corner when that app has **more
  than one window**. Press ↓ to see them.

The row wraps onto a second line when there are more applications than fit
across the screen, rather than running off both edges — macOS does the same, and
the tile that runs off the edge is always the one you were reaching for.

---

## How to try it from a clone

You need a Linux machine running the Aquarius Session. Everything below assumes
you have already been through `docs/session.md`.

```bash
# 1. Get the shell.
git clone https://github.com/stoneharborent/aquarius-shell.git ~/aquarius-shell
cd ~/aquarius-shell

# 2. Install the session files, which include labwc's rc.xml with the
#    switcher's keybinds in it.
./session/install-session.sh

# 3. Log out and log back in, choosing "Aquarius" at the login screen.
```

Then:

```bash
# Is the shell listening?  All seven functions should be listed.
qs ipc show

# Drive it by hand, without touching the keyboard at all:
qs ipc call switcher next        # open it, or step forward
qs ipc call switcher prev        # step backward
qs ipc call switcher down        # open the selected app's windows
qs ipc call switcher up          # back up out of them
qs ipc call switcher go          # go to what is selected, and close
qs ipc call switcher cancel      # close, changing nothing
qs ipc call switcher cycle       # ⌘` — next window of the app you are in
```

`switcher cancel` is also the way out if it ever gets stuck open — from another
terminal, from a phone over SSH, or from a text console.

To try the other profile:

```bash
aq keys windows     # now Alt+Tab lists windows, one row each
aq keys mac         # back to applications
```

No logout is needed. The shell watches `~/.config/aquarius/keys.conf` and
changes what it lists the moment the file changes.

---

## The files

| File | What it is |
|---|---|
| `components/switcher/AppSwitcher.qml` | The overlay: the window, the keyboard, the IPC door, the state. The long explanation of the modifier release is at the top of it. |
| `components/switcher/SwitcherModel.qml` | What to list and in what order — the most-recently-used list, and the grouping into applications. |
| `components/switcher/SwitcherTile.qml` | One application, as a 124px tile with its icon and its window count. |
| `components/switcher/SwitcherRow.qml` | One window, as a line. Used at two sizes: the Windows profile's rows and the Mac profile's ↓ list. |
| `services/KeyProfile.qml` | Reads `~/.config/aquarius/keys.conf`. Never writes it — `aq keys` owns that file. |
| `services/AppIdentity.qml` | "Which application is this window?", answered once for the dock, the switcher and the top bar. |
| `session/labwc/rc.xml` | The five keybinds, in one clearly marked block, plus the setting that switches labwc's own switcher off. |
| `theme/Theme.qml` | Every size, under `switcher*`. |
| `theme/Ice.qml`, `theme/Midnight.qml` | `switcherScrim` — the switcher dims the desktop much less than the search palette does, because you are choosing between things you can see. |

The same `rc.xml` block exists a second time in the os-image repository, at
`system_files/usr/share/aquarius/labwc/rc.xml`. **Change one, change both** —
`build_files/check-labwc-drift.sh` over there fails the build if they disagree.

---

## What is unproven

No QML engine has run any of this. It passes `tests/test-shell.sh` section 38,
which reads the files; that is the cheap gate, not the real one.

The bench list, in order:

1. **⌘Tab, held, through three apps.** Hold Command, tap Tab three times, let
   go. You should land on the third one.
2. **↓ into an app with two windows.** Stop on it, press ↓, pick a line, let go.
3. **⌘`** with two windows of one app open, and no panel appearing.
4. **`aq keys windows`, then Alt+Tab.** One row per window, with the window's
   title over the application's name.
5. **Esc** cancels and changes nothing.
6. **Two monitors.** The panel should appear on the one your pointer is on.
7. **The fast tap.** Tap ⌘Tab as fast as you can. If the panel stays up, that is
   the known race described above — press Esc and say so; it is a measurement,
   not a bug report.
