# Running the Aquarius Shell — step by step

*Written for somebody who has never used Linux. Every command is one line you can
copy. If a step does not do what it says, the "When it does not work" section at
the bottom lists what has actually gone wrong for people.*

---

## The one thing to understand first

A bar across the top of a screen is not just a window that happens to be at the
top. It has to **ask the window manager for permission** to be a bar — to sit
above other windows, to keep that strip of screen reserved so maximised windows
do not slide underneath it.

That request is made through a published Wayland protocol called
**wlr-layer-shell**. Lots of window managers implement it. **GNOME's does not**,
and GNOME has declined to for years.

AquariusOS now ships GNOME. So:

> **You cannot run this shell as the actual bar on AquariusOS today.** Not
> because the shell is unfinished — because GNOME will not take the request.

The way we develop it anyway is to run a *different* window manager **inside a
window**, and put our bar in there. Everything inside that window is a small,
complete desktop with its own rules. Our bar is a real bar in it.

That is what `run-nested.sh` does.

---

## What you need

- **A Linux machine.** The AquariusOS bench PC, any Fedora box, or a Fedora /
  Bazzite virtual machine on **x86** hardware.
- **A Wayland login session.** Modern Fedora and Bazzite give you one by default.
- **Two programs**, installed below.

> **This does not run on a Mac. At all.** Not in a terminal, not in Docker.
> Wayland does not exist on macOS. On an Apple Silicon Mac, an x86 Linux VM is
> also slow emulation, so use real hardware if you want to judge how the bar
> *feels* — which is the whole point of Phase P1's gate.

---

## Step 1 — install the two programs

**On Fedora (including the bench machine, if it is plain Fedora):**

```bash
sudo dnf install quickshell niri
```

- `quickshell` is the program that reads our `.qml` files and draws the bar. It
  is in Fedora's own repositories, so nothing extra is needed.
- `niri` is the small window manager we run inside a window. Also in Fedora's own
  repositories. `labwc` works too and is the alternative the roadmap is weighing
  — install it with `sudo dnf install labwc` if you want to try both.

**If `quickshell` is not found** — this happens on older Fedora releases, where
it has not landed yet. Add the community repository that carries it:

```bash
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell
```

**On Bazzite / AquariusOS itself**, the system is read-only and `dnf install`
does not work the way it does elsewhere. Two options:

```bash
# Option 1 — a throwaway container with the tools inside it (preferred)
distrobox create --name aq-shell --image fedora:latest
distrobox enter aq-shell
sudo dnf install quickshell niri
```

```bash
# Option 2 — layer them onto the system itself, then reboot
rpm-ostree install quickshell niri
systemctl reboot
```

Option 1 leaves the real system untouched, which is the point of an atomic OS.
Prefer it while this is a prototype.

**Fonts.** The OS ships Sora, Inter and JetBrains Mono. On a plain Fedora box you
probably have none of them, and the bar falls back to whatever sans-serif that
machine has — it looks slightly wrong and works perfectly. (`Theme.qml` asks the
machine which of the three it actually has and picks per family, so a missing
font is never a row of empty boxes.)

**Inside a distrobox, the fonts are already on the machine — just not visible to
the container.** distrobox mounts the whole host under `/run/host`, so one file
inside the box points fontconfig at the real AquariusOS fonts and the harness
renders in the true type:

```bash
mkdir -p ~/.config/fontconfig
printf '%s\n' '<?xml version="1.0"?>' \
  '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">' \
  '<fontconfig><dir>/run/host/usr/share/fonts</dir></fontconfig>' \
  > ~/.config/fontconfig/fonts.conf
fc-cache -f
```

Check it worked with `fc-match Inter` — it should answer `Inter-Regular.ttf`, not
a substitute.

---

## Step 2 — run it

From the `aquarius-shell` folder:

```bash
./harness/run-nested.sh
```

To use labwc instead of niri:

```bash
AQ_COMPOSITOR=labwc ./harness/run-nested.sh
```

---

