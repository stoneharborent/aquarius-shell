# The dock

*The second real piece of the Aquarius Shell. Bottom-centred, pinned apps plus
running ones, with the running dot the design has been asking for since V2.*

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
              │  ▣   ▣   ▣   ▣   ▣   ▣   │   ┌ ─ ┐        │
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
| `components/dock/DockAddTile.qml` | The dashed `+` tile. |
| `components/dock/DockModel.qml` | Turns *pinned list* + *live windows* into one ordered list of tiles. |
| `components/dock/DockConfig.qml` | Reads `~/.config/aquarius-shell/dock.json`. |
| `theme/Theme.qml` | Every number above, in the block headed **THE DOCK**. |

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

The shell **reads this file and never writes it.** There is no pin/unpin gesture
yet, so there is nothing for it to save, and a shell that creates files you did
not ask for is a shell you cannot predict. To start editing, make it yourself:

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

When pin/unpin does arrive it belongs in `DockConfig.qml` — `FileView.setText()`,
or a `JsonAdapter` write through `writeAdapter()`. The reader is already the
right shape for it.

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

There is **no right-click menu.** The KDE dock had one, most of it built from a
C++ helper this shell does not have. An empty menu is worse than no menu.

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

**Its two opacities** — 0.55 running, 0.8 running-and-focused — are the numbers
the Plasma theme's `tasks.svg` used for the same two states. Keeping both lets
the dock say which of several open apps you are actually in, at no cost in ink.

### The hover lift moves the whole tile

`translateY(-4px) scale(1.08)` over `--dur-fast` (120ms) on `--ease-out`
(`cubic-bezier(.22, 1, .36, 1)`), all of it from `Theme`.

The KDE version had to lift **the icon only** and leave the tile still, because
moving the tile dragged Plasma's highlight artwork off the dock's border. That
constraint does not exist here either, so the whole tile lifts — background,
border and icon together — which is what the CSS actually says.

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
| the tile's faint fill | `Theme.surfaceAlt` | A slightly recessed surface reads as a tile on both Ice and Midnight. |
| the tile's 1px border | `Theme.line` | |

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
   `execDetached` with both, so it should be handled.
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

Write down what actually happened. The roadmap's P1 gate — *does it feel better
than the themed panel?* — has a dock-shaped sibling, and it can only be answered
by looking at it.
