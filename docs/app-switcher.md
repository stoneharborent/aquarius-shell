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

### The one rough edge, said plainly — and the 2026-09-14 fix for it

There is a gap of a few tens of milliseconds between Tab going down and the
panel having the keyboard: a small program has to start, talk to the shell, and
the compositor has to put a surface on screen. **Let go inside that gap — a
really fast tap — and the release lands somewhere else and the panel does not
see it.**

**The bench found it.** Royce, 2026-09-14: *"the app switcher command sometimes
doesn't select or switch apps if the command is hit too quickly."* That is this
edge and nothing else: the panel is up, the gesture is over, and nothing ever
commits, because the event that means *commit* went to the window you were in.

**The panel cannot see the release it missed**, and it is worth knowing why so
nobody goes looking for a way. Wayland does tell a client which keys are held
when it is handed the keyboard, and labwc does pass them along — but Qt throws
that list away rather than turning it into events (qtwayland,
`qwaylandinputdevice.cpp`, `keyboard_enter`: `Q_UNUSED(keys)`). So "still
holding ⌘" and "let go a moment ago" look identical from in here.

**But the next press tells it.** Only two things can happen next, and they look
nothing alike:

| what really happened | what the panel hears next |
|---|---|
| you are still holding ⌘ | that modifier's **release**. A key already down cannot be pressed again. |
| the release was lost | you press ⌘ again to have another go — and that **press** lands on the panel, which by now certainly has the keyboard. |

So the rule, in one line: **the first keyboard event after the panel opens being
a modifier *press* means the last gesture ended out of sight.** The panel then
starts the gesture over, and the next Tab opens it afresh — on the app the first
tap should have landed on — instead of stepping along a selection nobody ever
got to use. Pressing the keys again, which is what a person does anyway, is now
the fix. Two booleans carry it: `sawKeyEvent` and `gestureRestart`.

⚠️ **Why "the first event" and not simply "a modifier press".** Aquarius Keys
presses the modifier again all the time — it lets go of ⌘ for a few
milliseconds to send a remapped chord and then puts it back (the second edge,
below). By then the panel has already heard that release and the chord's own
keys, so `sawKeyEvent` is true and the resurrection is not mistaken for a fresh
gesture. A panel that restarted on *any* modifier press would break ⌘↓, which is
the fix before this one. `tests/switcher-js-tests.mjs` asserts both.

The other ways out are unchanged, and still things you would try anyway: press
**Esc**, **click** the app you wanted, or click anywhere else to cancel.

**The gap itself is still upstream's.** This makes the recovery right; it does
not make the gap go away. The proper cure is a labwc keybind that fires on a
modifier's release *regardless* of what was pressed in between — a small change
to `handle_compositor_keybindings()` that would suit every other Wayland shell
that wants an alt-tab.

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

### The third edge — ⌘↓ closed the panel when Files was in front (found on the bench, 2026-09-08)

**What Royce saw.** He had been looking at his drives in Files. He held ⌘,
tapped Tab, and pressed ↓ to see an app's windows — and the switcher went to
the app and disappeared instead.

**Why.** Aquarius Keys does not have one set of rules; it has a set per
application, and a general set for everything else. There is a **Files-only**
block, so that the two habits a Mac user has in a file manager still work:

| In Files | is sent as | so that it does |
|---|---|---|
| ⌘↓ | `Enter` | opens the thing you have selected |
| ⌘↑ | `Alt+↑` | goes up to the folder above |

Now, **how does Aquarius Keys decide you are "in Files"?** It asks the
compositor which window is the front one. That question is answered through a
published protocol (`wlr-foreign-toplevel-management`), and the remapper's own
code — `src/client/wlroots_client.rs` in the exact xremap we build, 0.15.12 —
does two things worth knowing:

* it remembers a window as "the active one" when the compositor says that
  window has become active, **and it never forgets**. So "the current
  application" really means "the last ordinary window that was in front".
* **the switcher panel is not an ordinary window.** It is a *layer surface* —
  the same kind of thing the bar and the dock are — and layer surfaces are not
  in that list at all. The panel can never become "the current application".

So with Files in front, ⌘↓ arrived at the panel as **Enter**, and Enter meant
"go to what is selected". The panel closed. (⌘↑ was fine by luck: `Alt+↑`
arrives as ↑, and ↑ already means up.)

**What was considered, in the order the brief asked for.**

* **(a) Tell the remapper to stand aside while the switcher is open.** *Not
  possible with the remapper we ship.* xremap can be told to look at four
  things and no others: the front window's application id, the front window's
  title, which keyboard the key came from, and a "mode" it entered because
  somebody pressed a key. There is no file, no socket and no command it can be
  pointed at, so a "the switcher is open" marker on disk is invisible to it.
  The other half of (a) — the shell putting up a real window while the panel is
  up, so that xremap sees *us* as the front application — was rejected on three
  counts: a real window would compete for the keyboard the panel must hold in
  order to see ⌘ come up at all (which is the entire mechanism this switcher is
  built on); it would show up in the switcher's own list and in the dock; and
  when it closed, the remapper would be left pointing at a window that no
  longer exists, with **no** current application — which switches the Files and
  terminal rules off until you click something else.