## Step 3 — what you should see

*Rewritten 2026-09-01, after the first time any of this ran. The list below is
what was actually on screen, not what was expected.*

A window opens with a small desktop in it. In that window:

- **The bar across the top.** The Aquarius mark (the "A") on the far left, the
  word **Desktop** beside it in bold — the focused app's name, and with nothing
  open there is no app to name — and the date and time on the far right, the
  date in a quieter grey than the time.
- **Two faint empty squares** left of the status icons. These are deliberate:
  placeholders holding space for **Drop** and **Search**, which are not built
  yet. They are drawn deliberately un-clickable so they cannot pretend to work.
- **The status icons**, which tell the truth about the machine and so differ
  from machine to machine. On the bench PC that is a speaker and nothing else:
  no battery glyph, because a desktop has no battery. It was also recorded as
  having no Wi-Fi glyph, on the belief that the machine had no wireless card —
  **it has one, `wlp7s0`** (corrected 2026-09-02, see
  [`../docs/quick-settings.md`](../docs/quick-settings.md)), so a quiet
  crossed-out Wi-Fi mark should appear a moment after the bar draws. Whether it
  does has not been looked at yet. A laptop shows all three. Any system-tray
  icons appear here too.
- **The dock**, centred at the bottom.

**Which theme you get is not a choice the shell makes.** It follows the system's
light/dark setting through the standard portal, the same one GNOME apps read. On
a machine set to dark you get **Midnight**; on light, or where nothing answers,
you get **Ice**. A dark bar is not a bug.

Now open something inside that window to see the bar do its job:

```bash
# from another terminal, with NIRI_SOCKET pointing at the nested niri
niri msg action spawn -- alacritty
```

The bold word next to the Aquarius mark should change from **Desktop** to the
name of whatever you opened. That is the shell reading the focused window through
the standard foreign-toplevel protocol — the same protocol on every compositor,
which is the whole architectural bet.

### Driving the panels without touching the mouse

Useful when you want the same screenshot twice, or are working over a terminal.
The shell publishes an IPC interface; ask it what it has:

```bash
qs -p . ipc show
```

```bash
qs -p . ipc call search open     # the Flow Search palette
qs -p . ipc call search close
qs -p . ipc call dock openAppGrid
qs -p . ipc call lock lock           # the lock screen (there is no unlock call)
```

