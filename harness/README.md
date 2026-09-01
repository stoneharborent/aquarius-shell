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
  no battery glyph (a desktop has no battery) and no Wi-Fi glyph (no wireless
  adapter in it). A laptop shows all three. Any system-tray icons appear here
  too.
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
| Quick Settings reads **"No adapter"**, or the battery/Wi-Fi glyphs are missing | Nothing. That is the machine being described accurately | The desk PC has no battery and no wireless card. On a laptop they appear. |
| Every reading is blank and the log repeats **"Could not connect to DBus"** | You are in a container with no system message bus | The script wires the host's in automatically when it can see `/run/host`. Outside a distrobox, check the machine really is running one. |
| **Notifications never arrive** | GNOME owns the notification service on this bus | `AQ_PRIVATE_BUS=1 ./harness/run-nested.sh` — see Step 3. |
| The bar shows but **windows go underneath it** | The reserved-space request was refused | Note which window manager, and file it. Both niri and labwc should honour it. |
| The app name says **Desktop** even with a window open | The compositor is not reporting windows | Check it supports `wlr-foreign-toplevel-management`. niri and labwc both do. |
| Everything is **very slow** | You are in an emulated x86 VM on Apple Silicon | Expected, and it makes the P1 "does it feel better?" gate impossible to judge. Use real hardware. |

---

## What this harness is *not*

It is **not** the AquariusOS desktop. It is a window with a small desktop in it,
for building and looking at the shell.

The real thing — this shell as a login session you can pick at the login screen,
next to GNOME — is **Phase P2**. It lives in `../session/`, and the step-by-step
walkthrough is **[`../docs/session.md`](../docs/session.md)**.

Do the harness first. If the bar does not draw in a window, nothing on that page
will help.
