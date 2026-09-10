# Logging into the Aquarius Session — step by step

*Written for somebody who has never used Linux. Every command is one line you
can copy. Nothing here can break your machine, and there is a section at the
bottom that undoes all of it.*

---

## Read this first

**The session has now been logged into — once, on 2026-09-02.** It started. The
login screen listed it, the launcher ran, niri came up on a 4K screen and stayed
up for eighteen minutes. **The bar did not appear**, for a reason that had
nothing to do with the session: the `quickshell` package layered onto the OS
could not start at all. That whole story, with the fix, is in
[The Qt ABI trap](#the-qt-abi-trap) below — read it before you try again.

So: the session boots, the shell did not. Everything on this page about *getting
to a login* is now observed rather than predicted. Everything about *what you
see once you are in* is still a prediction.

Below is the older note, kept because most of this page was written the way it
describes.

**This page was written on a Mac**, where there is no Wayland, no compositor, no
Quickshell, no systemd and no D-Bus — so much of it began as a *prediction*,
checked line by line against the documentation and source code of the projects
involved.

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

**GDM does read the second folder. Proven 2026-09-02.** This used to be the one
assumption the whole no-image-changes story rested on: GDM's binary hardcodes
`/usr/share/wayland-sessions/`, but it *also* walks the standard system data
directories, which default to `/usr/local/share` then `/usr/share`. That was
read from GDM's source. On 2026-09-02 it was **seen**: with
`aquarius.desktop` in `/usr/local/share/wayland-sessions/` and nothing else
changed, "Aquarius Session (experimental)" appeared in GDM's session chooser and
logging into it started the launcher.

So it holds: the Aquarius Session can be added to a real AquariusOS machine,
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

---

## The Qt ABI trap

**This is what stopped the first real boot, on 2026-09-02, and it will stop
yours too unless you deal with it. Read this section before Step 2.**

### The symptom

The session starts. You get a desktop — a wallpaper-less one, with niri's own
behaviour — and **no bar at all**. The log
(`~/.local/state/aquarius-session/session.log`) is full of niri's chatter and
contains nothing whatsoever from the shell.

Open a terminal and type:

```bash
qs --version
```

If you see this, you are in this section:

```
qs: symbol lookup error: qs: undefined symbol: _ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6
```

### What is actually wrong

Nothing is broken or corrupted. Two pieces simply do not match.

Quickshell is a Qt program. It is **compiled against one exact version of Qt**,
and it calls functions inside Qt by name. Some of those names are private —
Qt's own internals — and they change between Qt releases.

- The AquariusOS image contains **qt6-qtbase 6.11.1**.
- Fedora 44's repositories rebuilt **quickshell** on 2026-08-31 against
  **qt6-qtbase 6.11.2**, which had just landed in the updates repository. That
  is the `-5.fc44` build.

When you `rpm-ostree install quickshell`, you get the `-5` build. It asks the
image's 6.11.1 for a function that only exists in 6.11.2, does not find it, and
dies before printing a single line of its own.

**And layering cannot fix it**, which is the part worth understanding. On an
atomic system the Qt inside the image is part of the image. `rpm-ostree` can add
packages on top; it cannot swap out what is underneath. So this is not a
one-off unlucky day — it is **structural**. A layered `quickshell` works only
when the repository's build happens to match the image's Qt, and nobody
coordinates those two things.

### Fix 1 — the quick one: layer the older build that matches

Fedora keeps every build it has ever made on its build server, Koji. The `-3`
build of the same Quickshell was compiled against 6.11.1 — the version in our
image. (It is also exactly what the `aq-shell` distrobox runs, which is why the
shell has worked in the harness the whole time.)

Download it:

```bash
curl -L -O "https://kojipkgs.fedoraproject.org/packages/quickshell/0.2.1%5Egit20260209.dacfa9d/3.fc44/x86_64/quickshell-0.2.1%5Egit20260209.dacfa9d-3.fc44.x86_64.rpm"
```

Then install that file *instead of* the repository's, in one step:

```bash
rpm-ostree install --uninstall=quickshell ./quickshell-0.2.1^git20260209.dacfa9d-3.fc44.x86_64.rpm
```

```bash
systemctl reboot
```

`--uninstall=PKG` removes an already-layered package in the same operation that
adds the new one, so you never have a moment with two quickshells or none.
(Checked on the bench PC, 2026-09-02: `rpm-ostree install --help` on rpm-ostree
2026.2 lists `--uninstall=PKG` — *"Remove overlayed additional package"*.)

After the reboot, prove it before logging out:

```bash
qs --version
```

It should print a version line. If it does, the launcher's own pre-flight will
be happy too.

**The catch, stated plainly:** the next time Fedora's `quickshell` updates,
`rpm-ostree upgrade` may pull the repository build back on top and break it
again. This fix is a patch, not a resting place.

### Fix 2 — the proper one: bake quickshell into the image

Put `quickshell` in the AquariusOS Containerfile, in the `os-image` repo. Then
it is built against **the image's own Qt**, by the same build, at the same time.
The two cannot drift apart, because there is no longer an "on top" and an
"underneath" — there is one image.

That is a change in `os-image`, not in this repository, and it is the honest
answer for a shell that is meant to ship as part of the OS. It moves the
Quickshell dependency from "a package the user layers" to "part of AquariusOS",
which is what it always was in spirit.

### What the launcher does about it now

Since 2026-09-02, `session/aquarius-session` does not merely check that a file
called `qs` exists — it **runs `qs --version`** and refuses to start the session
if that fails, printing the real error and both fixes above. The old check was
`command -v qs`, which happily passes for a binary that cannot start at all.
That is precisely how eighteen minutes were spent looking at a bar-less desktop
with no explanation anywhere.

---

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

**Before you log out to try a change, check that the shell still starts.** A
session that will not load looks the same as a broken computer: you log in, the
screen is empty, and there is no bar to tell you why. One command answers it
without logging out of anything —

```bash
./harness/load-check.sh
```

— because it starts the desktop, the login screen and the lock screen inside a
window manager with no screen attached, and says which of them died. CI runs the
same command on every push (`.github/workflows/lint.yml`, the job called "The
shell actually loads"), so a desktop that will not start now fails a build rather
than a login. ⚠️ The **login screen** does not load today for a reason that has
nothing to do with your change; it is on a known-broken list, and the check
prints it rather than failing on it. Both are explained in
[`../harness/README.md`](../harness/README.md), *"The load check, and why CI runs
it"*.

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

The Aquarius Session's labwc configuration adds its own bindings and keeps
labwc's defaults for everything else.

| Keys | What it does |
|---|---|
| **Super + Space** | **Open or close the Aquarius search palette** — ours |
| **Super + Tab / Super + Shift + Tab** | **The Aquarius app switcher, forwards / backwards** — ours |
| **Alt + Tab / Alt + Shift + Tab** | **The same switcher, for the Windows keyboard style** — ours |
| **Super + `** | **Cycle the windows of the app you are in, no panel** — ours |
| **Super + Shift + E** | **Leave the session** — ours |
| **Super + Return** | **A terminal — `ptyxis`, the one AquariusOS ships** |
| Alt + F4 | Close the window |
| Super + A | Maximise |
| Super + D | Show the desktop |
| Super + ← → ↑ ↓ | Snap the window to half or a quarter of the screen |
| Alt + Space | Window menu |

**About the Tab keys.** They used to be labwc's own `NextWindow` and
`PreviousWindow`, which draw labwc's list of window titles. They now open the
Aquarius app switcher instead — the shell's own panel, which groups an
application's windows together the way a Mac does and is drawn from the same
icon theme and colours as the dock. labwc's own list is switched off in the same
block of `rc.xml`, so there is no way to get two switchers on screen at once.

Both Super+Tab and Alt+Tab are bound, all the time, because Aquarius Keys swaps
the two keys beside the space bar in the Mac style and does not in the Windows
style. Which one you press is up to your keyboard profile; both arrive at the
same panel, and the panel decides what to LIST from
`~/.config/aquarius/keys.conf` — applications in the Mac style, windows in the
Windows style.

The whole feature, including the genuinely hard part (how the shell knows you
let go of the modifier, and the two approaches that were tried first), is
written up in **`docs/app-switcher.md`**.

**About Super + Return.** labwc's own `<default />` already binds it to a
terminal, reaching for xterm, foot and alacritty in turn. AquariusOS ships
`ptyxis`, so `rc.xml` names that one. This binding was in the os-image's copy of
`rc.xml` and not in this repo's, which meant the two files differed in a way that
was not a comment — and once that is true, "diff them and read the prose" stops
being a way to check they agree. The shell's copy is deliberately the **superset**
now. On a plain Fedora clone with no ptyxis installed the keybind is simply
inert: labwc runs the command, the command is not there, nothing happens.

### The one window rule: DaVinci Resolve opens at the size of the screen

At the bottom of `rc.xml`, after the mouse bindings, is the only `<windowRules>`
block in this session and the only place an application is named by name:

```xml
<windowRules>
  <windowRule identifier="resolve">
    <action name="FitToOutput" />
    <action name="Maximize" direction="both" />
  </windowRule>
</windowRules>
```

DaVinci Resolve decides for itself how big its own window should be, and on a
4K screen it sometimes decides on a window whose edges — the close button
included — are off the display. Nothing inside Resolve fixes that; it is Resolve
remembering a size from a screen it is no longer on. The window manager can,
because the window manager is what places the window.

`FitToOutput` shrinks a window that asked to be bigger than the screen it landed
on, so that un-maximising it later still gives back something that fits.
`Maximize` then fills that screen. Both run **once**, when the window first
appears — labwc has exactly one window-rule event and it is "on first map"
(`include/window-rules.h`, labwc 0.20.2). After that Resolve's window is yours:
move it, resize it, put it on the other monitor, and nothing here interferes.

`identifier` is the app_id for a Wayland window and the **WM_CLASS** for an X11
one. Resolve is X11 — there is no Wayland Resolve on any Linux — and the class
it declares is `resolve`, the same name Blackmagic's own desktop entry puts in
`StartupWMClass`. Matching is case-insensitive and takes `*` and `?` wildcards;
this rule uses neither, so it matches Resolve and nothing else.

⚠️ **This block is mirrored in the os-image repository** at
`system_files/usr/share/aquarius/labwc/rc.xml`, like the rest of this file.
Change one, change both — `build_files/check-labwc-drift.sh` over there fails
the build if they disagree.

### About Super + Tab

Hold **Super** and tap **Tab** to walk forward through your open windows; add
**Shift** to walk back. Keep Super held down and the switcher stays on screen,
so you can tap Tab several times to reach the window you want and let go.

**Alt + Tab still works and has not moved.** This is an addition, not a
replacement.

It is here because of Aquarius Keys, the OS's keyboard-mode feature. In **Mac
mode**, the Command key is mapped to Super — so somebody typing Command + Tab
out of habit is really sending Super + Tab. GNOME, the other AquariusOS desktop,
already treats Super + Tab as "switch windows". labwc puts window switching on
Alt + Tab only. So before this, the same keystroke did the expected thing on one
AquariusOS desktop and nothing at all on the other, which is the kind of
inconsistency people read as a broken computer.

The two lines use labwc's own `NextWindow` and `PreviousWindow` actions — the
same ones its default Alt + Tab is built from — so this is the standard window
switcher on a second key, not a second implementation of it.

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

## What else starts at login, and why it is written down three times

Most Linux desktops have one list of "things to start when somebody logs in":
the `.desktop` files in `/etc/xdg/autostart`. GNOME reads that folder and starts
everything in it.

**Neither of our compositors reads that folder.** labwc reads exactly one file,
the `autostart` next to its `rc.xml`, and nothing else. niri reads only its own
`config.kdl`. That is deliberate and it is worth keeping: it is what stops a
dozen GNOME background programs from starting up underneath the Aquarius Shell
and fighting it for the tray, the notifications and the screen.

The price of that decision is duplication. Anything that has to run at login in
**both** the Aquarius session and the GNOME fallback ends up written down in
three places:

| Where | Which session it covers |
|-------|-------------------------|
| `/etc/xdg/autostart/<name>.desktop` (shipped by AquariusOS) | the GNOME fallback |
| `session/labwc/autostart`, in this repo | the Aquarius session on labwc |
| `session/niri/config.kdl`, in this repo | the Aquarius session on niri |

**Change one, change all three.** There is no clever way around it — there is no
session name that means "GNOME and ours", so `OnlyShowIn=` cannot be used to
make a single `.desktop` file cover everything.

### The one entry there is so far: the welcome

On the first login, AquariusOS opens the **Aquarius welcome** — a short flow
that asks how you want the keyboard to work, then opens **"Your creator apps"**
(the window that offers the studio apps — OBS, Kdenlive, Blender and friends —
and installs the ones you tick) as its second step, then says goodbye. The
command is:

```bash
/usr/libexec/aquarius-welcome --first-run
```

> **This changed on 2026-09-04.** It used to be the creator apps window on its
> own, started as `/usr/libexec/aquarius-creator-apps --first-run`. The welcome
> replaced it as the thing that starts at login; the chooser is still an
> ordinary app you can open any time ("Aquarius Apps" in the app grid), it is
> just no longer started by these files. The AquariusOS copies are the
> authoritative ones — see "Which copy of these files actually ships" below.

`--first-run` is what makes it happen only once. The welcome looks for
`~/.config/aquarius/welcome-seen` and returns silently if that file is
already there, so the line runs at every login and does nothing at all on all
but the first.

Both session files wait ten seconds before running it, matching the
`X-GNOME-Autostart-Delay=10` in the GNOME copy. The wait is not for the
program's benefit — the window opens in well under a second — it is so the
desktop has settled and the person is looking at their computer rather than at
a login screen when it appears.

Both session files also guard the line with `[ -x /usr/libexec/aquarius-welcome ]`.
That guard matters here more than it would in the image: the welcome belongs to
AquariusOS, not to this repository, so on a plain Fedora machine running the
session from a clone the program simply is not there, and the session has to
start normally anyway.

### Which copy of these files actually ships

> **AquariusOS ships its own copies of the session files.** The image build
> (`build_files/stage-aquarius-shell.sh` in the `os-image` repo) copies only
> `shell.qml`, `components/`, `services/`, `theme/` and `assets/` out of this
> repository — it deliberately leaves `session/` behind, because the image's
> versions are adapted to system paths and carry image-only steps this repo has
> no business knowing about (the wallpaper, the display-scale helper, the
> shell-start dialog).
>
> So the file that runs on an installed AquariusOS machine is
> `system_files/usr/share/aquarius/labwc/autostart` **in the os-image repo**,
> and that copy is the authoritative one. The files here are what runs when the
> session is started from a clone — on the bench, or on plain Fedora.
>
> They are still kept in step by hand, and the lines that actually *run* are
> byte-for-byte identical between the two, so a diff between them shows only
> prose. When you change one, change the other.

**⚠️ `themerc-override` is no longer one of the hand-kept files.** It used to
be: a second copy of the Ice palette, typed out by hand, because labwc cannot
read QML. As of 2026-09-06 it is **generated** — see
"The window frame follows too" further down this file — and the fifth file to keep in step
is `session/labwc/generate-theme`, the program that writes it. Both repositories
carry a copy of the generator, and `check-labwc-drift.sh` in the os-image repo
runs *both* copies and compares what they produce, which is a stronger check
than comparing two hand-written files ever was.

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

### Handing the environment to systemd and D-Bus

Setting `XDG_CURRENT_DESKTOP` in the launcher is only half the job, and the
missing half used to be a real gap.

Portals, the keyring and the tray are **not** started by the session files.
They are started later, on demand, by systemd's user manager and by D-Bus.
Those two managers do not see the launcher's environment — they only know what
was explicitly pushed into them. So a portal could start without knowing which
desktop it was serving or which Wayland display to talk to, and a portal in that
state fails *silently*: the file dialog simply never appears and nothing is
written to any log.

On niri this is handled by its `--session` flag, which pushes the environment
across itself. labwc has no equivalent, so `session/labwc/autostart` does it
explicitly, as its first step:

```bash
dbus-update-activation-environment --systemd --all
```

It lives in the autostart file rather than in `aquarius-session` for a reason
that is easy to miss: `WAYLAND_DISPLAY` **does not exist yet** when the launcher
runs. labwc has not started, so there is no display to name. The autostart file
is the first point in the session where it exists, which makes it the only place
this can happen. It runs before `labwc-session.target` is started, because the
services that target pulls in read their environment once, as they start.

`--all` rather than a list of names, so that `XDG_CURRENT_DESKTOP` — the
variable the whole portal-config lookup above depends on — travels too. On a
machine without `dbus-update-activation-environment` (it is in the `dbus-tools`
package) the file falls back to `systemctl --user import-environment`.

> AquariusOS ships its **own** copies of the session files, adapted to system
> paths — the image never installs this repo's `session/` folder. Its copy of
> the autostart file already did the same thing, which is why
> `/usr/libexec/aquarius-keys-run` in the image works out the desktop name for
> itself rather than failing. This change closes the gap for the version in this
> repo, which is the one used when running the session from a clone.

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

### The window frame follows too, and this is how

The theme swap moves the **shell** — the bar, the dock, the panels, the menus the
shell draws — by ordinary QML bindings. It cannot move the things **labwc**
draws: window title bars, the border around every window, the round window
buttons, and the desktop right-click menu. labwc is a C program reading flat
text files. It has no idea what a QML singleton has just decided.

So a program writes those files for it: **`session/labwc/generate-theme`**.

#### What it does

It reads `theme/Ice.qml` or `theme/Midnight.qml` — the same two files the shell
itself is coloured from, and the only place in this repository a colour is
allowed to live — does the arithmetic, and writes out:

| What | Where it goes |
|---|---|
| `themerc-override` — every colour and size | `~/.config/aquarius/labwc/` |
| `rc.xml` — with three settings filled in | `~/.config/aquarius/labwc/` |
| `menu.xml`, `autostart`, `shutdown`, `environment` | copied there unchanged |
| the round window buttons, as SVG | `~/.local/share/themes/Aquarius/labwc/` |
| the GTK window chrome, in **both** light and dark | `~/.config/gtk-4.0/gtk.css` and `gtk-3.0` |

That last row is the one exception to "this project ships no GTK theme", and it
exists because of a bench finding on 7 September 2026: GNOME's own applications
(Files, Settings, Ptyxis, Text Editor) draw their own title bar inside the
window, so the labwc frame built above never appears on them at all. The
generated stylesheet gives them the window background colour, the header-bar
colour, and the three window buttons redrawn as the same round discs labwc
draws — deepening under the pointer, close alone going red, all of them fading
on a window you are not in. Nothing else in GTK is touched: no text colours, no
widget theming, not even the header bar's height. It used to be written only in
dark mode and deleted in light; since Royce widened design rule 9 it is written
in both, and rewritten on every flip.

The honest limit: that file sits in your home folder, so every GTK application
reads it, including one started from the GNOME fallback session — harmless, but
it keeps whichever scheme the Aquarius session wrote last rather than following
GNOME's own light/dark switch.

#### "It never overwrites a file it did not write" — and what that cost

That rule is right and it is not going away. On 8 September 2026 it also cost a
whole bench finding, and the way it did is worth understanding.

Royce looked at a GNOME window and reported two things: **the minimise line was
at the bottom of its circle instead of in the middle, and the close button did
not turn red under the pointer.** Both are exactly what libadwaita's own stock
buttons look like — which is the point. Our stylesheet was never written.

`~/.config/gtk-4.0/gtk.css` on that machine was two lines, dated 30 August:

```css
@import 'colors.css';
@import 'kde_window_geometry.css';
```

left behind by **Bazzite's KDE integration**, months before, along with a Breeze
`colors.css`, a `kde_window_geometry.css` and a `settings.ini` that still said
`gtk-icon-theme-name=breeze-dark` and `gtk-cursor-theme-name=breeze_cursors`.
The generator saw a file it had not written, declined, and said so through the
channel the shell silences with `--quiet`. So it said it to nobody, and what
reached Royce was "the window buttons in your design are wrong".

**Three things changed.**

1. **It always says what it did.** One plain sentence, on stderr, whether it
   wrote, moved something aside, or declined — and `--quiet` cannot silence it.
   The shell collects the generator's stderr into the session log, so:

   ```bash
   grep generate-theme ~/.local/state/aquarius-session/session.log
   ```

   now answers "why do my window buttons look wrong" in one line.

2. **A file that is plainly another program's output may be replaced** — once,
   keeping the original beside it as `gtk.css.before-aquarius`. The test for
   "another program's output" is deliberately narrow, and it is worth stating
   exactly, because the whole safety of this turns on it: the file counts only
   when **everything in it, once the comments are gone, is an `@import` of a
   file sitting beside it that carries Breeze's own fingerprints** (`_breeze`
   colour names, or the Libadwaita-Breeze header comment). A stylesheet a
   *person* wrote has rules in it, not only imports, so it can never match. If
   anything at all is unrecognised — an import of a file we cannot check, a
   single real rule — the file is treated as yours and left exactly where it is,
   and the log says so.

3. **`settings.ini` stopped fighting us.** This is the part worth reading twice.

#### The four `settings.ini` keys the session owns, and why only four

`~/.config/gtk-3.0/settings.ini` and `gtk-4.0/settings.ini` are where GTK reads
its defaults, and **libadwaita reads them too**. Four of those keys are answers
to questions the Aquarius session has already answered somewhere else, and a
stale value in this file is a straight contradiction:

| Key | What the session says | Where it decided |
|---|---|---|
| `gtk-icon-theme-name` | `Aquarius-Ice` or `Aquarius-Midnight` | follows the light/dark flip |
| `gtk-cursor-theme-name` | `Adwaita` | AquariusOS ships no cursor set of its own yet |
| `gtk-decoration-layout` | buttons left in Mac mode, right in Windows mode | `aq keys`, once, at first login |
| `gtk-application-prefer-dark-theme` | true on Midnight, false on Ice | follows the light/dark flip |

Those four are rewritten. **Everything else in the file is left exactly as it
was** — your font, your cursor blink, your animation setting, your toolbar
style. The original is kept once as `settings.ini.before-aquarius`.

Two questions this raises, answered rather than left:

* **Why touch it at all, if GTK 4 reads the settings portal anyway?** Because
  GTK **3** does not. It has no settings portal; `settings.ini` is the only
  thing it reads. So a stale `breeze-dark` in there gives every GTK 3
  application the wrong icons for ever, whatever gsettings says. It also
  matters to a GTK 4 application started before the portal is up.
* **What if the file has no KDE fingerprint and still disagrees with us?**
  Then it is somebody's own preference and it is **left alone**, with a line in
  the log saying so. The session's answers are still in gsettings, which GTK 4
  prefers; a person who has hand-edited `settings.ini` has said something and is
  entitled to be listened to.

#### The icons follow light and dark now too

Both icon themes ship — `Aquarius-Ice` and `Aquarius-Midnight` — and until now
the machine was set to Ice always. The generator now sets
`org.gnome.desktop.interface icon-theme` to match the scheme, at login and on
every flip, and **only if that theme is actually installed** (pointing GTK at a
theme that is not there is how a desktop ends up with no icons at all).

One honest gap: **the shell's own icons do not follow until the next login.**
Quickshell is told which icon theme to draw from by `QS_ICON_THEME`, read once
when it starts, and there is no way to change that in a running instance. So a
flip to dark gives GTK applications the Midnight icons straight away and leaves
the dock on the Ice ones until you log back in. The alternative would be
restarting the shell out from under somebody, which is worse.

#### The minimise line, and why the stylesheet draws it itself

The other half of what Royce reported. Our stylesheet colours the round disc but
the *glyph* inside it belongs to the icon theme, and the one GNOME applications
use — Adwaita's `window-minimize-symbolic` — is a bar sitting **low** in its box
(`m 4 10.007812 h 8 v 1.988282 h -8 z` in a 16-pixel square: centred at 11 where
the middle is 8). Design rule 9 says the middle, and that is what labwc draws on
every other window.

It cannot be swapped for our own picture: GTK's `-gtk-icon-source` is honoured
only by GTK's own built-in icon nodes, never by the image a window button uses.
So the stylesheet turns the glyph off — `color: transparent`, which is the same
channel that already turns the X white on a red close button — and draws the
line itself, centred, as a plain background image. The emitted stylesheet was
loaded into a real GTK 4 on the bench and parses with no errors.

The files in `session/labwc/` are the **template**. `session/aquarius-session`
runs the generator before starting labwc, and then starts labwc with the
generated folder rather than the template one. If generating fails, it starts
labwc with the template folder and says so in the log — a cosmetic step must
never be able to stop you logging in.

#### Why two output folders, and why not in place

Two folders because that is labwc's rule, not ours: labwc reads its **settings**
from the folder it was started with (`labwc -C <folder>`) but looks for **button
pictures** in a *theme* folder, `themes/<name>/labwc/`, which is why `rc.xml`
says `<theme><name>Aquarius</name>`.

Not in place because on an installed AquariusOS machine the template folder is
inside `/usr`, which is read-only — and because these files have to be rewritten
*while the desktop is running*, every time the machine goes light or dark.

#### When it re-runs

1. **At login**, from `session/aquarius-session`, before labwc starts.
2. **Whenever the machine goes light or dark**, from
   `services/SystemAppearance.qml`, which runs it again and then runs
   `labwc --reconfigure` — labwc's own "re-read your files now" command. That is
   what makes the change appear without logging out.
3. **When you run `aq keys mac` or `aq keys windows`** on AquariusOS, which is
   the one switch that moves the window buttons from one side to the other.

#### How to change a colour

Edit `theme/Ice.qml` or `theme/Midnight.qml`. Nowhere else. There is no second
copy to keep in step any more, because the second copy is made rather than
typed. Flip the desktop between light and dark and back and you will see it, or
log out and in.

#### How to change a size

Every number is in the block near the top of `generate-theme` headed "THE
DESIGN, WRITTEN DOWN ONCE", written at `AQ_UI_SCALE=1`. `AQ_UI_SCALE` now
reaches the window frames — it did not before — so a 20px button really is 25px
at 1.25.

#### Two things labwc 0.20 cannot do, written down so they are not surprises

* **There is no "pressed" button.** The design asks for a darker disc while the
  mouse button is held down. labwc's button states are default, hover, toggled
  and rounded, and nothing else; a pressed button therefore looks like a hovered
  one. Nothing fakes it.
* **There is no title-bar height setting.** The key that used to do it,
  `titlebar.height`, was removed. labwc works the height out as
  `max(font height, button height) + 2 x padding`, so the generator sets the
  button height and solves for the padding. At 1.25 that lands one pixel short
  of the design's 38 — 47 instead of 48 — because half of an odd number is not a
  whole number of pixels.

### If nothing happens

Not a failure. If no portal answers — and in the nested harness there often is
none — the shell stays on **Ice**, which is what AquariusOS is meant to look
like anyway. To see why, look at the log:

```bash
grep appearance ~/.local/state/aquarius-session/session.log
```

It says, in words, which of the three cases you are in.

> ⚠️ **Those lines were invisible until 8 September 2026, and it is worth
> knowing why.** Every explanatory sentence the shell writes used to go through
> `console.log`, and the Quickshell AquariusOS ships **drops `console.log`
> entirely** — it reaches neither the terminal nor the shell's own log file.
> Measured, not guessed: the same three lines written with `console.log`,
> `console.info` and `console.warn` produced two lines of output. So a shell
> that had been carefully explaining itself for a fortnight had been explaining
> itself to nobody, which is part of why the bench had nothing to read. Every
> one of those sentences is now `console.info`, and they do come through.

### Or just ask the shell what it believes

Added 8 September 2026, after an afternoon went on "did the dark flip reach the
lock screen?" with no way to ask:

```bash
qs ipc call theme status
```

It prints five lines: what the portal last said, whether the shell is Ice or
Midnight **and why**, which wallpaper the lock screen would draw, whether this
session has a window-frame generator to run when the theme flips, and whether it
has a wallpaper setter to tell about the flip. If those say dark and the screen
still looks light, the thing you are looking at is something the shell does not
draw — read the next section.

### The wallpaper, and the two halves that make it follow light and dark

> **State, 8 September 2026: the shell's half is written and tested.** It runs
> the program named in `$AQ_WALLPAPER_SETTER` with one word — `ice` or
> `midnight` — every time the theme flips, and does nothing at all when that
> variable is unset. The session's half (`/usr/libexec/aquarius-wallpaper` and
> the export in `aquarius-session`) is being written in the `os-image`
> repository, and until it lands nothing happens, which is correct rather than
> broken. `harness/wallpaper-check.sh` proves the shell's half on its own.

**What you saw before it.** Flip the machine to dark. The bar goes navy, the
dock goes navy, the menus go navy — and the picture behind them stays the pale
Ice "Pour". Both pictures ship; only one is ever shown.

**Why.** The wallpaper is not drawn by the shell. It is drawn by `swaybg`,
which the session's `labwc/autostart` starts **once**, at login, naming the Ice
file. That is a deliberate decision and a good one: a wallpaper drawn by a
separate program survives the shell crashing, so a bad night's work on the bar
can never leave somebody staring at a black screen. The cost is that nothing
re-runs it when the theme changes.

**The contract for fixing it.** This has to be done on the session's side — in
the `os-image` repository, which owns the copy of `autostart` that actually
ships — and it is written out here so that whoever does it does not have to
invent the interface.

1. **The session ships one small program** whose only job is "put the right
   wallpaper up", called with the scheme:

   ```
   /usr/libexec/aquarius-wallpaper ice        # the light picture
   /usr/libexec/aquarius-wallpaper midnight   # the dark one
   /usr/libexec/aquarius-wallpaper auto       # ask the appearance portal
   ```

   It stops any `swaybg` it started before (its own pid file, not `pkill
   swaybg` — somebody may be running their own), starts a new one with
   `-c '#0B1220' -m fill`, and says one plain line into `$AQ_LOG`. A missing
   picture, or a missing `swaybg`, is one logged sentence and exit 0: a
   wallpaper is decoration and must never be able to take a login down.

2. **`labwc/autostart` calls it instead of running `swaybg` itself**, with
   `auto`, at the same point in the file. That alone fixes *login* — the
   picture is right for the theme the machine is already in.

3. **The shell tells it when the theme changes — ✅ written, 2026-09-08.** The
   shell already had this exact seam for the window frames:
   `services/SystemAppearance.qml` runs the program named in
   `$AQ_FRAME_GENERATOR` every time light/dark flips, and does nothing at all
   when that variable is unset. The wallpaper is the same shape, beside it:

   | | |
   |---|---|
   | Variable | `AQ_WALLPAPER_SETTER`, to be exported by `aquarius-session` beside `AQ_FRAME_GENERATOR` |
   | The shell runs | `$AQ_WALLPAPER_SETTER <ice\|midnight>`, fire-and-forget |
   | When | on a **flip** — not on the portal's first answer; see below |
   | If unset | nothing happens, and that is correct — there is no Aquarius wallpaper to swap |
   | If it fails | one line in the log; the desktop keeps the picture it had |

   **Why on a flip and not at login as well.** The window frames are rebuilt on
   the portal's first answer too, and that is fine because nobody can see it
   happen. Restarting `swaybg` *is* visible — the desktop blinks — and step 2
   above has already put the right picture up before the shell even starts. So
   the shell speaks only when the answer **changes**.

   **Which word it sends, and where it gets it.** `ice` or `midnight`: the
   palettes' own names, and the same two words `generate-theme --scheme` takes.
   One vocabulary for "which look is on". It follows the **portal**, not
   `Theme.dark`, exactly as `generate-theme` does when it runs at login with no
   shell to ask. The honest consequence, written in the code as well: the day a
   Settings panel can pin the theme by hand, the frames and the wallpaper will
   follow the system and the shell will not, and all three have to change
   together.

Until the session's half lands, "dark" still means everything except the
picture, and `qs ipc call theme status` will tell you so — its `desktop` line
names the setter, or says there is not one.

**Testing the shell's half without any of the rest of it.** There is a check
that starts the real shell in an invisible window manager, replaces `gdbus`
with a script that says "light" and then, three seconds later, prints exactly
the line a real `gdbus monitor` prints when somebody turns the machine dark,
and puts a fake wallpaper setter on the PATH that writes down what it was asked
for:

```bash
./harness/wallpaper-check.sh
```

It proves three things: the setter is called, it is called with `midnight`, and
it is called exactly once. Then it runs the shell again with
`AQ_WALLPAPER_SETTER` unset and proves nothing is run at all.
`tests/test-shell.sh` section 44 runs it on any machine that can, and says so
and skips on any machine that cannot.

---

## When it does not work

**The log is the first place to look, every time:**

```
~/.local/state/aquarius-session/session.log
```

The previous run is kept next to it as `session.log.1`, which is exactly enough
to compare the time it worked with the time it did not.

**Lines that begin `[shell]` came from the Aquarius Shell; everything else came
from the compositor.** That prefix was added on 2026-09-02, along with the
redirect that puts the shell's output in this file at all. Before that, a
compositor handed the shell `/dev/null` for its output — proven by measurement
on niri 26.04, not assumed — so on the first real boot the shell crashed and the
log said nothing about it. If you see no `[shell]` lines at all, the shell never
got far enough to print anything: see the first row of the table below.

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
| The session starts, there is **no bar**, and the log shows **only niri** — not one line from the shell | `qs` died before it could print anything. On AquariusOS this is almost always the Qt mismatch. | Open a terminal and run `qs --version`. If it says *symbol lookup error* / *undefined symbol*, go to [The Qt ABI trap](#the-qt-abi-trap). |
| The session starts but there is **no bar**, and the log has `[shell]` lines in it | The shell started and then failed | Read the `[shell]` lines — Quickshell prints QML errors in full, with file and line. |
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
nothing installed) and **the first real login on 2026-09-02** settled the items
struck through below. Here is what remains, in the order a bench run would hit
it:

**Never executed at all**

1. ~~`session/aquarius-session` has never run.~~ **PROVEN 2026-09-02**: it ran,
   from GDM, on the bench PC. It found its configuration and the shell, printed
   its pre-flight, chose niri, and handed over. It also failed to notice that
   `qs` could not start — which is why it now runs `qs --version` (see
   [The Qt ABI trap](#the-qt-abi-trap)).
2. ~~`session/install-session.sh` has never run.~~ **PROVEN 2026-09-02**: it ran
   on the bench PC and installed all five pieces into `/usr/local` and
   `~/.config`. Nothing needed patching afterwards.
2b. **The shell itself has never drawn in a real login session.** On
   2026-09-02 the session booted and `qs` could not start (see
   [The Qt ABI trap](#the-qt-abi-trap)), so everything on this page from
   "What you should see" onwards — the bar, the bindings, the portals, the
   light/dark following — is still only proven in the nested harness.
2c. **The new log redirect has not been seen in a real login.** The line that
   captures the shell's output was proven by running niri 26.04 with this
   repo's own config and watching `[shell]` lines arrive in `$AQ_LOG` — but
   nested, from a terminal, not from GDM.
3. ~~`session/niri/config.kdl` has never been parsed by niri.~~ **Validated
   2026-09-01**: `niri validate` (niri 26.04) reports *config is valid*, after
   the Super + Space fix — and again on 2026-09-02, after the `spawn-sh-at-startup`
   change.
4. `session/labwc/rc.xml` has never been parsed by labwc. It is confirmed
   well-formed XML by `tests/test-shell.sh` — which proves the angle brackets
   match and nothing else.
5. ~~`services/SystemAppearance.qml` has never been run by a QML engine.~~
   **Run 2026-09-01** in the nested harness: the bench machine is set to dark
   and the shell came up Midnight, so the `gdbus` call and the binding both
   work. Still unproven IN A REAL SESSION, which is what this page is about —
   and unproven is *changing* the setting while the shell is running.

**Read from documentation and source, but not observed**

6. ~~That **GDM** reads `/usr/local/share/wayland-sessions`.~~ **PROVEN
   2026-09-02.** It was the single assumption the whole no-image-changes story
   rested on, and it holds: with `aquarius.desktop` installed only into
   `/usr/local/share/wayland-sessions/`, GDM listed **Aquarius Session
   (experimental)** in its session chooser, and picking it ran our launcher.
   No change to the OS image, none needed. *(This item said SDDM until
   2026-09-01; SDDM is Bazzite's KDE variant, which AquariusOS is not.)*
7. ~~That `/usr/local` is writable on Bazzite.~~ **Confirmed 2026-09-01**
   (`/usr/local -> ../var/usrlocal` on the bench PC) and **proven by use
   2026-09-02**: the installer wrote all four system pieces there and GDM read
   them back.
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

### Window buttons after changing Mac/Windows style

The one keyboard-style choice also places the window buttons. The generated
labwc frame and GTK 3/4 settings follow each change, including on a fresh login
and after an old KDE configuration has been repaired. Only the decoration-layout
key is synchronized in a custom GTK settings file; fonts and unrelated personal
settings remain intact. An application that reads this file only at startup
may need to be reopened before it shows the new placement.

Apps that draw their own controls can override the desktop's choice. Use their
native-title-bar option when one is available; adding another compositor frame
around every app would leave some windows with two sets of buttons.

Resolve's project window has a specific exception: it asks for no frame and can
restore itself maximized. The Aquarius Session supplies its normal frame and
restores that window when it first appears. The rule matches the `resolve`
class, a normal window, and a title beginning `DaVinci Resolve` with ` - ` before
the project name. Splash screens and dialogs do not receive this exception.
You can still maximize the editor afterwards; no fixed size is imposed.

Verification on 10 September 2026 used three disposable X11 windows: a matching
frameless maximized editor, a splash, and a dialog. Only the editor was restored
and given a visible frame. Maximizing it afterwards still worked. Recheck the
real Resolve project window after updating because app title changes can affect
this deliberately narrow match.