**The shell's bindings are loaded in the nested window** — the harness starts
labwc with a folder generated from `session/labwc/` (as the real session does)
and niri with `harness/niri-nested.kdl`. **But the desktop you are sitting in
sees every key first**, and GNOME keeps the ones that matter most: Super+L
(its lock), Alt+Tab and Super+Tab (its own switcher), Super+` (its window
cycler). Press them and GNOME acts on *your* desktop; the nested one never
hears it. That is not a bug in the shell and there is no setting for it.
Super+Space and Super+Return do get through.

So drive those pieces by hand from another terminal, in the shell's folder.
The messages are exactly what the key bindings send:

```bash
qs -p . ipc call lock lock         # the lock screen (nested window only)
qs -p . ipc call switcher next     # open the app switcher, or step forward
qs -p . ipc call switcher prev     # step back
qs -p . ipc call switcher down     # into the selected app's windows
qs -p . ipc call switcher go       # go to what is selected, and close
qs -p . ipc call switcher cancel   # close, changing nothing
```

**To see the window frame, the round buttons and the right-click menu you
need a window INSIDE the nested session.** Right-click the nested desktop for
the menu. For a window, press **Super+Return** with the nested window focused:
it opens a terminal in there, with the Aquarius frame around it. (Apps clicked
in the dock mostly open on your real desktop instead — Files, Settings and
their kind hand the request to the copy already running out there.) In a
distrobox the container needs a terminal to open; the harness tries `ptyxis`,
`foot`, `alacritty`, `kitty` and `xterm` in that order, so install one:

```bash
sudo dnf install foot
```

`qs` only talks to an instance started on the same display, so run these with
`WAYLAND_DISPLAY` set to the NESTED session's socket (`wayland-1`, usually), not
your login session's `wayland-0`. `qs list --all` shows every running instance
and which display each one is on.

Quick Settings and the notifications panel open by clicking the bar — the status
icons and the clock respectively. `wlrctl pointer move` and `wlrctl pointer
click left` will do it from a script.

> **Do not park the pointer at 0,0** to get a known position. That is niri's
> hot corner, and it drops niri's own overview over everything — a dimmed screen
> with a shrunken copy of the desktop in the middle. The harness config turns
> hot corners off for exactly this reason, but if you are running niri some
> other way, that grey rectangle in your screenshot is the overview, not a bug
> in the shell.

### Testing the drives at the right end of the dock

The dock shows one tile per external drive that is plugged in and mounted. It
finds them by watching the folder udisks2 mounts removable drives into —
`/run/media/<your name>` — and the thing that is hard to test is that **that
folder does not exist most of the time**. udisks2 creates it when the first
drive is mounted and removes it again after the last one is unmounted, so on a
real machine the shell almost always starts with it missing and has to notice it
appearing later.

You cannot make `/run/media/somebody` appear on demand without being root. So
the dock can be pointed at a folder you *can* create:

```bash
AQ_MEDIA_ROOT=/tmp/fake/media/tester ./harness/run-nested.sh
```

Then, from another terminal, be udisks2 by hand:

```bash
mkdir -p /tmp/fake/media/tester            # the first mount creates the folders
mkdir "/tmp/fake/media/tester/My Drive"    # a drive appears
mkdir "/tmp/fake/media/tester/Backup"      # and another
rmdir "/tmp/fake/media/tester/My Drive"    # unplugged
rmdir "/tmp/fake/media/tester/Backup"
rmdir /tmp/fake/media/tester /tmp/fake/media   # the last one is unmounted
```

Watch the right-hand end of the dock after each line. A tile should appear
within about a second, and the hairline separator before the tiles should only
be there while there is at least one.

Two rules about the path you give it:

* it has to be **at least two folders deep** (`…/media/tester`), because the
  dock watches the folder, its parent and its grandparent — that is what makes
  it notice the middle one being created;
* the **grandparent must already exist** when the shell starts (`/tmp/fake` in
  the example, which `mkdir -p` above makes). On a real machine that is `/run`,
  which always exists. Why any of this matters is the long note at the top of
  `components/dock/DockDrives.qml`.

Unset the variable and you are back to the real thing: `/run/media/<you>`,
which is what every actual login uses.

### Testing notifications

The shell wants to BE the machine's notification daemon, and only one program per
message bus can hold that job. On AquariusOS, GNOME already does — so in the
ordinary harness our shell asks, is refused, and no notification ever arrives.
The log says so plainly:

```
Could not register notification server at org.freedesktop.Notifications,
presumably because one is already registered.
```

Give the nested session a bus of its own instead:

```bash
AQ_PRIVATE_BUS=1 ./harness/run-nested.sh
```

Then, from another terminal in the same container, send one to it:

```bash
DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/aquarius-harness-bus) \
    notify-send -a "Aquarius Editor" "Export complete" "Timeline 01 · 3m 12s"
