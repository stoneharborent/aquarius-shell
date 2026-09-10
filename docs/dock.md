# The dock

*The second real piece of the Aquarius Shell. Bottom-centred, pinned apps plus
running ones, with the running dot the design has been asking for since V2.*

> **R6 update, 2026-09-06.** Two changes landed together, both Royce's call:
> the dashed **"+" tile at the right end is gone**, replaced by a **live list of
> the external drives that are mounted right now** (see
> [Mounted drives](#mounted-drives) below); and the **slab is a touch darker**
> than the bar now (`Theme.dockSurface`, one step off `panel`) so it has an edge
> against the very light Ice desktop it floats over instead of washing into it.
> The `Theme.panel` → `Theme.dockSurface` swap is the only colour change; the
> borderless icons and the running-dot contrast are untouched.
>
> **Bench fixes, later the same day.** The first run of that drives list showed
> **about thirty tiles with nothing plugged in** — they were the folders in the
> home directory. Qt's `FolderListModel` silently lists the process's working
> directory when the folder it is given does not exist at the moment it is
> created, and `/run/media/<user>` does not exist until the first drive is
> mounted. It is fixed, and the trap is written out in
> [Mounted drives](#mounted-drives) so nobody re-introduces it. The **Settings
> tile** also did nothing when clicked, for a completely separate reason that
> had nothing to do with the dock — see
> [The Settings tile is a special case](#the-settings-tile-is-a-special-case).

**It runs — 2026-09-01, on the bench PC.** The dock draws its six pinned apps
with their real artwork, the hairline rule and the `+` tile, and opening an
application added a tile with **the running dot underneath it**. Details and
screenshots: [`first-run-on-hardware.md`](first-run-on-hardware.md).

That is drawing and running-state, and no more. Everything a person does TO the
dock — clicking a tile to launch or focus, the hover lift, dragging to reorder,
the `+` tile's app grid — is still only written. The
[Not proven](#not-proven) section is the list, and [On the
bench](#on-the-bench-what-to-actually-do) is the sequence that settles the rest.

---

## What it is

```
              ╭───────────────────────────────────────────╮
              │  ◆   ◆   ◆   ◆   ◆   ◆   │   ┌ ─ ┐        │
              │  ●   ●                       ╷ + ╷        │
              ╰───────────────────────────────────────────╯
                 ^                       ^     ^
                 |                       |     opens the app grid (one day)
                 |                       a hairline rule
                 pinned and running apps; a dot under each running one
```

A floating slab, centred along the bottom edge, 15px clear of it. Inside: one
66px tile per app, 14px apart, with 20px of space at the ends and 14px above and
below.

**The tiles are invisible.** Each app is its own icon sitting on the slab, with
nothing drawn around it — no pane, no outline. The slab is the only box. See
[**No box around the icon**](#no-box-around-the-icon) for why that changed on
2026-09-04.

### The dock is deliberately larger than the rest of the shell

Those numbers are **1.5x** the V2 artboard's (44px tile, 9px apart, 13/9 of
padding, 10px off the screen edge). Everywhere else in the shell — the bar, the
panels, the search palette, the type scale — the artboard number is multiplied
by **1.25**. That is not drift and it is not a rounding accident. It is Royce's
call on the bench, 2026-09-03, looking at the shell on a 55" 4K Odyssey Ark with
the session output scale at 1.25:

> 1.25 reads right for the whole shell, except the dock, which should be the
> size it has at 1.5.

There is a reason it lands differently. The bar and the panels are **read** —
they hold text, and text has a legible size of its own. The dock is **aimed
at**: it is a row of click targets you hit with a pointer from across a very
large desk, and a pointer target wants to be bigger than the type beside it.
Docks on other desktops are outsized relative to their panels for the same
reason.

The whole `THE DOCK` block in `theme/Theme.qml` moves together — tile, gap,
padding, slab corner, screen margin, dot, hover lift, glyphs. Growing only the
tile would put a 66px icon inside a slab still built for a 44px one, and the
dock would read as badly padded rather than bigger.

`tests/test-shell.sh` **section 31** guards this. It asserts the dock tile stays
roughly 1.75x the bar's height (66/38 = 1.74, in a 1.60–1.90 band), because
"the bar is a touch tall, take it to 34" is a one-token edit that would quietly
shrink the dock's apparent size and nobody would connect the two.

| File | What it does |
|---|---|
| `components/dock/Dock.qml` | The layer-shell panel, one per monitor, and the slab it draws. Owns the `appGridRequested` seam. |
| `components/dock/DockItem.qml` | One app: tile, icon, hover lift, running dots, and what a click does. |
| `components/dock/DockDrives.qml` | The live list of mounted external drives at the right end (R6). |
| `components/dock/DockDrive.qml` | One mounted drive: glyph, open in Files, right-click to eject (R6). |
| `components/dock/DockAddTile.qml` | The dashed `+` tile. **No longer drawn** (the drives list took its place, R6); the file is kept because the structural tests still list it and it is one Rectangle from returning if an app grid ever wants a launch tile. |
| `components/dock/DockModel.qml` | Turns *pinned list* + *live windows* into one ordered list of tiles. |
| `components/dock/DockConfig.qml` | Reads `~/.config/aquarius-shell/dock.json`. |
| `theme/Theme.qml` | Every number above, in the block headed **THE DOCK**. |

## Mounted drives

The right end of the dock (R6, 2026-09-06) is a live list of the removable /
external drives that are plugged in and mounted right now — one tile per drive,
with a separator before them. Plug a drive in and a tile appears; unplug it and
it goes. **When nothing is plugged in, the dock draws nothing there** — no
separator, no placeholder.

- **Left-click** opens the drive in the file manager (`xdg-open <mount path>`).
- **Right-click** offers *Eject / Unmount*, which unmounts it through GVfs/GIO
  (`gio mount -u -f <mount path>`).
- Each tile draws the shell's own **drive glyph** (from `QsGlyph`) rather than
  app artwork, because a drive has no `.desktop` entry; the volume's name is on
  the tile's accessibility label and at the head of the right-click menu.

**Where the list comes from — the standardised route, and why this one.** The
task was to read the mounts through UDisks2 over D-Bus or the GVfs/GIO volume
monitor, whichever the shipped Quickshell can do cleanly. The shipped build
(quickshell 0.2.1 git, Qt 6.11) has **neither** binding — there is no storage
service in its probed module list — so there is no D-Bus object to bind to from
QML without hand-rolling a client, which the standardised-protocols law exists to
avoid. What *is* clean, standard and reactive is watching the directory udisks2
mounts removable drives into — `/run/media/<user>/<label>` — with Qt's own
`FolderListModel`, which updates the instant a mount appears or disappears, no
polling and no compositor-specific anything. It is a plain reading of the mount
table's user-facing face. The trade, written down so nobody has to rediscover
it: it depends on the os-image side auto-mounting removable drives to
`/run/media` (which it does, passwordless) and on `Qt.labs.folderlistmodel`
being present — and it is behind a `Loader` so a missing module costs the drives
list and nothing else. Unmounting takes the GIO road because `gio mount -u` is
the one unmount that works from a mount **path** alone, which is all a directory
listing gives us. When a UDisks2 or GIO binding lands in a future Quickshell,
`DockDrives.qml` is the one file that changes.

### ⚠️ The trap underneath it: a model that lists the wrong directory

**What happened.** On the bench on 2026-09-06, with nothing plugged into the
machine, the right end of the dock drew about thirty tiles — *"a bunch of random
folders instead of external drives"*. They were the folders in Royce's home
directory.

**Why.** Not the path, and not udisks2. It is what Qt's `FolderListModel` does
when the folder it is given does not exist **at the moment the model is
created**. From `qquickfolderlistmodel.cpp`, in `componentComplete()`:

```cpp
QString localPath = QQmlFile::urlToLocalFileOrQrc(d->currentDir);
if (localPath.isEmpty() || !QDir(localPath).exists())
    setFolder(QUrl::fromLocalFile(QDir::currentPath()));
```

A missing directory does not make the model empty and does not make it complain:
it re-points the model at the **process's current working directory**. The shell
is started from the session, whose working directory is the user's home — so
every folder in the home directory became a "drive". And `/run/media/<user>` is
missing most of the time, because udisks2 creates it on the first mount and
removes it after the last unmount. So on a machine with nothing plugged in at
login — the ordinary case — the model was always born pointing at the wrong
place, and since `folder` was bound to a constant it never re-pointed when a real
drive appeared later.

(Calling `setFolder()` later with a missing directory is *not* the same thing —
that just empties the model. The silent substitution happens only at completion,
which is why "set it again when it appears" is not the fix.)

**How it is fixed.** The list is a chain of three watchers, each level created
only while the level above says its directory exists, and destroyed when it goes:

```
/run                    always exists — the one model created unconditionally
  └─ has "media"?  ──▶  /run/media            (created by a Loader)
        └─ has "<user>"?  ──▶  /run/media/<user>   (created by a Loader — the list)
```

Because a `FolderListModel` has no "list nothing" switch, **not creating it** is
the switch — hence the Loaders. And because a Loader builds a *fresh* model each
time it becomes active, plugging a drive in an hour after login now builds the
list properly instead of being ignored.

**Belt and braces.** Each created model also reads its own `folder` back once it
is complete and compares it to the directory that was asked for. That is a direct
question about whether the fallback fired, because the fallback works by writing
into that very property. A mismatch marks the model unhealthy, warns once on the
console, and makes `hasDrives` false — so a listing the shell does not trust
draws **nothing**, not somebody's home directory. `tests/test-shell.sh`
**section 35b** guards the whole shape of this.

**The honest edges.** The existence checks re-run when the listing above them
changes size; a directory swapped for another in the same instant, with the count
landing back where it started, would not be noticed until the next change — the
health check is the net under that. A username containing characters a URL has to
escape would fail the read-back comparison and leave the list empty, which fails
safe rather than wrong.

### It was finally tested, 8 September 2026 — and it works

The bench list of 8 September said *"drives appear in Files but not in the
dock"*, and the open question was the one this whole section is about: does the
chain notice a folder that is created **after** the shell has started? On the
bench that is exactly what happens — the shell starts at login and `/run/media`
does not exist until the first drive is plugged in, a minute later.

Nobody could test it, because making `/run/media/<you>` appear on demand needs
root, and a test that needs root is a test that never runs. So the chain can now
be pointed at a folder anybody can create:

```bash
AQ_MEDIA_ROOT=/tmp/fake/media/tester ./harness/run-nested.sh
```

Everything then behaves exactly as it does on a real machine: the grandparent is
watched, the parent is watched, and the drives are the subfolders. The recipe,
step by step, is in [`../harness/README.md`](../harness/README.md). On a real
login the variable is unset and the folder is `/run/media/<you>`; the Aquarius
session sets it nowhere.

**What was measured**, with the shell running in an invisible labwc on the bench
PC and screenshots of the real dock at each step:

| Step | The dock drew |
|---|---|
| nothing mounted | no separator, no tiles — the right end of the dock is simply not there |
| the media folders appear (udisks making them for the first mount) | still nothing; there are no drives yet |
| one drive mounted | the hairline separator, then one tile |
| a second drive | separator, then two tiles |
| both unmounted | back to no separator and no tiles |
| the folders removed again | unchanged — nothing |

Every step landed within about a second, and it behaved the same whether the
folders existed before the shell started or appeared afterwards. Pointed at the
**real** `/run/media/rorobeckley` in the live session — where the shell had
started a minute before the first drive was plugged in — it listed both mounted
volumes, and a screenshot of the running dock showed both tiles.

**So the dock was already drawing the drives.** What is easy to miss is what a
drive tile looks like: a small, quiet, line-drawn mark with **no label under
it**. Two of them at the right-hand end of a dock read as "two empty squares"
rather than "my two drives" — especially next to the app icons, which are all
full-colour artwork. That is a design question and it is left open here rather
than answered quietly: the honest options are a label under the tile, the
volume's own icon where the drive has one, or nothing at all on the grounds that
hovering already names it. **Royce's call.**

---

## The pinned list

### Where it lives

```
~/.config/aquarius-shell/dock.json
```

`$XDG_CONFIG_HOME` is honoured if it is set, per the freedesktop base-directory
specification.

### The format

```json
{
  "pinned": [
    "org.gnome.Nautilus.desktop",
    "org.mozilla.firefox.desktop",
    "steam.desktop",
    "aquarius-editor.desktop",
    "aquarius-writer.desktop",
    "org.gnome.Settings.desktop"
  ]
}
```

One key. `pinned` is a list of desktop-entry names, in the order they should
appear left to right.

- **A name may be written with or without `.desktop`.** Both work. The `.desktop`
  form is what you will have seen everywhere else, so it would be unkind to
  reject it.
- **A name that matches nothing installed is skipped.** No warning, no gap, no
  error — the slot is simply not drawn. This is the same rule the KDE dock
  followed, and it is what makes a typo cost one slot instead of the dock.
- **To find the right name for an app**, look in `/usr/share/applications/` on a
  running machine and use the filename.
- **The order is yours.** Running apps that are not in the list are appended
  after it, in the order their first window appeared.

### The defaults

If the file does not exist, these six are used:

> Files · Firefox · Steam · Aquarius Editor · Aquarius Writer · Settings

That is **not a fresh opinion**. It is the exact list, in the exact order, that
the shipping OS puts in GNOME's dock —
`os-image/system_files/usr/share/glib-2.0/schemas/zz1-aquarius-20-shell.gschema.override`,
the `favorite-apps` line, which also records why each one earns a permanent seat.
If that list changes, change `DockConfig.defaultPinned` to match rather than
inventing a second answer.

### Creating the file

The shell **never writes this file unless you ask it to.** Nothing is created at
start-up, no default copy is written, and if the file is absent the defaults
above simply stand — a shell that creates files you did not ask for is a shell
you cannot predict. Since 2026-09-06 there *is* a gesture that changes the list
(*Keep in Dock* / *Remove from Dock* in a tile's right-click menu), and that is
the only thing that writes. To start by hand instead, make it yourself:

```bash
mkdir -p ~/.config/aquarius-shell
cat > ~/.config/aquarius-shell/dock.json <<'JSON'
{
  "pinned": [
    "org.gnome.Nautilus.desktop",
    "org.mozilla.firefox.desktop",
    "steam.desktop",
    "aquarius-editor.desktop",
    "aquarius-writer.desktop",
    "org.gnome.Settings.desktop"
  ]
}
JSON
```

**Save it and the dock reorders while you watch.** `DockConfig` sets
`watchChanges: true` and reloads on change, which is Quickshell's own documented
pattern. No restart.

### Pinning writes the file

*Right-click a tile → **Keep in Dock** or **Remove from Dock**.* That is the only
thing in the shell that changes `dock.json`.

- **`writeAdapter()`, not `setText()`.** The `JsonAdapter` already holds the list
  in the exact shape the file wants, so the whole write is: change the adapter's
  property, call `writeAdapter()`, let it serialise. Building JSON by hand here
  would be a second opinion about the format living three lines from the first.
- **The dock moves immediately, before the disk write comes back.** `pinned` is a
  binding onto the adapter's property, so the model rebuilds the moment the list
  changes. The write then lands, `watchChanges` sees the file it just wrote,
  `reload()` reads it, and the adapter ends up holding what is on disk. That
  round trip is redundant and harmless — and it is what keeps this working when
  the file is *also* being edited in a text editor.
- **The list is reassigned, never pushed onto.** Pushing onto the existing array
  changes it without the property system noticing, and the dock would not redraw
  until something unrelated touched the binding.
- **A name is written with `.desktop` on the end,** because that is how every
  name in the defaults and in the example above is written, and a file somebody
  opens should look like the one the documentation showed them. The reader
  accepts either spelling, and *unpin* removes **every** spelling of the app —
  a hand-edited file can perfectly well contain both `steam` and `steam.desktop`,
  and removing one of them leaves the tile exactly where it was.
- **Keeping an app puts it at the end,** which is where the tile already was: an
  unpinned running app is drawn after every pinned one, so it does not jump out
  from under the pointer.

**⚠️ The parent directory is the one thing that can go wrong.** `FileView` writes
a file; it does not create the folder above it, and `~/.config/aquarius-shell/`
does not exist on a machine where nobody has hand-edited `dock.json` — which is
every fresh install. So the first pin fails, and it fails silently unless
something is listening. `onSaveFailed` is what listens: it runs `mkdir -p` on the
folder **once** and retries. Not before the first attempt (a shell that spawns a
process at start-up on the off-chance is exactly what the no-unprompted-writes
rule was written against), and not twice — a second failure means something real,
like a read-only home directory, and a retry loop would hide it. If both attempts
fail, the list in memory is still right and the dock still shows it; what is lost
is that the change does not survive a restart, and a warning says so.

`tests/test-shell.sh` **section 37b** checks all of that: the three functions, the
adapter write, the reassignment, the failure handler, the one-shot `mkdir`, and
that nothing writes at start-up.

---

## The API surface

### `Dock`

```qml
Dock {
    reserveSpace: true                  // default
    onAppGridRequested: /* ... */
}
```

| Member | Type | What it is |
|---|---|---|
| `appGridRequested()` | signal | The `+` tile was clicked, or `qs ipc call dock openAppGrid` was run. **Wired to nothing.** |
| `reserveSpace` | `bool`, default `true` | Whether the compositor keeps the dock's strip of screen clear, so a maximised window stops above the dock instead of sliding under it. `false` gives a dock that floats over windows in the macOS manner. |

### The app-grid seam

The dashed `+` is meant to open **Flow Search** — the full-screen app grid and
search box the design draws. That is being built separately, and **this dock does
not import it, name it, or depend on it.** There is one signal, reachable two
ways:

```qml
// 1. from QML
Dock { onAppGridRequested: searchPalette.open() }
```

```bash
# 2. from anywhere else — a keybinding, a script, another part of the shell
qs ipc call dock openAppGrid
```

Both land on the same signal, so whoever wires the palette in changes `shell.qml`
and nothing else. Today `shell.qml` connects it to a line of log output, exactly
as the top bar's own launcher signal is connected — a button that prints a line
is honest about being unfinished; a button that opens an empty box is not.

The IPC target name is `dock`, and IPC targets must be unique across the whole
shell. If another component wants that name, one of them moves.

### What a click does

| Situation | Left click | Middle click |
|---|---|---|
| Pinned, not running | launch it | launch it |
| One window, focused | minimise it | launch a second copy |
| One window, not focused (or minimised) | un-minimise and focus it | launch a second copy |
| Several windows | focus the next one after whichever is focused, wrapping | launch another copy |

Cycling rather than opening a window picker is a decision, not an oversight: a
picker needs a popup, a layout and a keyboard story, none of which this dock has
yet. Cycling is obvious after one try, and the whole behaviour is
`DockItem.activate()` when the picker arrives.

### Right-click a tile

*Added 2026-09-06 — the bench note was four words: "right click on the apps does
nothing".* The drives at the other end of the same dock already had a menu; the
app tiles ignored the right button entirely, because their `MouseArea` listed
only `Qt.LeftButton | Qt.MiddleButton`.

```
┌──────────────────────────┐
│  Firefox                 │   the app's name — quiet, not clickable
├──────────────────────────┤
│  New Window              │   "Open" when nothing is running
│  Remove from Dock        │   "Keep in Dock" when it is not pinned
├──────────────────────────┤
│  Quit                    │   only while windows are open
└──────────────────────────┘
```

It is drawn **by the shell**, the same way the drive menu next to it is — a
`PopupWindow` with `grabFocus`, hanging above the tile — out of the same
`MenuRow` the Aquarius menu at the top-left uses. All three menus in the shell
are one design rather than three.

| Row | What it does |
|---|---|
| the app's name | Nothing. A quiet header, so the menu says what it is about — exactly what the drive menu does with the volume's name. |
| **Open** / **New Window** | `DockItem.launch()` — the same road the middle button takes, and the same one that knows Settings is a special case. The label changes because "Open" reads wrong for something already open. |
| **Keep in Dock** / **Remove from Dock** | `DockConfig.pin()` / `.unpin()`. Writes `dock.json`; see [Pinning writes the file](#pinning-writes-the-file). |
| **Quit** | Closes every window this app owns, through each Wayland toplevel's own `close()`. |

- **Esc closes it. A click anywhere else closes it.** The click-away is the
  compositor's doing (`grabFocus: true`); Esc needs the popup grab to deliver key
  events, which is the half of this that is *not proven* — and the half that
  matters least, since the click-away works either way.
- **Opening it closes every other overlay,** and they close it.
  `services/Overlays.qml` holds that rule; `DockDrive`'s menu joined the same
  registry on the same day, because with two kinds of menu in one dock "opening
  one closes the other" stopped being a nicety.
- **It closes before it acts.** Quit and the pin toggle both change the things
  the menu is drawn from — the window list, and whether this tile exists at all —
  and a menu still on screen while its own tile is taken out from under it is a
  menu hanging in mid-air.
- **Right-clicking the tile again** has the same wrinkle Quick Settings
  documents: the compositor dismisses the popup because the tile is "outside",
  and the tile's own handler would reopen it immediately. The same 250 ms guard
  is used, and it is a heuristic, not a protocol.
- **No app-specific knowledge lands in `DockItem`.** The menu is built from what
  a `DesktopEntry` offers everybody — a name, and the ability to run — plus the
  two things the tile already knew: whether it is pinned, and which windows it
  owns.

**Quit copies the window list first.** `close()` makes the compositor drop the
window, which rebuilds the very list the loop is walking, so iterating the live
one skips windows and a five-window app is left with two open. That reads as Quit
being unreliable rather than as a bug in a loop, which is the worst kind of bug
to have. And `close()` is a *request*: an app with unsaved work may put up a
dialog and stay, which is correct behaviour, not a failed Quit.

*(The KDE dock had a right-click menu too, most of it built from a C++ helper
this shell does not have. What is here is the part that can be built honestly:
launch, pin, quit. A window picker is still absent for the same reason cycling is
— it needs a popup, a layout and a keyboard story.)*

### The Settings tile is a special case

Every tile launches its app the ordinary way — `DesktopEntry.execute()`, which is
`execDetached` with the entry's own parsed command. Exactly one program on the
machine cannot be started that way, and on 2026-09-06 the bench found it: clicking
the **Settings** icon did nothing at all.

Nothing to do with the dock. GNOME's Settings app reads `XDG_CURRENT_DESKTOP` and
exits immediately — printing `Running gnome-control-center is only supported under
GNOME and Unity, exiting` where nobody can see it — unless one of the
colon-separated names is `GNOME`, and an Aquarius session deliberately calls
itself `aquarius-labwc:aquarius:wlroots` (that name is how the desktop portals are
found, so it cannot change). Running its `.desktop` entry runs that same command,
so the dock hit the same wall as the Aquarius menu and the Quick Settings
chevrons.

So `DockItem.launch()` asks first:

```qml
if (SettingsLauncher.ownsDesktopEntry(root.entry)) {
    SettingsLauncher.open("");
    return;
}
root.entry.execute();
```

The dock knows nothing about that program; it asks the shell's one Settings door,
`services/SettingsLauncher.qml`, which is also what the Aquarius menu, the Quick
Settings chevrons and the search palette use, and which runs it as `env
XDG_CURRENT_DESKTOP=GNOME gnome-control-center`. Every other entry on the machine
takes the ordinary road. The whole story is in
[`logo-menu.md`](logo-menu.md#opening-settings).

---

## Decisions, and the reasons

### It is centred because it is anchored to one edge

`PanelWindow { anchors { bottom: true } }` — bottom and nothing else. That is not
a trick; it is what the protocol says happens. From
`wlr-layer-shell-unstable-v1`'s own description of `set_anchor`:

> "If two orthogonal edges are specified … the anchor point will be the
> intersection of the edges …; otherwise the anchor point will be centered on
> that edge"

One anchor, so the compositor centres us — on every compositor, with no
arithmetic on our side, and nothing to redo when a monitor is plugged in or the
resolution changes.

The window is exactly the size of the slab, so `margins.bottom` is the gap under
it, and the window's own colour is `transparent` — otherwise the corners outside
the slab's 16px radius would be painted in and the dock would look like a
rectangle wearing a picture of rounded corners.

### The running dot, done properly at last

The design has asked for this since V2:

```css
.dock-ico i { bottom:-7px; left:50%; margin-left:-2px;
              width:4px; height:4px; border-radius:50%;
              background: var(--starlight) }
```

A small round mark, centred, just under a running app's tile. **The KDE version
of this dock could not draw it.** Plasma builds a tile from nine pieces of one
SVG and stretches the middle ones, so a dot drawn in the middle piece comes out
as a bar the width of the tile, and a dot drawn in a corner piece stays welded to
that corner. There is no piece that is both fixed-size and centred, so that dock
shipped a 2px underline instead and wrote the compromise down (its
`FORK-NOTES.md`, entry B2).

None of that constrains plain QML. This is a `Rectangle` with a `radius`,
anchored to `horizontalCenter`. The design, drawn as drawn.

`bottom:-7px` is CSS for "the dot's bottom edge sits 7px below the tile's bottom
edge". With a 4px dot that is a 3px gap, which is `Theme.dockDotGap`. 3 + 4 = 7,
and the dock's 9px bottom padding holds it with 2px to spare.

**One deliberate extension: one dot per window, up to three.** A dock that shows
the same single dot whether an app has one window or nine is hiding the thing you
need to know before you click. With one window — the common case, and the case
the design draws — this is pixel-for-pixel the design's single centred dot.
Beyond three the dots would out-measure the tile they belong to, so three is the
cap.

**The dot does not rise with the tile.** In the design's HTML it does, but only
because it is a CSS child inheriting the tile's transform, not because anyone
decided it should. A running mark that jumps about reads as noise. Same call the
KDE dock made, for the same reason.

**Its colour says which app you are in.** `Theme.accent` when this is the
focused app, `Theme.inkMute` when it is merely open. Both solid.

That is a change from 2026-09-04, and the reason is the tiles going away. The
dot used to be `Theme.accent` at two opacities — 0.55 running, 0.8
running-and-focused, the numbers the Plasma theme's `tasks.svg` used. Those
worked while every icon sat on its own recessed pane: the pane said "app", so
the dot only had to whisper "and it is open". With the panes gone the dot is the
only thing left saying an app is running, and a whisper does not carry. Measured
against each theme's panel colour:

| | Ice | Midnight |
|---|---|---|
| old, running (accent @ 0.55) | **1.9:1** | 3.3:1 |
| old, focused (accent @ 0.8) | **2.6:1** | 5.4:1 |
| new, running (`inkMute`) | 3.0:1 | 3.1:1 |
| new, focused (`accent`) | 3.3:1 | 7.7:1 |

WCAG asks 3:1 of a non-text indicator. Ice failed both states and Midnight
passed both, which is exactly the trap a light theme sets: the author's dark
screen looks fine. Two solid colours clear the bar on both themes, and hue is a
distinction a light theme can carry where a difference in fadedness is not.

### No box around the icon

Until 2026-09-04 every tile painted its own pane — `Theme.surfaceAlt` with a
hairline of `Theme.line` around it, straight off the V2 artboard, which draws
`.dock-ico` as a bordered rounded rectangle because it had two-letter
placeholders to put inside rather than real icons.

On the bench, on a 55" screen at output scale 1.25, that read as a row of little
boxes with icons trapped inside them rather than as a row of icons. Six visible
outlines competing with the six pieces of artwork they were framing, inside a
slab that already draws the only frame the group needs. Royce's words:
**"remove the clear borders around the apps in the dock."**

So the icon sits on the slab, and the slab is the box — which is what every dock
people already use does (macOS, the GNOME dash, Latte), for the same reason: an
app icon is artwork somebody designed to be looked at, and a second outline
around it is noise.

Three things the pane was **not** doing, and which all still happen:

* the **hover lift** — the tile still rises 6px and grows to 108%;
* the **press wash** — `Theme.pressWash` at `Theme.dockTileRadius`, so a click
  is still acknowledged, and still with the tile's own corner;
* the **running dot**, which never sat on the pane in the first place. It hangs
  *below* the tile, in the slab's bottom padding, so its background was
  `Theme.panel` before this change and is `Theme.panel` after it. Removing the
  pane did not touch it — but it did make it the only running indicator left,
  which is why its colours changed too. See "The running dot" above.

`Theme.dockTileRadius` and `Theme.dockTileInset` both stay: the press wash and
the `+` tile shape themselves to the first, and the icon is still inset inside
its 66px slot by the second. Putting the pane back, if anyone ever wants it, is
one `Rectangle` in `DockItem.qml`.

### The hover lift moves the whole tile

`translateY(-4px) scale(1.08)` over `--dur-fast` (120ms) on `--ease-out`
(`cubic-bezier(.22, 1, .36, 1)`), all of it from `Theme`.

The KDE version had to lift **the icon only** and leave the tile still, because
moving the tile dragged Plasma's highlight artwork off the dock's border. That
constraint does not exist here either, so the whole tile lifts — which, since the
tile stopped painting a background on 2026-09-04, is the icon and the press wash.
There is no artwork left that could be dragged off anything, so this cannot come
back.

The mouse area does **not** move with it. If it followed the lift, the pointer
would leave it the instant the tile moved, the tile would drop, and the whole
thing would judder.

### No glass, no shadow

The design floats a blurred translucent slab with a drop shadow. This shell does
neither. The top bar dropped glass for the same reason (`BarItem.qml`'s note, and
the Plasma theme's "Glass removed" decision), and Ice is a light theme where a
heavy shadow reads as grime. Solid `Theme.panel`, one hairline of `Theme.line`.

If a shadow is wanted later it is `QtQuick.Effects`' `MultiEffect`, and it is a
design decision before it is a code one.

### Matching a window to an app

A window reports an `appId` (`org.gnome.Nautilus`, `firefox`, `steam`). A pinned
slot names a `.desktop` file. Those agree less often than you would hope, so the
dock does not try to be clever — it asks Quickshell:

```qml
DesktopEntries.heuristicLookup(appId)
```

which tries an exact id match, then a case-insensitive id match, then matches the
appId against each entry's `StartupWMClass`, exactly and then case-insensitively.
(Read out of quickshell's own `src/core/desktopentry.cpp`, because the published
docs only say "will try to guess".) If it finds an entry, that entry's id **is**
the app's identity and the window joins whichever tile carries it. If it finds
nothing, the window becomes its own tile keyed on its raw appId — visible and
clickable, just unnamed, which beats vanishing.

An id, incidentally, never carries the `.desktop` ending: quickshell builds it
from the file's base name. That is why `DockModel.pinnedEntry()` strips it before
falling back to `byId()`.

**When it goes wrong, it is almost always the entry, not the lookup.** DaVinci
Resolve on the bench, 8 September 2026, is the worked example: no icon, no name,
its own anonymous tile. Its window calls itself `resolve`, and the menu entry
`distrobox-export` had written said

```
StartupWMClass=/usr/share/applications/com.blackmagicdesign.resolve.desktop
```

— a file path where a class name belongs. Nothing could match those two.

The repair is one line in the `os-image` repository, which owns the installer:
`StartupWMClass=resolve`. That it is enough was checked from this side rather
than assumed — an entry carrying it, written while the shell was already
running, was found by the lookup within a couple of seconds, from `resolve` and
from `Resolve`. (And yes, the index **does** pick up a `.desktop` file written
after the shell started; that was measured too. See
[`flow-search.md`](flow-search.md).)

### Rearranging the dock — drag a pinned app

Press a pinned app and carry it left or right; the other pinned apps step aside,
and the new order is written to `dock.json` the moment the tile crosses a
neighbour, so it survives a restart. Let go and the tile settles into its slot.

The mechanism is deliberately plain. `DockItem.qml` floats the carried tile with
the pointer (the `x` on the tile's lift `Translate`) and counts how many whole
slots — a tile plus the gap — it has moved from where the Row put it. It counts
from the tile's OWN index, not an absolute position on screen, so it does not
matter where the dock sits: after each swap the Row re-lays the tile into its new
slot, the offset is recomputed, and the count settles to zero. Each swap calls
`DockConfig.movePinnedBy()`, which rewrites the pinned list by normalised name
and clamps to the list, so a running (unpinned) app is never a drop target and
dragging past the end just parks the tile there. A press that turns into a drag
is not treated as a click, so carrying an app never also launches it.

### Icons, and the two-letter fallback

`Quickshell.iconPath(name, true)` resolves an icon name against the icon theme Qt
is using, so the dock's icons match every other application on the machine. The
`true` means "give me an empty string if it does not exist" rather than the
missing-texture image — which is what lets the fallback know it is needed.

The fallback is the app's first two letters, in the display face at 13px. That is
not an invention: it is literally what the design draws in its tiles (`Fi`, `St`,
`Kd`, `OB`, `Me`, `Se`).

### The dashed outline is a `Shape`, not a `Canvas`

A QML `Rectangle`'s border is always solid. The KDE version painted the dashed
tile with a `Canvas`. `QtQuick.Shapes` is the better tool: `strokeStyle:
ShapePath.DashLine` with a `dashPattern` gives dashes directly, it is the same
machinery the Aquarius mark in the top bar already uses, and it repaints on a
property change without a `Canvas`'s manual `requestPaint()` bookkeeping.
`dashPattern` is measured in multiples of the stroke width, so with a hairline
stroke `[3, 3]` is a 3px dash and a 3px gap.

The rounded rectangle is written out as an SVG path rather than using
`PathRectangle`, which says the same thing in one line but only arrived in Qt
6.8. The shell should not acquire a version floor for a dashed outline.

The renderer is left at Qt's default (`GeometryRenderer`) rather than being
switched to `CurveRenderer` the way `LogoMark` does. Qt's documentation makes no
promise about dash patterns under the curve renderer, and this is a fixed-size
rounded rectangle that gains nothing from it. **Do not "optimise" that without
checking on a machine.**

### Every colour comes from `Theme`

There is not one hex value in `components/dock/`, and `tests/test-shell.sh`
fails if one appears. The V2 artboard's colour tokens map onto ours like this:

| V2 token | Here | Why |
|---|---|---|
| `--starlight` (the accent) | `Theme.accent` | The running dot. |
| `--text-3` (tertiary ink) | `Theme.inkMute` | The `+` and its dashed outline. |
| `--border-2` (stronger rule) | `Theme.lineStrong` | The separator before the `+`. |
| the slab's translucent fill | `Theme.panel` | Solid — see "No glass". |
| the tile's faint fill | *(not drawn)* | Removed 2026-09-04 — see "No box around the icon". It was `Theme.surfaceAlt`. |
| the tile's 1px border | *(not drawn)* | Removed with it. It was `Theme.line`. |
| `--text-3` again | `Theme.inkMute` | The running dot of an app that is open but not focused. |

**No new colour role was needed**, so `Ice.qml` and `Midnight.qml` are untouched.
What *was* added to `Theme.qml` is a block of dock geometry (`dockTileSize`,
`dockGap`, `dockLift`, …) and the two dot opacities, all measured off the V2
artboard and commented with where each number came from — and, since
2026-09-03, all shipping at 1.5x those measurements for the reason given at the
top of this document.

### One dock per monitor, all windows on each

`Variants` builds one copy per screen the compositor reports, the same way the
top bar does. Every dock shows every window, not only the ones on its own
monitor — that is the setting the shipping OS chose for the KDE dock
(`showOnlyCurrentScreen: false`, and "matches how a Mac dock behaves"), kept here
so the two agree while both exist.

`Toplevel` does expose `screens`, so per-monitor filtering is a small change if
it turns out to be wanted.

---

## Not proven

**No QML engine has parsed any of this and no compositor has drawn it.** What has
been checked is what `tests/test-shell.sh` can check from a Mac: brackets
balance, imports are the ones intended, no colour outside `theme/`, every
`Theme.<name>` used is one `Theme.qml` actually declares, no Plasma leftovers, no
machine-specific paths. That is real, and it is not the same as working.

Everything below is a specific thing that could be wrong. In rough order of how
likely it is to bite:

1. **That the dock is centred at all.** The reasoning from the protocol text is
   sound, but "anchored to one edge ⇒ compositor centres it" has not been seen
   happen. If it comes out flush left, this is the line to look at.
2. **The exclusive zone.** `exclusiveZone: implicitHeight + margin` on a
   *narrow, centred* window. The protocol says a positive zone is meaningful for
   a surface anchored to one edge, but whether a compositor reserves a full-width
   strip or only the dock's own width is implementation-defined, and both
   behaviours are defensible. Watch what a maximised window does.
3. **`color: "transparent"` on a `PanelWindow`.** The `QsWindow` docs warn that a
   window which is opaque before it is shown cannot become transparent later. It
   is set transparent from the start, which should be the safe order — but
   whether the corners outside the slab's radius actually show the wallpaper
   through has not been seen. If they come out white, `surfaceFormat.opaque:
   false` is the next thing to try.
4. **Whether `heuristicLookup` matches the apps that matter.** Firefox as a
   Flatpak, Steam, and anything Electron are the classic offenders. The dock
   degrades safely — an unmatched window becomes its own unnamed tile — but a
   pinned Firefox that does not light up when Firefox is running is the failure
   to watch for.
5. **`JsonAdapter` with a `list<string>` and a missing key.** If `dock.json`
   exists but has no `pinned` key, the adapter is expected to leave the default
   in place. The docs say properties are updated "if their values have changed",
   which reads that way but does not say it outright.
6. **`Quickshell.iconPath()` given an absolute path.** Some `.desktop` files put
   a full path in `Icon=` rather than a theme name. Untested; the fallback is the
   two-letter tile, so the worst case is ugly rather than broken.
7. **`DesktopEntry.execute()`** for a Flatpak app, and whether it needs
   `workingDirectory` passed. The docs say `execute()` is equivalent to
   `execDetached` with both, so it should be handled. Settings is the one entry
   that never reaches `execute()` — see [The Settings tile is a special
   case](#the-settings-tile-is-a-special-case) — and the id it is matched on
   (`org.gnome.Settings`, or `gnome-control-center` on older packaging) has not
   been read off the shipped machine, so check that the tile really opens the app
   rather than merely stopping doing nothing.
8. **`minimized = true` as a way to hide a focused window.** It is a *request*;
   `Toplevel`'s docs say a compositor may ignore it. If clicking a focused app's
   tile does nothing on the bench, that is why, and the fallback is to drop the
   minimise behaviour rather than fight it.
9. **The `void DesktopEntries.applications.values.length;` line in
   `DockModel.qml`.** It exists purely to make the model rebuild when an app is
   installed or removed. If that turns out not to establish the dependency, the
   symptom is a newly-installed pinned app not appearing until the shell reloads
   — cosmetic, and only on that one event.
10. **Delegate churn.** Every window opening or closing rebuilds the whole
    `items` array, so the `Repeater` recreates every tile. It is deliberately
    simple; if it visibly flickers on the bench, the fix is a keyed model rather
    than a plain array.
11. **The `+` tile's corner radius.** It keeps the design's 11px radius on a box
    that has been inset by 6px, so it is proportionally rounder than an app
    tile's corner. That is what the KDE port did too. It may want to be
    `11 - inset` once somebody looks at it side by side.
12. **`qsTr("%n window(s) open", "", n)`** — the plural form. Nothing translates
    this shell yet, so it renders the source string; the `%n` substitution itself
    is untested.
13. **A `Loader` holding a non-visual object.** The drives chain has each level's
    `FolderListModel` created by a `Loader` through `sourceComponent`, because not
    creating a model is the only way to stop it listing the wrong directory. Qt
    documents `Loader.item` as a `QtObject` and Loader as able to load a
    non-visual component, but this repo has never done it before. If the models
    never appear, that is the first thing to check, and the fallback is
    `Instantiator` from `QtQml`, which is built for non-visual delegates.
14. **Whether the drives chain actually recovers.** Plugging a drive in *after*
    login is the case the old code got wrong and the case a static check cannot
    prove. It is step 14 on the bench list below.
15. **Whether **Esc** reaches the tile's right-click menu.** A compositor holding
    an `xdg_popup` grab sends key events to the grabbing surface, so the card
    inside it should be able to have keyboard focus — but no compositor has been
    in front of this. If Esc does nothing, the menu is still perfectly usable:
    clicking anywhere else closes it, and that is the compositor's own doing.
16. **The 250 ms reopen guard on that menu.** Copied from
    `QuickSettingsPopup.qml`, where it is also unproven. Symptom if the number is
    wrong: right-clicking a tile a second time makes the menu flicker and never
    close, or makes the *first* right-click after closing one do nothing.
17. **The first pin on a machine with no `~/.config/aquarius-shell/`.** The
    `mkdir -p`-and-retry path has never run. Symptom: pinning appears to work —
    the tile moves — and the change is gone after a shell restart, with
    `aquarius-shell: could not save ...` in the log. The 200 ms wait before the
    retry is a pause, not a handshake, because a detached process gives nothing
    to wait on.
18. **`Toplevel.close()` on several windows at once.** Each is a request and each
    application answers for itself; an app with unsaved work is *supposed* to put
    up a dialog and stay. Quit having "not worked" and Quit having been declined
    look identical from here.

---

## On the bench: what to actually do

On a Linux machine, from the repo root:

```bash
./harness/run-nested.sh
```

Then, in order:

1. **Look at the bottom of the nested window.** A pale slab should be centred
   there, 10px clear of the bottom edge, with rounded corners that show the
   desktop through — not white squares. If there is no slab at all, read the
   terminal: Quickshell prints QML errors in full, with file and line.

2. **Count the tiles.** With no config file you should get the six defaults, less
   any that are not installed on that machine, then a hairline, then a dashed
   `+`. On a plain Fedora box that will probably be one or two tiles and the `+`
   — that is correct behaviour, not a bug.

3. **Hover a tile.** It should rise 4px and grow slightly, over about an eighth
   of a second, easing to a stop rather than snapping. Move the pointer back and
   forth quickly: it must not judder or stick.

4. **Open something.** From another terminal:

   ```bash
   niri msg action spawn -- kgx      # or gnome-terminal, alacritty, foot
   ```

   A tile should appear for it (or its pinned tile should light up), with **one
   small round dot centred underneath**. That dot is the whole point of this
   component — if it is a bar, or off to one side, something is wrong with the
   anchor in `DockItem.qml`.

5. **Open a second window of the same app.** Two dots, still centred as a pair.

6. **Click that tile repeatedly.** Focus should walk from one window to the
   other and back. With only one window open, clicking the focused app should
   minimise it and clicking again should bring it back.

7. **Middle-click a tile.** A second copy of that app should open.

8. **Maximise a window.** With `reserveSpace: true` it should stop above the dock,
   not slide under it. Note whether the reserved strip is the full screen width
   or only the dock's width — item 2 in *Not proven*.

9. **Write the config file** (the command is under [Creating the
   file](#creating-the-file)), then reorder the list and save. The dock should
   reorder without a restart. Put a deliberate typo in one name: that slot should
   vanish and everything else should carry on.

10. **Click the `+`.** The terminal should print
    `aquarius-shell: app grid requested (P2)` and nothing should happen visually.
    That is the correct behaviour today.

11. **From another terminal:** `qs ipc call dock openAppGrid`. Same line should
    print. That is the seam the search branch will use.

12. **Flip the theme.** Change `dark` to `true` in `theme/Theme.qml` and save.
    The whole dock should repaint into Midnight with no restart and nothing left
    in Ice colours.

13. **Plug in a second monitor**, if the bench has one. A second dock should
    appear, centred on that screen, showing the same apps.

14. **The drives, in this order, because the order is the bug.** Start the shell
    with **nothing plugged in**: the right end of the dock must be empty — no
    separator, no tiles, and above all not a row of your home folders (that is
    the 2026-09-06 failure, and the console would say
    `aquarius-shell: dock drives:` if the health check caught a substitution).
    *Then* plug a USB drive in, while it is running: a tile should appear, with
    the separator before it. Unplug it: both should go. Plug it in again: the
    tile should come back. That last one is the recovery the old code did not
    have. `ls /run/media/$USER` in a terminal is the ground truth to compare
    against.

15. **Right-click an app tile.** A small menu should appear above it, in Ice,
    looking like the Aquarius menu at the top-left: the app's name in grey at the
    top, a hairline, then the rows. Hover down them — each should light as the
    pointer crosses it. Press **Esc** (it should close; if it does not, that is
    item 15 in *Not proven* and not a blocker). Right-click the tile again and
    make sure the menu closes rather than flickering.

16. **Right-click a *running* app.** It should say **New Window** and offer
    **Quit**; a tile with nothing running should say **Open** and offer no Quit
    at all. Click Quit with two windows open — **both** should close, not one.

17. **Pin and unpin.** Open something that is not in the dock, right-click its
    tile, choose **Keep in Dock**. The tile should stay after you close the app.
    Check the file actually changed:

    ```bash
    cat ~/.config/aquarius-shell/dock.json
    ```

    On a machine where that folder did not exist, this is the first write ever —
    watch the log for `aquarius-shell: could not save`. Then right-click a pinned
    app and choose **Remove from Dock**: the tile should leave the moment the app
    is closed, and the name should be gone from the file.

18. **Right-click a drive tile while an app's menu is open** (and the other way
    round). Only one menu should ever be on screen — that is
    `services/Overlays.qml` doing its job.

19. **Click the Settings tile.** GNOME's Settings should open. If it does not,
    run `env XDG_CURRENT_DESKTOP=GNOME gnome-control-center` in a terminal inside
    the session: if that opens the window, the tile is not going through
    `SettingsLauncher`; if it does not, the problem has moved into the app
    itself. See [The Settings tile is a special
    case](#the-settings-tile-is-a-special-case).

Write down what actually happened. The roadmap's P1 gate — *does it feel better
than the themed panel?* — has a dock-shaped sibling, and it can only be answered
by looking at it.

### Drive labels and Mac folders (10 September 2026)

Hover over a drive to see its name above the dock. The label uses the current
light or dark palette and does not take keyboard focus or intercept clicks.
Long names shorten in the middle to keep both ends visible.

Clicking a drive opens Files. APFS-FUSE mounts expose an extra `root` folder
beside `private-dir`; the dock now opens that `root` directly. The opener checks
the exact mount's filesystem type before using it, so an ordinary drive with a
folder named `root` still opens at its normal top level. Eject continues to use
the actual mount, never the content folder.

Bench check: hover each drive, click it, and confirm the expected files appear.
Right-click should show the drive menu in place of the hover label. Move away
and confirm the label disappears. This shortcut does not change Files' sidebar
or how file copying and merging work.
