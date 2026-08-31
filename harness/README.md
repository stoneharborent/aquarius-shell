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
probably have none of them, and the bar will fall back to whatever sans-serif
font that machine has. It will look slightly wrong and work perfectly. To match
the design exactly, install them — the Google Fonts versions are the right ones.

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

A window opens. Across the top **of that window** there is a pale, near-white bar
about 30 pixels tall with:

- the Aquarius mark (the "A" with a wave through it) on the far left,
- the word **Desktop** next to it in bold — that is the "active app name", and
  with nothing open yet, there is no app to name,
- three faint empty squares near the right — placeholders holding space for
  Phase P2's Wi-Fi, battery and search icons,
- the date and time on the far right, with the date in a quieter grey than the
  time.

Now open something inside that window to see the bar do its job. Press the nested
window manager's terminal shortcut, or from another terminal:

```bash
# for niri
niri msg action spawn -- kgx      # or: gnome-terminal, alacritty, foot
```

The bold word next to the Aquarius mark should change from **Desktop** to the
name of whatever you opened. That is the shell reading the focused window through
the standard foreign-toplevel protocol — the same protocol on every compositor,
which is the whole architectural bet.

---

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
| The bar is there but the text is **boxes or the wrong font** | Sora / Inter are not installed | Harmless. Install the fonts, or ignore it — nothing about the layout depends on them. |
| The bar shows but **windows go underneath it** | The reserved-space request was refused | Note which window manager, and file it. Both niri and labwc should honour it. |
| The app name says **Desktop** even with a window open | The compositor is not reporting windows | Check it supports `wlr-foreign-toplevel-management`. niri and labwc both do. |
| Everything is **very slow** | You are in an emulated x86 VM on Apple Silicon | Expected, and it makes the P1 "does it feel better?" gate impossible to judge. Use real hardware. |

---

## What this harness is *not*

It is **not** the AquariusOS desktop. It is a window with a small desktop in it,
for building and looking at the shell.

The real thing — this shell as a login session you can pick at the login screen,
next to GNOME — is **Phase P2**. See `../docs/ROADMAP.md`.