```

A toast appears at the top right; clicking the clock opens the panel with the
notifications grouped by application. While the private bus is on, the system
tray is empty — the host's applications are on the host's bus. The light/dark
setting still works.

### What the harness can and cannot show you

The nested window is the shell, drawn on top of whatever the machine it runs on
provides. Three things in it are **not** the shell's, and each looks like a
missing feature when it is really a missing ingredient:

| You see | It comes from | What it needs |
|---|---|---|
| **The wallpaper** | `swaybg`, started by the harness (on AquariusOS, by the session's autostart — never by the shell, so the picture survives the shell crashing) | The file `/usr/share/backgrounds/aquarius/the-pour-ice-3840x2160.png`. It is in the AquariusOS image; on any other machine the desktop is plain black. |
| **The app icons** in the dock, search and switcher | The icon theme the harness hands the shell as `QS_ICON_THEME` — the machine's setting, or `Aquarius-Ice` when that theme is installed. The shell asks Qt for "the icon for this app" and draws what it gets. | The `Aquarius-Ice` theme on the machine (in the AquariusOS image since 2026-09-06). The harness prints an `icons:` line saying what it chose and why. **In a distrobox**, two traps: the container's own `gsettings` says "Adwaita" (the harness no longer trusts it), and the container's Qt cannot see SVG-only icons — Files' own icon, for one — until `sudo dnf install qt6-qtsvg` inside the container. The Aquarius icons ship as PNG at every size, so they show either way. |
| **The window frame** — round buttons, corner radius, title font | `session/labwc/generate-theme`, which the harness runs into a folder of its own (since 2026-09-06) | Nothing else. If the buttons are labwc's own squares, the harness printed a warning at start and the reason is in the log it names. |

So on the bench, "no wallpaper and Adwaita icons" means the machine is booted
into an image older than the artwork, not that the shell lost them. Check with:

```bash
rpm-ostree status | head -8
ls /usr/share/backgrounds/aquarius /usr/share/icons | head
```

If the second line lists no `aquarius` folder and no `Aquarius-Ice`, rebase to
the newest image and reboot; the shell will pick both up without a change.

## Step 4 — the working loop

**Leave the window open.** Edit any `.qml` file in this repo, save it, and the
bar reloads within about a second on its own. Quickshell watches the files.

There is no build step, no restart, no rebuilding the OS image. Change a colour
in `theme/Ice.qml`, hit save, watch the bar change.

To stop: close the window, or press **Ctrl-C** in the terminal you started it
from.

---

## When it does not work

| What you see | What is wrong | What to do |
|---|---|---|
| `MISSING qs` | Quickshell is not installed | Step 1. On Fedora it is `quickshell`, and the command it installs is `qs`. |
| `MISSING niri` | The nested window manager is not installed | `sudo dnf install niri` |
| `No Wayland session detected` | You are logged into an X11 session | Log out, and at the login screen pick the Wayland version of your desktop (usually the default). |
| `This script only runs on Linux` | You are on the Mac | Expected. Use the bench machine. |
| The window opens but there is **no bar** | Quickshell started and failed | Look at the terminal. Quickshell prints QML errors there in full, with file and line number. |
| The bar is there but the text is **boxes or the wrong font** | Sora / Inter are not installed | Harmless. Install the fonts, or point fontconfig at the host's — Step 1. |
| The window opens with **a bar, and a waybar above it, and a big "Important Hotkeys" card** | niri read your personal config instead of the harness's | The script passes `-c harness/niri-nested.kdl` precisely so this cannot happen. If you are starting niri by hand, pass it too. |
| **A grey rectangle** sits in the middle of the screen | niri's overview is open — something touched the top-left hot corner | Press Escape. It belongs to niri, not to the shell; the harness config turns hot corners off. |
| Quick Settings reads **"No adapter"**, or the battery/Wi-Fi glyph is missing | The battery one is nothing — a desk PC has no battery. **The Wi-Fi one was a bug**, fixed 2026-09-02 | The bench PC does have a wireless card (`wlp7s0`); a ReferenceError froze the tile on its start-up reading. If you see *No adapter* on a machine that has Wi-Fi, read docs/quick-settings.md. |
| Every reading is blank and the log repeats **"Could not connect to DBus"** | You are in a container with no system message bus | The script wires the host's in automatically when it can see `/run/host`. Outside a distrobox, check the machine really is running one. |
| **Notifications never arrive** | GNOME owns the notification service on this bus | `AQ_PRIVATE_BUS=1 ./harness/run-nested.sh` — see Step 3. |
| The bar shows but **windows go underneath it** | The reserved-space request was refused | Note which window manager, and file it. Both niri and labwc should honour it. |
| The app name says **Desktop** even with a window open | The compositor is not reporting windows | Check it supports `wlr-foreign-toplevel-management`. niri and labwc both do. |
| Everything is **very slow** | You are in an emulated x86 VM on Apple Silicon | Expected, and it makes the P1 "does it feel better?" gate impossible to judge. Use real hardware. |

---

## The load check, and why CI runs it

`run-nested.sh`, above, is for **you**. It opens a window you can look at.

`load-check.sh`, next to it, is for **a build machine** — a computer with no
screen, no graphics card and nobody sitting in front of it. It answers one
question and no others:

> **Does the shell start at all?**

Run it the same way:

```bash
./harness/load-check.sh              # the desktop, the login screen, the lock screen
./harness/load-check.sh shell        # just the desktop
./harness/load-check.sh greeter lock # pick and choose
```

### Why it had to exist

Everything else that checks this repository **reads** the files. `qmllint` reads
them very cleverly. `tests/test-shell.sh` reads them with about forty
repo-specific rules. Neither runs a single line.

That gap has a name and a date. On **6 September 2026** the desktop refused to
start on the bench machine, twice in one day:

```
Failed to load configuration
  caused by @shell.qml[103:5]: LockLayer is not a type
