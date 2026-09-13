# Screenshots and screen recording

*The two buttons at the right of the top bar, and the one program behind them.*
Feature 017. Written for somebody who has never used Linux.

---

## What you see

At the right of the top bar, just before the system tray and the Wi-Fi/sound/
battery button, there are two small icons:

| Icon | What it is |
|---|---|
| a camera | **Screenshot** — takes a picture of the screen |
| a circle with a dot in it | **Record** — records a video of the screen |

Click either one and the same little menu opens under it:

```
┌────────────────────────────┐
│  Whole screen              │
│  An app                    │
│  Select an area            │
└────────────────────────────┘
```

*Whole screen* takes everything. *An app* lets you pick one open window. *Select
an area* lets you drag a box with the mouse. Up and down arrows walk the menu,
Enter chooses, Escape closes it.

**While a recording is running** the record button turns red and grows a clock —
`00:07`, `01:32` — counting how long it has been going. Clicking it then does not
open the menu: it **stops the recording**, because that is the only thing anybody
wants in that moment.

Everything lands in the **Screenshots** folder in your home folder, and that
folder is pinned in the Files app's sidebar.

---

## What the shell does, and what it does not

The shell draws the two buttons and the menus. It takes no pictures and records
no video. All of that is one small program the operating system installs:

```
/usr/libexec/aquarius-capture
```

The shell runs it with one of five instructions and never does anything else:

| The shell runs | What happens |
|---|---|
| `aquarius-capture shot screen`/`window`/`area` | a picture is taken, saved, copied to the clipboard, and a notification is raised — all by the helper |
| `aquarius-capture record screen`/`window`/`area` | a recording starts, and the command returns straight away |
| `aquarius-capture record stop` | the recording stops |
| `aquarius-capture status` | prints one line of JSON saying whether a recording is running, since when, into which file, and for how many seconds. **Always succeeds.** |
| `aquarius-capture folder` | prints where captures are saved |

That list is a **contract**. It is shared, word for word, with the `os-image`
repository, which is where the helper itself is built. If it ever changes, it
changes in both places in the same sitting.

**Why it is arranged this way.** This shell's one architectural law (see
`README.md`) is that it speaks only standardised Wayland protocols and never a
single compositor's private back door. Taking a picture of the screen is exactly
the kind of thing a shell is tempted to break that law for. Handing the job to a
command keeps the law intact, and it means the picture-taking program can be
swapped on the image — `grim` today, something else tomorrow — without a line of
QML changing.

---

## Who remembers that a recording is running

**Nobody in the shell.** The helper does.

A recording can be started three ways: the bar button, a keyboard shortcut, or a
person typing the command in a terminal. And the shell restarts far more often
than you would think — saving any `.qml` file in the harness reloads it. If the
shell tried to remember, it would be wrong within a day.

So `services/CaptureService.qml` **asks**: once at start-up, once a second while
it believes a recording is running (which is what makes the clock tick), and once
every five seconds the rest of the time (which is what turns the button red when
a keyboard shortcut started the recording). The helper's answer is the only thing
that ever sets `recording`, `elapsedSeconds` or `lastFile` — a test enforces
that.

---

## On a machine with no helper

Every developer's machine, and the nested harness, have no
`/usr/libexec/aquarius-capture`. Then:

* both buttons still draw and both menus still open — the bar is the same shape
  everywhere, which is much easier to reason about than a bar that rearranges
  itself depending on where it woke up;
* choosing anything writes **one clear warning** to the log and does nothing;
* nothing throws, nothing crashes, nothing is left half-started.

To try the whole thing end to end anyway, the repository carries a **fake
helper** that answers the entire contract out of a temporary file:

```
tests/fixtures/capture/aquarius-capture
```

Both harness scripts point the shell at it automatically, through the
environment variable `AQ_CAPTURE_BIN`. So `./harness/run-nested.sh` gives you a
working record button — it goes red, the clock counts, clicking stops it — with
nothing installed. Point that variable somewhere else to use a different helper:

```bash
AQ_CAPTURE_BIN=/usr/libexec/aquarius-capture ./harness/run-nested.sh
```

---

## The keyboard shortcuts

⌘⇧3, ⌘⇧4, ⌘⇧5 and ⌘⇧6 on the Mac layout (and PrtSc, Shift-PrtSc, Win-Shift-S and
Win-Alt-R on the Windows one) are bound to the same helper, in labwc's `rc.xml`.

**Those bindings are written in the `os-image` repository**, not here. The four
labwc files under `session/labwc/` in this repository are a *mirror* of that
copy, kept honest by `check-labwc-drift.sh`. They are synced **after** the
os-image change lands — never guessed at from this side.

---

## Where the pieces are

| File | What it is |
|---|---|
| `services/CaptureService.qml` | the only place in the shell that talks to the helper |
| `components/bar/CaptureMenu.qml` | the three-row menu, in the Aquarius menu's style |
| `components/bar/StatusCluster.qml` | the two buttons themselves |
| `components/quicksettings/QsGlyph.qml` | the `camera` and `record` drawings |
| `tests/fixtures/capture/aquarius-capture` | the fake helper |
| `tests/test-shell.sh`, section 45 | the checks, including a real run of that fake helper |

---

## Not in version one

Annotations, a delayed capture, sound in recordings, and GIF export. Each is a
small follow-up; none of them is here yet.
