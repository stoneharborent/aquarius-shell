# Logging into the Aquarius Session — step by step

*Written for somebody who has never used Linux. Every command is one line you
can copy. Nothing here can break your machine, and there is a section at the
bottom that undoes all of it.*

---

## Read this first

**The session itself has never been logged into.** This page was written on a
Mac, where there is no Wayland, no compositor, no Quickshell, no systemd and no
D-Bus — so most of it is a *prediction*, checked line by line against the
documentation and source code of the projects involved.

**Pre-flight done 2026-09-01, on the bench PC, without installing anything.**
Before the first login, the assumptions that could be checked from a terminal
were checked, and some of them were wrong. In short:

- The bench PC is running **AquariusOS itself** (`aquarius-os-gnome-nvidia`,
  build 44.20260901). Not Bazzite, not plain Fedora — our own image.
- The login screen is **GDM, not SDDM.** Everything this page used to say about
  SDDM was true of Bazzite's KDE variant and never applied to ours. Corrected
  throughout, and "the session does not appear" below is the section to read
  if GDM turns out not to look in `/usr/local`.
- `/usr/local` **is** a link to `/var/usrlocal`. That assumption held.
- `session/niri/config.kdl` **is valid** — `niri validate` says so.
- The **Super + Space binding was wrong** in both compositor configs, and would
  never have opened the palette. Fixed; see [About Super + Space](#about-super--space).
- Both portal back ends the niri route needs are **already on the OS**. The
  only packages to layer are `quickshell` and `niri` (plus `labwc` and
  `xdg-desktop-portal-wlr` if you want to try labwc). Fedora 44 ships
  Quickshell 0.2.1 — the same version every harness run has used.

What is left is exactly the part that needs a person at the login screen. The
full list is at the bottom, under **[What is unproven](#what-is-unproven)** —
read it before you start, not after.

**Nothing here removes or replaces GNOME.** The Aquarius Session is added *next
to* it on the login screen. If it does not start, you log out and pick GNOME and
your day continues. That rule does not bend, in this document or anywhere else
in the project.

---

## The safe first step: do not do any of this yet

Before installing a login session, run the shell in a window. It takes two
commands, changes nothing about your machine, and answers "does the bar even
draw" — which is the question that actually blocks everything else.

```bash
sudo dnf install quickshell niri
./harness/run-nested.sh
```

Full instructions: **[`../harness/README.md`](../harness/README.md)**.

If the bar does not appear in that window, **stop**. Nothing on this page will
help, because this page is about *where* the shell runs, and the harness has
already told you the shell itself is not running. Fix that first.

Only when the harness works is it worth reading on.

---

## What a "session" actually is

When you turn a Linux machine on, you get a login screen. Somewhere on it —
usually a small gear icon, or a word near the password box — is a list of
*sessions*. Each entry in that list is one desktop you could log into.

That list is not magic. It is a folder of small text files:

```
/usr/share/wayland-sessions/
    gnome.desktop
    ...
```

Each file says a name to display and a program to run. The login screen reads
the folder, shows you the names, and runs the program you picked.

So "adding a session" means: **put one more text file in that folder.** That is
all. `session/aquarius.desktop` is that file, and it names
`aquarius-session` — the launcher script — as the program to run.

### Why this is not as scary as it sounds on Bazzite

AquariusOS is built on Bazzite, which is an **atomic** system. The important
consequence: `/usr` is part of the operating system image and is **read-only**.
You cannot put a file in `/usr/share/wayland-sessions`, and you should not want
to — the whole point of an atomic system is that the OS is exactly the image and
nothing more.

But there is a second folder, and this is the piece that makes this whole
document possible:

```
/usr/local/share/wayland-sessions/
```

On an atomic system `/usr/local` is a link to `/var/usrlocal`, which is
ordinary writable storage. It survives OS updates. It is not part of the image.
**Confirmed on the bench PC 2026-09-01:** `ls -ld /usr/local` shows
`/usr/local -> ../var/usrlocal`.

The login screen on AquariusOS is **GDM** — GNOME's, version 50 on the bench
PC. (An earlier version of this page said SDDM. SDDM is what Bazzite's KDE
variant uses; our image is built on the GNOME variant and has never had it.)

Whether GDM reads the second folder is the one thing this plan now rests on.
Looking inside GDM's own binary on the bench PC: it hardcodes
`/usr/share/wayland-sessions/`, but it *also* walks the standard system data
directories — which, when nothing overrides them, are
`/usr/local/share` then `/usr/share`. So `/usr/local/share/wayland-sessions`
should be picked up. That is read from GDM's source and its binary, not yet seen
on the login screen. See [What is unproven](#what-is-unproven), item 6.

If it holds, the Aquarius Session can be added to a real AquariusOS machine,
appear on the real login screen, and be removed again by deleting five files —
with the OS image never modified, never rebuilt, and never even aware.

---

## Step 1 — install the programs

This is the one step that genuinely touches your system, and how it works
depends on which kind of Linux you are on.

### On plain Fedora

```bash
sudo dnf install quickshell niri xdg-desktop-portal-gtk xdg-desktop-portal-gnome
```

If you want to try labwc as well:

```bash
sudo dnf install labwc xdg-desktop-portal-wlr
```

### On Bazzite / AquariusOS

Bazzite's system is read-only, so `dnf install` does not work the way it does
elsewhere. Packages are **layered** onto the image instead, which needs one
reboot.

**On AquariusOS the two portal back ends are already in the image**
(`xdg-desktop-portal-gnome` and `xdg-desktop-portal-gtk` — checked on the bench
PC 2026-09-01), so the niri route needs only two packages:

```bash
rpm-ostree install quickshell niri
```

```bash
systemctl reboot
```

If you also want to try labwc, it needs its own screen-capture back end, which
is **not** in the image:

```bash
rpm-ostree install labwc xdg-desktop-portal-wlr
```

To undo it later:

```bash
rpm-ostree uninstall quickshell niri
```

(add `labwc xdg-desktop-portal-wlr` if you installed them), then reboot.

Fedora 44's repositories carry Quickshell **0.2.1**, niri **26.04** and labwc
**0.9.6** — the same Quickshell every harness run has used, so nothing about the
shell changes between the harness and the real session.

> **A distrobox will not work here, and this is worth understanding.**
>
> The harness page suggests a distrobox — a container with the tools inside it —
> as the tidy way to try things on Bazzite without layering packages. That
> advice is right for the harness and **wrong for a login session.**
>
> A login session's program is started by the login screen, on the host, before
> any container exists. The compositor also has to talk directly to the graphics
> card and the keyboard. Neither of those works from inside a container.
>
> So this one time, layering is the honest answer. It is reversible, it survives
> updates, and `rpm-ostree uninstall` puts everything back.

**If `quickshell` is not found** — it landed in Fedora fairly recently. On an
older release, add the community repository that carries it:

```bash
sudo dnf copr enable errornointernet/quickshell
```

(and then `dnf install` or `rpm-ostree install` as above).

### Fonts

AquariusOS ships Sora, Inter and JetBrains Mono. A plain Fedora box has none of
them, and the bar will fall back to whatever sans-serif that machine has. It
will look slightly wrong and work perfectly. Install them from Google Fonts if
you want the design to match exactly.

---

## Step 2 — install the session

From the top of the `aquarius-shell` folder:

```bash
./session/install-session.sh
```

It will ask for your password partway through — that is the part that writes
into `/usr/local`. Everything it is about to do with those privileges is
printed on screen before it happens.

It puts five things in place:

| What | Where | Needs a password? |
|---|---|---|
| The launcher | `/usr/local/bin/aquarius-session` | yes |
| The compositor configs | `/usr/local/share/aquarius-session/` | yes |
| The shell itself | `/usr/local/share/aquarius-shell/` | yes |
| The login-screen entry | `/usr/local/share/wayland-sessions/aquarius.desktop` | yes |
| The portal config | `~/.config/xdg-desktop-portal/` | no |

**Do not run it with `sudo`.** It will refuse, and the refusal explains why: one
of those five goes into *your* home directory, and under `sudo` it would land in
root's home instead, where nothing would ever read it — and you would not be
told.

### While you are working on the shell

```bash
./session/install-session.sh --link
```

`--link` points the installed session at your working copy instead of copying
it. Edit a `.qml` file, save it, and the running shell reloads by itself. The
catch is the obvious one: move or delete the folder and the session stops
working.

---

## Step 3 — log in

Log out. At the login screen, find the session chooser — usually a small gear
icon near the password box, sometimes the current session's name written
somewhere on the screen. Pick **Aquarius Session (experimental)**, then log in
as normal.

**If it is not in the list**, jump to
[the session does not appear](#the-session-does-not-appear).

### What you should see

A desktop with nothing on it except a pale, near-white bar across the top,
about 30 pixels tall, holding the Aquarius mark on the left and the clock on the
right.

That is correct. There is no dock, no wallpaper and no menu yet — those are
still being built. Press the terminal shortcut and open something to prove the
bar is really connected to the windows: the bold word next to the Aquarius mark
should change to the name of whatever you opened.

### Which compositor you got

**niri**, unless you say otherwise. To switch to labwc:

```bash
mkdir -p ~/.config/aquarius-session
echo labwc > ~/.config/aquarius-session/compositor
```

Then log out and back in. `echo niri > ...` switches back.

The choice is genuinely undecided — see
[`adr/0001-framework.md`](adr/0001-framework.md). Deciding it is one of the
things this bench run exists to do, so try both and form an opinion.

---

## The key bindings

**Super** is the key with the Windows logo on it (Command, on an Apple
keyboard).

### On niri

Everything except the first line is niri's own; the first line is ours.

| Keys | What it does |
|---|---|
| **Super + Space** | **Open or close the Aquarius search palette** — ours |
| Super + Return | A terminal |
| Super + Q | Close the focused window |
| Super + F | Maximise the column |
| Super + Shift + F | Fullscreen the window |
| Super + O | Overview — every workspace and window, zoomed out |
| Super + ← → ↑ ↓ | Move the focus |
| Super + Ctrl + ← → ↑ ↓ | Move the window itself |
| Print | Screenshot (niri's own, not the portal's) |
| Super + Shift + ? | Show niri's full hotkey list |
| Super + Shift + E | Leave the session |

> On niri, "Super" is only Super when niri is the real compositor. In the nested
> harness it is **Alt** instead. That is niri's own behaviour and there is
> nothing we can do about it — it is why the harness feels slightly different.

### On labwc

The Aquarius Session's labwc configuration adds two bindings and keeps labwc's
own defaults for everything else.

| Keys | What it does |
|---|---|
| **Super + Space** | **Open or close the Aquarius search palette** — ours |
| **Super + Shift + E** | **Leave the session** — ours |
| Super + Return | A terminal |
| Alt + Tab / Alt + Shift + Tab | Next / previous window |
| Alt + F4 | Close the window |
| Super + A | Maximise |
| Super + D | Show the desktop |
| Super + ← → ↑ ↓ | Snap the window to half or a quarter of the screen |
| Alt + Space | Window menu |

### About Super + Space

This one is different from all the others, and the difference is worth
understanding because more of the shell will work this way.

The other bindings *launch a program*. Super + Space does not. It sends a
message to the shell that is **already running**, telling it to show or hide its
search box. The command is:

```
qs ipc call search toggle
```

`qs ipc call <target> <function>` is Quickshell's own way of calling a function
inside a running configuration. `search` is the target the palette registers
and `toggle` is its function. *Which* running shell gets the message is decided
by `QS_CONFIG_PATH`, which the launcher exports and the compositor passes down —
so no name and no path appears in the binding.

**This line was wrong until 2026-09-01.** Both compositor configs used to run
`qs ipc call aquarius-shell search toggle`, which Quickshell would have read as
target `aquarius-shell`, function `search` — and there is no such target. It
was caught by reading `qs ipc call --help` on the bench PC. Unproven item 8
was exactly this, and it would have shown up as "Super + Space does nothing".

If Super + Space does nothing, ask the running shell what it actually offers:

```bash
qs ipc show
```

That prints every target and every function it will accept. If the names there
do not match the command above, the bindings in `session/niri/config.kdl` and
`session/labwc/rc.xml` need updating to match — that is a one-line change in
each, and the shell is the source of truth, not the config.

---

## Portals — what they are and why there are two config files

A **portal** is how an application asks the desktop to do something it cannot do
by itself: record the screen, open a file picker, show a notification, remember
a password. Sandboxed apps (every Flatpak, and OBS) can *only* work this way.

There is one front door — `xdg-desktop-portal` — and several back ends behind
it. A configuration file says which back end answers which question. That file
is what `session/portals/` contains.

**When it is wrong, nothing errors.** OBS shows no screens to record. The file
dialog in a Flatpak never appears. That silence is why those files are commented
so heavily.

### How the right file gets found

`xdg-desktop-portal` reads the `XDG_CURRENT_DESKTOP` environment variable,
splits it on colons, and for each name looks for `<name>-portals.conf`. The
launcher sets:

| Compositor | `XDG_CURRENT_DESKTOP` | File it finds |
|---|---|---|
| niri | `aquarius-niri:aquarius:niri` | `aquarius-niri-portals.conf` |
| labwc | `aquarius-labwc:aquarius:wlroots` | `aquarius-labwc-portals.conf` |

The highest-precedence place it looks is `~/.config/xdg-desktop-portal/` — your
own config folder, above anything the system ships. That is why the installer
can put these in place without root, and why they work on a read-only OS.

### Why niri and labwc cannot share one file

The custom-DE plan says to mix `xdg-desktop-portal-gtk` and
`xdg-desktop-portal-wlr`. **That is right for labwc and wrong for niri**, and
the difference is not taste:

- **labwc** is a wlroots compositor. `xdg-desktop-portal-wlr` can capture its
  screen. So: `gtk` for everything, `wlr` for Screenshot and ScreenCast.
- **niri** is not captured that way. It presents the Mutter screen-cast
  interface, which is what `xdg-desktop-portal-gnome` talks to. niri's own
  documentation says it flatly: *"xdg-desktop-portal-gnome: required for
  screencasting support."* Installing `xdg-desktop-portal-wlr` on niri does not
  help.

So there are two files, and the launcher picks between them by name.

**This matters for the P2 compositor gate.** The gate is *"OBS records, Steam
desktop works, a full workday survives on the bench"* — and the two compositors
get there by different routes, with different amounts of machinery. labwc's
capture story is one small focused back end; niri's is the whole GNOME portal.
That is a real input to the decision, not a footnote.

### Checking the portals are alive

```bash
# Which portal back ends are running right now
systemctl --user status 'xdg-desktop-portal*'

# What the front door thinks it is offering
busctl --user introspect org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop
```

---

## The theme follows the system

`Theme.dark` used to be a value somebody flipped by hand. It now follows the
machine: set the system to dark and the shell turns **Midnight**, set it to
light and it turns **Ice**.

### Try it

With the session running, in a terminal:

```bash
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
```

The bar should turn dark **while you watch**, with no restart. Then:

```bash
gsettings set org.gnome.desktop.interface color-scheme prefer-light
```

and it should turn pale again. (`dconf write
/org/gnome/desktop/interface/color-scheme '"prefer-dark"'` is the same change
written a different way — niri's documentation spells it that way.)

### How it works, briefly

The shell asks the appearance portal one standard question:
`org.freedesktop.portal.Settings.ReadOne("org.freedesktop.appearance",
"color-scheme")`. The answer is `0` no preference, `1` prefer dark, `2` prefer
light. It then listens for the `SettingChanged` signal so that later changes
arrive live.

This is the same question GNOME apps, KDE apps, Firefox and every Flatpak ask.
Answering it the same way is the standardised-protocols law applied to
appearance instead of to windows.

**Quickshell has no service for this.** That was checked against v0.3.1's full
module listing rather than remembered — there is no portal module and no
general-purpose D-Bus type in QML. Quickshell's own FAQ points at the answer
used here: drive `gdbus` with its `Process` type. The whole implementation is
`services/SystemAppearance.qml`, and its header explains the two alternatives
that were considered and dropped.

### If nothing happens

Not a failure. If no portal answers — and in the nested harness there often is
none — the shell stays on **Ice**, which is what AquariusOS is meant to look
like anyway. To see why, look at the log:

```bash
grep appearance ~/.local/state/aquarius-session/session.log
```

It says, in words, which of the three cases you are in.

---

## When it does not work

**The log is the first place to look, every time:**

```
~/.local/state/aquarius-session/session.log
```

The previous run is kept next to it as `session.log.1`, which is exactly enough
to compare the time it worked with the time it did not.

### The session does not appear

The login screen is not reading `/usr/local/share/wayland-sessions`.

On AquariusOS the login screen is GDM. It should walk `/usr/local/share` (see
"Why this is not as scary" above), but that has not been seen yet. Check the
file is actually there first:

```bash
ls /usr/local/share/wayland-sessions/
```

If it is there and the session still is not offered, GDM is not looking in
`/usr/local`. On a plain Fedora machine the fix is to install into `/usr`:

```bash
./session/install-session.sh --prefix /usr
```

On AquariusOS `/usr` is read-only and that will fail — which is the honest
answer: adding a session would then genuinely require a change to the OS image.
That is the case the *"when this ships in the image"* section below is about,
and it would move from Phase P3 to "now".

### Other symptoms

| What you see | What is wrong | What to do |
|---|---|---|
| A black screen, then back to the login screen | The launcher failed its checks | Read the log. It names exactly what was missing. |
| The session starts but there is **no bar** | The compositor came up and `qs` did not | Look for QML errors in the log — Quickshell prints them in full with file and line. |
| The bar is there but windows go **underneath** it | The reserved-space request was refused | Note which compositor and file it. Both niri and labwc should honour it. |
| The app name stays **Desktop** with a window open | The compositor is not reporting windows | It needs `wlr-foreign-toplevel-management`. Both should have it. |
| **Super + Space** does nothing | The search palette's IPC name does not match | `qs ipc show`, then fix the binding. See [above](#about-super--space). |
| **OBS shows no screens** to record | The wrong portal back end, or none | `systemctl --user status 'xdg-desktop-portal*'`. On niri you need `xdg-desktop-portal-gnome`; `-wlr` will not do. |
| A **file dialog never opens** in a Flatpak | The FileChooser back end | Should be `gtk` in both of our configs. Check `xdg-desktop-portal-gtk` is installed. |
| The theme **ignores** the system light/dark setting | No portal answered | Expected in the harness. `grep appearance` in the log. |
| The text is **boxes or the wrong font** | Sora / Inter are not installed | Harmless. Install them or ignore it. |
| Everything is **very slow** | An emulated x86 VM on Apple Silicon | Expected, and it makes "does this feel good?" impossible to judge. Use real hardware. |

### Getting out

- **Super + Shift + E** leaves the session and returns to the login screen.
- If the screen is frozen, **Ctrl + Alt + F2** gives you a plain text login. Log
  in there and run `pkill niri` (or `pkill labwc`).
- Worst case, hold the power button. Nothing here writes to disk during a
  session, so there is nothing to corrupt.

---

## Taking it all back out

```bash
./session/install-session.sh --uninstall
```

That removes the five installed files and nothing else. The Aquarius Session
disappears from the login screen; GNOME was never touched and is unchanged.

To also remove the packages, on AquariusOS:

```bash
rpm-ostree uninstall quickshell niri
```

(add `labwc xdg-desktop-portal-wlr` if you layered them), then reboot.

---

## When this ships in the image

Everything above is the *bench* path: a session added to one machine by hand,
outside the OS image. Putting the Aquarius Session **in** AquariusOS is Phase
P3, and there is one specific obstacle waiting there. It is written down now so
that it is a known cost rather than a surprise.

### Bazzite's Game ↔ Desktop switch hardcodes which desktop it means

Bazzite is a gaming OS. It can boot straight into Steam's Game Mode, and Steam's
"switch to desktop" button hands off to a Bazzite script. Two scripts decide
what "desktop" means:

- `/usr/libexec/os-session-select` — what Steam calls when you leave Game Mode.
- `/usr/libexec/bazzite-autologin` — what sets the session the login screen
  logs into automatically.

*Checked on the bench PC 2026-09-01: **neither script is present** on
`aquarius-os-gnome-nvidia` — not in `/usr/libexec`, not in `/usr/bin`. They
belong to Bazzite's handheld/HTPC ("deck") images, which boot into Game Mode;
our desktop image does not. So on the images that exist today this obstacle
does not exist. It becomes real only if AquariusOS ever ships a deck variant,
and the rest of this section is kept for that day.*

Both pick the desktop session **by looking at which Bazzite variant is
installed**, from `/usr/share/ublue-os/image-info.json`:

```bash
if [[ "$BASE_IMAGE_NAME" == "kinoite" ]]; then
  desktop_session="plasma.desktop"
else
  desktop_session="gnome.desktop"
fi
```

`bazzite-autologin` does the same thing, and is stricter — it matches `kinoite`
or `silverblue` and **exits with "Unknown base image" if it is neither**.

**A correction to the strategy document.** The custom-DE plan records this as
*"Bazzite's Game↔Desktop switching hardcodes `plasma.desktop`"*. That was true
of an earlier Bazzite and is no longer the shape of the problem: today it
hardcodes `plasma.desktop` **or** `gnome.desktop`, chosen by variant. Since
AquariusOS is now GNOME-based, the value it currently hardcodes for us is
`gnome.desktop`.

The *conclusion* is unchanged and the plan's cost estimate still holds: there is
no supported way to say "the desktop session is `aquarius.desktop`" without
patching those files. What changes is which lines the patch touches.

### What the patch has to do

1. Make the desktop session name **configurable** rather than derived from the
   image name — a file such as `/etc/bazzite/desktop_session`, read by both
   scripts, defaulting to today's behaviour when absent.
2. Set it to `aquarius.desktop` in the image, once the Aquarius Session is
   actually installed there.
3. **Re-verify on every Bazzite update.** These are upstream files. They will
   change, and a change that quietly reverts the patch means Steam's "switch to
   desktop" drops users into GNOME instead — a confusing failure, not a loud
   one. This belongs in the image's own test suite, not in somebody's memory.

### Two things this note does not decide

- **Whether the Aquarius Session should ever be the default.** It should not be,
  for a long time. Phase P4 at the earliest, per the plan's standing rule that
  every phase ships behind a fallback.
- **Whether GNOME stays installed.** It does. Keeping it costs nothing —
  it is in the Bazzite base — and removing it is a permanent fight for no gain.

---

## What is unproven

Less than there was. The pre-flight on 2026-09-01 (bench PC, from a terminal,
nothing installed) settled the items struck through below. Here is what remains,
in the order a bench run would hit it:

**Never executed at all**

1. `session/aquarius-session` has never run. Not once, on any machine.
2. `session/install-session.sh` has never run. Not once.
3. ~~`session/niri/config.kdl` has never been parsed by niri.~~ **Validated
   2026-09-01**: `niri validate` (niri 26.04) reports *config is valid*, after
   the Super + Space fix.
4. `session/labwc/rc.xml` has never been parsed by labwc. It is confirmed
   well-formed XML by `tests/test-shell.sh` — which proves the angle brackets
   match and nothing else.
5. ~~`services/SystemAppearance.qml` has never been run by a QML engine.~~
   **Run 2026-09-01** in the nested harness: the bench machine is set to dark
   and the shell came up Midnight, so the `gdbus` call and the binding both
   work. Still unproven IN A REAL SESSION, which is what this page is about —
   and unproven is *changing* the setting while the shell is running.

**Read from documentation and source, but not observed**

6. That **GDM** reads `/usr/local/share/wayland-sessions`. *(Rewritten
   2026-09-01 — it used to say SDDM, which AquariusOS does not have.)* GDM's
   daemon binary on the bench PC hardcodes `/usr/share/wayland-sessions/` and
   also joins `wayland-sessions` onto each standard system data directory,
   which default to `/usr/local/share:/usr/share` when the `XDG_DATA_DIRS`
   variable is unset — and GDM's service does not set it. So it should work.
   **This is now the single assumption the whole no-image-changes story rests
   on**, and it is settled by logging out and looking at the session list.
7. ~~That `/usr/local` is writable on Bazzite.~~ **Confirmed 2026-09-01**:
   `/usr/local -> ../var/usrlocal` on the bench PC.
8. ~~That `qs ipc call aquarius-shell search toggle` is the correct spelling.~~
   **It was not.** Fixed 2026-09-01 to `qs ipc call search toggle` after
   reading `qs ipc call --help`; the target is the IpcHandler's `target:
   "search"` in `components/search/FlowSearch.qml`. Still unproven: that the
   binding fires it in a real session (item 9).
9. That `QS_CONFIG_PATH` is inherited all the way down to a `qs` started by a
   compositor key binding. `qs ipc --help` on 0.2.1 confirms the variable is
   the environment form of `--path` for `ipc` as well as for launching, and
   environments are inherited, but the whole chain is untested.
10. ~~That the portal configurations name back ends that are actually
    installed.~~ **Checked 2026-09-01** against the bench PC: the niri config
    names `gnome` and `gtk`, and both `xdg-desktop-portal-gnome` 50.0 and
    `xdg-desktop-portal-gtk` 1.15.3 are in the image. The labwc config names
    `wlr`, which is **not** in the image — layer `xdg-desktop-portal-wlr`
    with labwc or its screen capture will be silent.
11. That `gdbus monitor` output has the exact shape the line-matching in
    `SystemAppearance.qml` expects. The parser is deliberately forgiving —
    it looks for three substrings and a number — but "forgiving" is not
    "verified".
12. That `xdg-desktop-portal-gtk` on the bench machine was built with its
    Settings interface enabled. It is optional at build time. If it was not, the
    light/dark following will find nothing, and the shell will correctly stay on
    Ice.

**Known to be approximate**

13. The terminal shortcut on niri runs a fallback chain
    (`xdg-terminal-exec || ptyxis || kgx || xterm`) because Fedora keeps moving
    its default terminal. On any given machine, three of those four will fail
    first. That is ugly and intentional.
14. Neither compositor configuration sets a wallpaper, and neither draws
    anything in the Aquarius colours. The session will look like niri or labwc
    with our bar on top, because that is exactly what it is.

---

*The strategy this came from is the custom-DE plan (`docs/custom-de/PLAN.md` on
the `research/custom-de` branch of `os-image`). The phase this belongs to is P2
— see [`ROADMAP.md`](ROADMAP.md).*