```

and then, once that was fixed, the same thing again with `GreeterAvatar`. Both
were one mistake: **a folder with a `qmldir` file shows the outside world only
what the `qmldir` names**, and neither type was named. Both passed `qmllint`.
Both passed `tests/test-shell.sh`. The only thing on earth that finds that is a
QML engine being asked to load the shell — which, until this script, had never
happened anywhere except on Royce's desk.

It found a third one about a minute after it first ran, on 7 September: the whole
desktop would not load, because `lock/LockLayer.qml` used `Component.onCompleted`
without importing QtQuick. (That one was being fixed on `main` at the same hour,
from the bench — which is the point. The bench found it by somebody driving to
it; this found it in twenty-five seconds, on a machine nobody was sitting at.)

So these failures used to be found by a person, in front of a machine, at the end
of a day. Now they are found by a build, in about five minutes, before anybody
drives anywhere.

### How it works, in plain language

A bar has to ask a window manager for permission to be a bar. With no window
manager to ask, Quickshell never gets as far as reading our QML, so "just run
`qs`" would prove nothing.

So the script starts a **real window manager with no monitor attached**. wlroots
— the toolkit labwc, sway and cage are all built on — has a mode for exactly
this. Four instructions do it:

| Setting | What it means |
|---|---|
| `WLR_BACKENDS=headless` | Do not look for a screen. There isn't one. |
| `WLR_HEADLESS_OUTPUTS=1` | Invent one pretend monitor, because a bar needs a screen to sit on. |
| `WLR_RENDERER=pixman` | Paint with the processor. There is no graphics card. |
| `WLR_LIBINPUT_NO_DEVICES=1` | Do not refuse to start over a missing keyboard and mouse. |

And two more, in Qt's language, for the shell itself: `QT_QPA_PLATFORM=wayland`
(the shell is a Wayland program and nothing else — the same line the real session
sets) and `QT_QUICK_BACKEND=software` (draw with the processor).

Then it starts `qs` inside that, waits **twenty seconds**, and judges it on two
things:

1. **Is it still running?** Quickshell exits when the file it was asked to load
   will not load, so a dead process *is* the answer. This is what all three
   faults above looked like.
2. **What did it say?** A piece the shell builds later — a panel that only
   appears on a click — can fail on its own without taking the whole shell down.
   That only ever shows up as a line in the log, so the log is read too.

**It prefers labwc**, because labwc is the real one — it is what AquariusOS ships
and what the shell runs on in front of a person. sway and cage are understudies,
in case a package is missing or labwc's headless mode ever breaks. A check that
quietly switches itself off is worse than no check, because it still looks green.

### ⚠️ Two of the three entry points do not load today

The **login screen** and the **standalone lock screen** are on a known-broken
list in the script. They are still run, and everything they say is still printed
— they just do not turn the build red, because what is wrong with them is not
something the load check arrived with.

What is wrong is one sentence long. **Quickshell throws away every import that
points outside the config folder**, and the config folder is simply the folder of
the file it was given. The image starts the login screen as

```
qs -p /usr/share/aquarius/shell/greeter/greeter.qml
```

so its config folder is `greeter/`, and `import "../components/bar"` in
`GreeterCard.qml` resolves to nothing at all:

```
Failed to load configuration
  caused by @GreeterCard.qml[65:13]: LogoMark is not a type