* **(b) Read Enter as ↓, but only in the instant after the remapper let ⌘ go.**
  **Chosen.** The remapper always releases ⌘ microseconds before it sends the
  chord, and a person cannot let go of ⌘ and then press Return inside a
  sixteenth of a second. So "the sixty-millisecond grace timer is running" is
  already a reliable way of saying *this key came from the remapper, not from a
  hand* — and the panel has trusted exactly that since 2026-09-07 for
  Ctrl+End. No new machinery, no new state, and it cannot mistake a deliberate
  Return for an arrow.
* **(c) Take `Super-Down`/`Super-Up` out of the Files block.** Not done, and
  not recommended: it would cost a Mac habit (⌘↓ opens the selected file, ⌘↑
  goes up a folder) in order to fix a switcher. Wrong way round. `mac.yaml` is
  unchanged.

**One more thing the same fix carries.** Since the remapper presses Alt to send
`Alt+↑` and lets it go again two events later, the panel now remembers a
modifier that arrived from a chord and ignores its release. Before, that
release started a commit that was cancelled a moment later by ⌘ coming back —
which worked, but only because the remapper is fast.

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
| `components/switcher/AppSwitcher.qml` | The overlay: the window, the keyboard, the IPC door, the state. The long explanation of the modifier release is at the top of it. It *carries out* key decisions; it no longer makes them. |
| `components/switcher/switcher-keys.js` | The rulebook: what one key event means, given what happened just before it. Plain JavaScript with no QML in it, so it can be run. |
| `tests/switcher-js-tests.mjs` | 63 assertions that walk whole gestures — the ordinary one, each of the three bench findings, the fast tap — through the rulebook under node. |
| `services/SwitcherTrace.qml` | The flight recorder. Off unless `AQ_SWITCHER_TRACE=1` (or `AQ_TRACE=switcher`) is set; on, it writes one line per event into the ordinary session log. See "When the switcher misses" below. |
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

## When the switcher misses: how to capture it

Royce reported on 2026-09-15, and twice before that: *sometimes it won't switch
to the selected app.* Each time the report arrived with nothing attached, because
there was nothing to attach. Every fix so far has been worked out by reading the
source and guessing at the order of events. Two of those guesses were probably
right. None of them were ever checked against a real miss.

This section is how that stops. The switcher can now write down everything it
does. It is **off by default** — it costs nothing when it is off — and when it is
on, one miss produces about twenty lines that say exactly which step did not
happen.

**What we need from you: make it miss once with the trace on, then send the
lines.** That is the whole ask.

### Way 1 — right now, in a terminal, no logging out

This is the quickest, and the trace appears straight in the terminal window where
you can see it. It restarts the desktop's panel, dock and menus for a second —
your applications are **not** touched, nothing closes, nothing is lost.

Open a terminal and type this, all on one line:

```bash
pkill -x qs; sleep 1; AQ_SWITCHER_TRACE=1 qs 2>&1 | tee ~/switcher-trace.txt
```

What that does, word by word:

| Piece | What it means |
|---|---|
| `pkill -x qs` | stop the shell that is running now (the bar and the dock vanish for a moment) |
| `sleep 1` | give it a second to tidy up |
| `AQ_SWITCHER_TRACE=1` | start the next one with the trace switched **on** |
| `qs` | start the shell again — the bar and dock come back |
| `tee ~/switcher-trace.txt` | show everything on screen **and** save a copy in your home folder |

Leave that terminal running. Now use ⌘Tab normally until it misses. The moment
it does, come back to the terminal, press **Ctrl+C** to stop it, and then start
the shell again the ordinary way:

```bash
/usr/libexec/aquarius-shell-start &
```

The file `~/switcher-trace.txt` now has the evidence in it. Send the last fifty
lines or so:

```bash
tail -n 50 ~/switcher-trace.txt
```

### Way 2 — leave it on for a whole session

Use this if the miss is rare and you would rather not sit in front of a terminal
waiting for it. It survives logging out and back in, and it turns itself off
again when you undo it.

```bash
mkdir -p ~/.config/labwc
cp /usr/share/aquarius/labwc/environment ~/.config/labwc/environment
echo "AQ_SWITCHER_TRACE=1" >> ~/.config/labwc/environment
```

Log out and back in. From now on the trace lines go into the session log, along
with everything else the desktop says:

```bash
grep switcher ~/.local/state/aquarius-session/session.log | tail -n 60
```

(The log from your **previous** session is next to it, as `session.log.1`. If the
miss happened just before you logged out, that is the file to look in.)

To turn it off again, delete the line you added — or, if you copied nothing else
into that file, delete the whole file:

