# The first run on real hardware

*2026-09-01, on the AquariusOS bench PC (Ryzen 9 9950X3D, RTX 4090, GNOME
session). Everything in this repo had been written on a Mac, where no QML engine
and no Wayland compositor exist. This page is the record of the day it was first
executed: what broke, what was fixed, and — the part that matters — what is now
genuinely proven versus what is still only written down.*

---

## The short version

**It runs.** The bar, the dock, Quick Settings, the notifications panel and Flow
Search all draw, and all five read real data from the real machine.

Four failures stopped it loading, and each one had passed every check in
`tests/test-shell.sh` first. A fifth was breaking a component silently. All five
are fixed and committed, one commit each.

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
| 5 | *(no error — it just looked wrong)* | The bar wore a crossed-out Wi-Fi mark on a desk PC that has no wireless adapter at all. |

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
- **Quick Settings reads the real machine**: Wi-Fi *No adapter*, Bluetooth
  showing the actually-connected MX Vertical, Performance *Balanced*, and a
  sound slider at the system's real 38%.
- **Flow Search works.** `12.5 * 8` gives 100 with *press Enter to copy*; typing
  letters finds real applications with real icons.
- **The shell is the notification daemon.** `notify-send` in, toast out, and the
  panel groups them by application with counts, a collapse chevron, timestamps,
  *Clear all*, and the footer clock with *Focus until morning*.

## What is still NOT proven

- **Both gates.** P1's *does it feel better than the themed panel?* and P2's
  *OBS records, Steam desktop works, a full workday survives* are judgement
  calls that need Royce at the machine, not a screenshot.
- **The real login session.** Everything above ran in the nested harness. The
  session in `session/` — picking Aquarius at the login screen — has still never
  been logged into. That is the next real step, and `docs/session.md` has it.
- **Anything interactive beyond opening.** Clicking a search result to launch an
  app, the inline reply on a notification, the Focus timer surviving a restart,
  dragging a dock tile — all still only written.
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

1. **The two empty squares in the bar.** They are deliberate placeholders for
   *Drop* and *Search*. But Flow Search now exists, so the Search one could
   simply open it. Wire it up, or keep both as placeholders until Drop is real?
2. **Fuzzy search breadth.** Typing `fi` returns Starfield, DaVinci Resolve and
   Alacritty — the matcher weighs several fields, not just the name. Right call,
   or should the name carry more weight?
3. **Text truncation in the Quick Settings tiles.** *MX Vertical ·…* and
   *Notifications…* both clip. Live with it, widen the tiles, or shorten what
   they say?