```

**No `qmldir` fixes this** — the import is discarded before any `qmldir` is read,
which is what makes it different in kind from the two faults on 6 September.
`qs -p lock/lock.qml` fails the same way, through `LockSurface.qml`.

On a real machine a login screen that will not load is **a black screen with no
way in** — the failure `/usr/libexec/aquarius-greeter-watchdog` exists in the OS
image to catch. It is worth checking whether it is the same one.

There are two ways out, and both need this repository and `os-image` to move
together, which is why the check reports them rather than guessing:

1. **Move the entry file to the top of the repo** — `greeter.qml` beside
   `shell.qml`, keeping `greeter/` for its pieces. Then the config folder is the
   whole shell and every import resolves. It costs one path in the image's
   `aquarius-greeter-shell`.
2. **Stop importing across** — give the login screen its own copy of the mark.
   Cheaper, and a second copy of a logo to keep in step forever.

If either one starts passing, **the build fails on purpose** and asks for the
list to be shortened. A known-broken list nobody ever takes anything off is how a
project ends up with checks that mean nothing.

### What it deliberately ignores

A build machine has no Wi-Fi, no battery, no Bluetooth, no sound card, no login
manager and almost no fonts, and the shell asks about every one of those on the
way up. Each answer is "there isn't one here", which is **true and not a fault**.
If those counted, this check would be red forever and everybody would learn to
ignore it — the one way a check can do actual harm.

So `load-check.sh` carries a list of the complaints an empty machine is expected
to make, and treats anything *not* on that list as a real problem. **Adding to
that list is a decision, not housekeeping.** Read the log line first, and be sure
it is about the empty machine and not about our code.

The list is only ever applied to the *soft* signals — a `TypeError` really is
what a missing battery reading looks like. It is never applied to "is not a
type", "Failed to load configuration" and their kin, because the list contains
the word "Bluetooth", and a genuine failure in `TileBluetooth.qml` would
otherwise be thrown away by its own file path.

### What it still cannot tell you

- **Whether anything looks right.** Nobody looks at the picture. This says "it
  loads", never "the bar is in the right place" or "that is the right blue".
- **Anything that only goes wrong when a person touches it** — a click handler
  with a typo, a keyboard shortcut wired to nothing, a panel that opens in the
  wrong corner.
- **Anything that breaks after the first twenty seconds** — a timer, a leak, a
  reload.

Those are still the bench's job. See
[`../docs/RESUME-ON-BENCH.md`](../docs/RESUME-ON-BENCH.md).

### Where CI runs it

`.github/workflows/lint.yml`, the job called **"The shell actually loads"**. It
runs on Fedora, in a container, on **every push to every branch** and on every
pull request. (That workflow used to run on `main` only, which meant branch work
— where everything actually happens — was never checked at all.)

It builds Quickshell from source rather than installing Fedora's, and that is not
fussiness: Fedora packages a snapshot of **0.2.1**, which has no
`Quickshell.Networking` and no `Quickshell.Bluetooth`, so the shell does not load
on it *at all*. The version it builds is pinned in
[`quickshell-pin.env`](quickshell-pin.env), which is a copy of the pin in the
`os-image` repository — **change one, change both**, or this check is proving
something about a Quickshell nobody has.

That build takes about three minutes, so it is cached, keyed on both the
Quickshell commit **and** the exact Qt that is installed. That second half
matters: a Quickshell is permanently married to the Qt it was compiled against,
and a stale cached copy would die with `undefined symbol` — the same ABI trap
written up in `os-image/build_files/stage-quickshell.sh`.

**How long the whole job takes**, measured on 7 September 2026:

| | Time |
|---|---|
| First run, or after Fedora ships a new Qt (builds Quickshell) | **~4½ minutes** |
| Every run after that (cache hit) | **~1½ minutes** |
| Of which, actually starting the three shells | 25 seconds |

The cache is saved by a step of its own that runs `if: always()`. That is not
tidiness: the all-in-one `actions/cache` writes only in a post step, and that
post step is **skipped when the job fails** — and this job exists in order to
fail sometimes. Without the split, every red build threw away the Quickshell it
had just compiled, so exactly while somebody was iterating on a fix, each attempt
cost an extra three minutes.

---

## The wallpaper check — the first one that makes something *happen*

`load-check.sh` asks one question: does the shell start. `wallpaper-check.sh`,
beside it, is a different kind of check and the first of its kind here — it
starts the real shell and then **makes something happen to it**, and reads what
the shell did about it.

```bash
./harness/wallpaper-check.sh
```

### What it is for

The wallpaper is the one part of "the desktop follows the theme" that the shell
does not draw. `swaybg` puts the picture up, started once by the session at
login, and nothing re-runs it — so a machine flipped to dark had a navy bar, a
navy dock and a *pale* picture behind them. On the bench that read as "the flip
to dark didn't carry over", twice.

The fix is a contract in two halves (`../docs/session.md`): the session ships a
small program that puts the right picture up, and the shell runs it, with one
word, every time the theme flips. This check is the shell's half, proved on its
own — the session's half lives in the `os-image` repository and does not have to
exist for this to run.

### The two fakes, and why faking is honest here

**A fake wallpaper setter.** A script on the PATH that writes down what it was
called with. That is the whole point: we are not testing that `swaybg` works, we
are testing that the shell asks for the right thing.

**A fake `gdbus`.** This one is more interesting. The shell asks the appearance
portal whether the machine is light or dark by running `gdbus`, and hears about
*changes* by leaving a `gdbus monitor` running and reading its output a line at
a time. A build machine has no portal at all — and even this bench PC has only
one, belonging to a person who is using it, so flipping the real setting to run
a test would change the desktop somebody is sitting at.

So `gdbus` is replaced by a script that answers "light" once and then, three
seconds later, prints exactly the line a real `gdbus monitor` prints when
somebody turns the machine dark. Everything after that is the real shell doing
the real thing.

> ⚠️ **That makes this a test of the parser too, deliberately.** The line the
> fake prints was copied from a real `gdbus monitor` on the bench — colons,
> quotes, brackets and all. "The shell is not hearing the change" was one of the
> two suspects behind the lock-screen report of 8 September 2026, and there was
> no way to test it. Now there is: change how that line is read and this check
> goes red.

### What it proves, and what it does not

It proves the setter is called, that it is called with `midnight` and not some
other word, and that it is called **once** — the session has already put the
right picture up before the shell starts, and restarting `swaybg` for nothing
makes the desktop blink. Then it runs the shell again with
`AQ_WALLPAPER_SETTER` unset and proves nothing is run at all.

It does **not** prove the picture changes. That is
`/usr/libexec/aquarius-wallpaper`'s job, it lives in the other repository, and
it is the bench's to look at.

`tests/test-shell.sh` section 44 runs this on any machine that can (Linux, `qs`,
and one of labwc/sway/cage) and says so and skips on any machine that cannot —
so it is green on the Mac without pretending it checked anything.

---

## What this harness is *not*

It is **not** the AquariusOS desktop. It is a window with a small desktop in it,
for building and looking at the shell.

The real thing — this shell as a login session you can pick at the login screen,
next to GNOME — is **Phase P2**. It lives in `../session/`, and the step-by-step
walkthrough is **[`../docs/session.md`](../docs/session.md)**.

Do the harness first. If the bar does not draw in a window, nothing on that page
will help.