```bash
rm ~/.config/labwc/environment
```

There is a second name for the same switch, `AQ_TRACE=switcher`, which exists so
that other parts of the shell can grow traces of their own later
(`AQ_TRACE=switcher,dock` would turn on two). Either one works; use whichever you
remember.

### ⚠️ `AQ_LOG` is not the switch

It is a natural guess, because of the name. `AQ_LOG` is a **file path** — it is
how the session tells every program where to write. It decides *where* these
lines land. `AQ_SWITCHER_TRACE` decides *whether they are written at all*. You
need the second one.

### ⚠️ There is no `aq switcher trace` command, on purpose

`aq` is the operating system's command, and it lives in the **os-image**
repository, not this one. The shell cannot add subcommands to it from here. If a
subcommand is ever wanted, it belongs beside `aq keys` in
`os-image/system_files/usr/bin/aq`, and all it would do is what the two recipes
above do by hand.

### What the lines look like, and how to read one

```
[shell] switcher +0000ms open-request   reason=shut delta=1 entries=6 currentIndex=0 selected=1 app=org.gnome.Nautilus at=…
[shell] switcher +0002ms surface        visible=true at=…
[shell] switcher +0041ms focus-gained   at=…
[shell] switcher +0388ms key-release    key=Super_L code=0x1000053 mods=0x0 repeat=false grace=false saw=false restart=false selected=1 at=…
[shell] switcher +0388ms decision       action=none grace=arm handled=true restart=false at=…
[shell] switcher +0449ms grace-fired    interval=60 at=…
[shell] switcher +0449ms commit         selected=1 of=6 expanded=false app=org.gnome.Nautilus target=org.gnome.Nautilus@0x55f1… at=…
[shell] switcher +0450ms go-to          target=org.gnome.Nautilus@0x55f1… unminimised=false at=…
[shell] switcher +0550ms focus-check    wanted=org.gnome.Nautilus@0x55f1… got=org.gnome.Nautilus@0x55f1… match=true at=…
```

The `+NNNNms` is **milliseconds since the panel opened**, not the time of day.
Every question anybody has ever had about this feature is a question about how
many milliseconds apart two things were, so that is the number on the front of
every line. The time of day is on the end, as `at=`, for lining up against the
rest of the log.

You do not have to interpret it. But if you want to, here is the short version of
what a miss looks like in each of the four shapes it could take:

| What you see in the trace | What it means |
|---|---|
| no `key-release` line at all, then nothing | the release of ⌘ never reached the panel — the fast tap, the known gap. Look at how long `focus-gained` took. |
| `commit` and `go-to` happen, then `focus-check … match=false`, then `retry`, then `activate-failed` | the panel did everything right and **the compositor refused to bring the app forward**. This is the candidate nobody could prove by reading. |
| `commit-empty` or `commit-stale` | the selection pointed at nothing, or at a window that had closed. Should be impossible now that the list is frozen; if it appears, the freeze has a hole. |
| `commit-skipped` | something closed the panel in the sixty milliseconds between letting go and the switch. |


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
7. **The fast tap, and the recovery (2026-09-14).** Tap ⌘Tab as fast as you can.
   The panel may still stay up with nothing switched — that is the known gap,
   and it is a measurement, not a bug report. What is now being tested is what
   happens **next**: tap ⌘Tab a second time, at a normal speed, and let go. You
   should land on the app you were last in — the same place one clean ⌘Tab would
   have taken you — and *not* two apps along. Say which happened.
8. **⌘↓ still works after a fast tap.** With a fast tap's panel still up, hold ⌘
   and press ↓: the selected app's window list should open, as it always has.
   This is the case the fast-tap rule must not break.
9. **The trace, on a miss (2026-09-15).** Follow "When the switcher misses: how
   to capture it" above, use ⌘Tab until it misses once, and send the lines. This
   is the most valuable single thing on this list — it is worth more than the
   other eight put together, because it is the only one that produces evidence
   rather than an opinion.
10. **A window opening mid-gesture.** Hold ⌘ and tap Tab, and while the panel is
    up have something open a new window (a Resolve render finishing, a
    notification opening a window, `xdg-open` from a second terminal). The tiles
    must **not** move or renumber while you are looking at them, and letting go
    must land on the tile you were on. This is the frozen-list fix of
    2026-09-15.
11. **A window closing mid-gesture.** The same, but close a window instead. The
    panel must not renumber; if you had that window selected, letting go should
    simply do nothing rather than switching somewhere unexpected.
12. **Switching TO DaVinci Resolve, repeatedly.** Resolve is an XWayland client,
    which is the kind most likely to ignore an activation request. ⌘Tab to it and
    away from it twenty times. With the trace on, any `activate-failed` line
    here is the answer to the whole bug.
13. **Switching to a minimised window.** Minimise something, ⌘Tab to it. It
    should come back up. With the trace on, `go-to … unminimised=true` and then
    `focus-check … match=true`.
