# The lock screen

*Written 2026-09-06, from the spec Royce approved the same day. The shell's
`lock/` folder.*

---

## What it is

The screen you get when you press **Ctrl+⌘Q** (Mac keys) or **Win+L** (Windows keys), pick **Lock Screen** from the
Aquarius menu, or walk away from the machine for ten minutes.

```
                              ◭ AquariusOS


                              09:42
                         Friday 6 September




                    ┌──────────────────────────┐
                    │  3 notifications waiting │
                    └──────────────────────────┘
              press any key, or start typing your password
```

It is the login screen's sibling. Same wallpaper, same typefaces, same colours,
the same round avatar with your initials in it, the same card — because it is
built out of the same `theme/` folder and, in the avatar's case, literally the
same file. Flip the system between light and dark while the machine is locked
and the lock screen changes with it, for the same reason everything else in this
shell does.

---

## The three states

### 1. CALM

What you see when you walk up. The wallpaper, blurred, under a wash of the
theme's own background colour. The clock, large, in the middle. A small
`◭ AquariusOS` at the top. Near the bottom: how many notifications are waiting,
and one line telling you that you can just start typing.

**The count is the only thing that leaks, and it can be switched off.** No
titles, no senders, no app names, no previews, no media, and never a glimpse of
the desktop. See "What is never shown", below.

### 2. PASSWORD

Press any key, click anywhere, or just start typing. The clock rises to near the
top of the screen and halves in size; the card slides up twenty-four pixels and
fades in underneath it over about a fifth of a second.

```
                              09:42
                         Friday 6 September

              ┌──────────────────────────────────────┐
              │                                      │
              │                ( RA )                │
              │             Royce Adkins             │
              │                                      │
              │   ┌──────────────────────────────┐   │
              │   │ ••••••••                     │   │
              │   └──────────────────────────────┘   │
              │   Password                           │
              │                                      │
              │                Sleep                 │
              └──────────────────────────────────────┘

                 Enter to unlock   ·   Esc to go back
```

**Anything you typed before the card appeared is in the box.** That is not a
nicety; it is the difference between a lock screen that feels instant and one
that eats your first three characters. How it works: the box is there from the
moment the screen locks, holding the keyboard. In the calm state it is simply
drawn at zero opacity. There is nothing to catch up on because nothing was ever
missed.

**Escape** puts the card away and forgets what you typed. So does thirty seconds
of doing nothing — a half-typed password should not sit on a screen anybody can
walk past.

### 3. WRONG PASSWORD

The box moves six pixels, three times, over about a quarter of a second, and
grows a two-pixel red ring. The line underneath says *"That password isn't
right. Try again."* Nothing else on the screen moves.

After the **third** wrong password in a row the box waits ten seconds, counting
down in that same line. That is a pause, not a security measure — Linux has its
own and they are better. It is there so that somebody leaning on a keyboard
cannot hammer the box.

---

## How the password is actually checked

**In one sentence: the shell never checks it. It asks PAM, and PAM answers yes
or no.**

The longer version, because it is the part worth understanding:

1. You type a password and press Enter. The QML hands the text to
   Quickshell's `PamContext` and does nothing else with it.
2. `PamContext` **forks a separate small process**. The entire conversation with
   PAM happens in there, over a pipe. That process is written in C against
   `libpam` and it is part of Quickshell, not part of this shell.
3. That process asks PAM to authenticate you, using a set of rules named
   **`aquarius-lock`**, which the AquariusOS image installs at
   `/etc/pam.d/aquarius-lock`. The file is one line long:

   ```
   auth       include      login
   ```

   which means "use whatever this machine's ordinary login rules are for
   proving who somebody is". So if the machine gains a fingerprint reader, a
   smart card, or a company password policy, the lock screen gets it too,
   automatically, because those are changes to that shared set of rules.
4. Underneath, PAM's `pam_unix` module cannot read `/etc/shadow` either — it is
   running as you, not as root. It hands off to `/usr/bin/unix_chkpwd`, a tiny
   program shipped by Fedora's `pam` package which IS allowed to, and which will
   **only ever check the password of the person who ran it**. That is the whole
   design, and it is why nothing AquariusOS ships needs special powers.
5. The answer comes back as one of four words — success, failed, out of tries,
   error — and the lock screen either lets go or shakes.

**Nothing in `lock/` compares anything.** There is no hash in this shell, no
password file is read, and `tests/test-shell.sh` has a check that fails the
build if a comparison ever appears there.

### This is exactly what every other Linux locker does

We looked. On Fedora, `swaylock`, `hyprlock` and `gtklock` all ship a plain
unprivileged binary (mode 0755, no special powers), all ship a one-line file in
`/etc/pam.d/` containing `auth include login`, and all run their PAM
conversation in a forked child. `swaylock`'s child exists for the same reason
Quickshell's does: PAM has no way to abort a module that is waiting — a
fingerprint reader, a hardware key — except by killing the process it is in.

The one thing we did **not** do is write our own helper, which the spec left
open. There was nothing to gain: Quickshell's is the same architecture, already
written, already in the image, and a second piece of security-critical C to keep
correct is a real cost. The pam.d file is ours; the helper is the runtime's.

### If something is wrong with it

If `/etc/pam.d/aquarius-lock` is missing, `PamContext` refuses to start rather
than hanging, and the card says *"This computer cannot check passwords right
now."* A lock screen that silently ignores your Enter key is indistinguishable
from a frozen computer, and that is the one failure this had to avoid.

---

## What is never shown

This is a list of rules, not of things that happen to be missing.

- **No notification content.** Not a title, not a sender, not an app name, not a
  body, not a preview. Only a count, and `LockState.showNotificationCount` turns
  even that off.
- **No media.** No track title, no artist, no album art, no transport controls.
- **No desktop.** The veil is a picture of the **wallpaper**, from disk, blurred.
  It is *not* a blurred screenshot of your session, which is what several other
  lock screens show. A blur is not redaction: a heading survives it nearly
  intact, and a rendering bug or a slow frame can hand back the sharp version.
- **No photograph on the avatar.** Initials, in the Aquarius blue. The reasoning
  is written out in `greeter/GreeterAvatar.qml` and applies here unchanged.
- **No way out except the password.** The IPC door can lock the machine and can
  answer "are you locked". There is deliberately no `unlock()`, because anything
  that could ask this shell to unlock would be a way past the password, and
  `qs ipc` is reachable by every program running as you.

---

## Walking away from the machine

| After | What happens |
|---|---|
| 5 minutes | The screen **dims**. Nothing is locked. Touch anything and it comes straight back. |
| 10 minutes | The screen **locks**. |
| 15 minutes | The monitor is **turned off**. Touch anything and it wakes into the calm state. |

The shell does not count any of this itself. It asks the compositor, over the
standard `ext-idle-notify-v1` protocol — the same one `swayidle` is a front end
for. That matters because the compositor sees things a timer cannot: input
inside a full-screen game, every monitor, and who has asked to be left alone.

**Apps that ask to be left alone are honoured.** A video player, DaVinci Resolve
exporting, OBS recording, a film in a browser: all of them tell the compositor
"do not call this machine idle", through `idle-inhibit-unstable-v1`, and while
any of them is doing so none of the three timings fires. That is one line of
QML — `respectInhibitors: true` — and it is the line that stops the screen
locking in the middle of a two-hour export.

**Closing the lid locks a laptop**, by the ordinary route: Fedora's logind
suspends the machine when the lid closes, and a small systemd user service the
image installs locks the screen just before it sleeps. So does the **Sleep** word
on the card, and the Aquarius menu's Sleep row. You always wake into the calm
state.

The three numbers live in `theme/Theme.qml` as `lockIdleDimSeconds`,
`lockIdleLockSeconds` and `lockIdleOffSeconds`. They are meant to get a plain
Settings page later; today changing them means changing those.

---

## The files

| File | What it is |
|---|---|
| `lock/qmldir` | Declares `LockState` a singleton. Forgetting this is how you get "LockState is not a type". |
| `lock/LockState.qml` | Everything the lock screen knows, and the whole conversation with PAM. The only file that talks to `PamContext`. |
| `lock/LockLayer.qml` | What `shell.qml` holds: the session lock, the idle watcher and the IPC door. |
| `lock/LockSurface.qml` | One screen's worth of lock screen. One is built per monitor. |
| `lock/LockCard.qml` | The card. Reuses `greeter/GreeterAvatar.qml` unchanged. |
| `lock/LockField.qml` | The password box. Its header says why this is not `GreeterField`. |
| `lock/LockVeil.qml` | The blurred wallpaper and the wash over it. |
| `lock/LockBlur.qml` | Four lines, and the only file in this shell that imports `QtQuick.Effects`. Read its header before touching it. |
| `lock/LockIdle.qml` | Dim, lock, screen off. |
| `lock/lock.qml` | A way to look at the lock screen in the harness. **Not** how it ships. |

### Why it is part of the shell and not its own program

The login screen is a second entry point (`greeter/greeter.qml`) because it
genuinely is a second program — it runs before anybody has logged in, started by
greetd, in a session that does not exist yet.

The lock screen is not that. It runs inside your session, and giving it its own
process would cost three things and buy nothing:

1. **Speed, which here is security.** Super+L has to lock the screen *now*.
   Starting a second program means loading Qt and QML first — the better part of
   a second during which the machine is not locked and you have already walked
   away.
2. The idle watcher has to run all the time anyway, so something in the session
   is always watching. It may as well be the shell.
3. The count of waiting notifications is in the shell, because the shell **is**
   this session's notification service. Across a process boundary that would
   need a protocol of its own for one number.

`ADR 0001` picked Quickshell partly because `WlSessionLock` is in it and speaks
a standardised protocol; nothing in it says a lock has to be a separate process,
and Quickshell's own documentation shows one inside an ordinary shell config.

---

## How to try it

**In the nested harness, which is the right way:**

```bash
./harness/run-nested.sh          # a compositor in a window
qs -p lock/lock.qml              # inside that window
```

It locks itself as soon as it starts, so there is something to look at.

Or run the whole desktop nested and lock it the way a person would. The harness
starts the compositor with the shell's own key bindings, so Super+L works in
the nested window — unless the desktop you are sitting in takes the key first,
which GNOME does (it is GNOME's own lock shortcut). Then send the same message
by hand, from another terminal in the shell's folder:

```bash
qs -p . ipc call lock lock
```

Only the nested window locks. Your real desktop is untouched.

**On a real AquariusOS machine**, it is already there — press Ctrl+⌘Q (Mac keys) or Win+L (Windows keys). That key
binding runs exactly one line, which you can also type yourself:

```bash
qs ipc call lock lock
```

It launches nothing; it sends a message to the shell that is already running,
which is why locking is instant. To see every door the running shell has, `qs
ipc show`. There is deliberately no matching unlock.

To watch what it is doing:

```bash
journalctl --user -f | grep aquarius-lock
```

### ⚠️ Do not run `qs -p lock/lock.qml` on the machine you are sitting at

It will lock your real session, for real. Your real password gets you back in —
but if the code is half-written and crashes while the lock is on, nothing will,
and the way out is a text console.

### If you are ever stuck on a locked screen

This is worth knowing before you need it. A session lock is a promise the
compositor makes: *nothing except the lock's own surfaces gets drawn or gets
input, until the program that asked says otherwise.* That promise is what makes
killing the locker useless as a way past it — and it also means that if the
shell dies while locked, the screens stay covered in a flat colour with nothing
left running that can lift them.

The way out on a real machine:

1. **Ctrl+Alt+F3** — a plain text login screen on another console.
2. Log in with your usual name and password.
3. `loginctl` to find your graphical session's id, then
   `loginctl terminate-session <id>` to end it. You land back at the login
   screen and can start a fresh session.

Nothing you had open is saved by that, so it is a last resort, not a habit.

---

## What was checked before any of this was written

Nothing here was taken from a blog post or from memory. Each line was read out of
the exact version AquariusOS pins, and the version is named so that the next
person can check the same thing after a bump.

**Quickshell v0.3.1** (commit `1a4716c`, the tag `aquarius-os.env` pins), read in
its own source:

| What | Where it was read | What it says |
|---|---|---|
| `WlSessionLock` | `src/wayland/session_lock.hpp` | `locked` (read/write), `secure` (read-only — the compositor confirming every screen is covered), `surface` (a Component, and the default property). The header carries the warning this whole design is shaped around: if the lock dies while on, the screens stay covered and nothing can lift them. |
| `WlSessionLockSurface` | same file | `screen`, `width`, `height`, `color` (**defaults to white** — ours sets `Theme.bg`), `visible`, `contentItem`. **There is no keyboard-focus property**, because the session-lock protocol grants input to the lock surfaces by definition. That is the opposite of layer-shell, where the login screen has to ask. |
| `IdleMonitor` | `src/wayland/idle_notify/monitor.hpp` | `enabled`, `timeout` (**seconds** — `monitor.cpp` multiplies by 1000 for the protocol), `respectInhibitors` (defaults true), `isIdle`. |
| …and what `respectInhibitors` really does | `src/wayland/idle_notify/proto.cpp` | true → `get_idle_notification`, which the compositor suppresses while an app holds an inhibitor. false → `get_input_idle_notification`, which ignores them. This is the line that decides whether a Resolve export gets interrupted. |
| `PamContext` | `src/services/pam/qml.hpp`, `conversation.hpp`, `subprocess.cpp` | `config` (defaults `"login"` — we set `"aquarius-lock"`), `configDirectory` (defaults `/etc/pam.d`), `user` (**unset means the process's own user**, resolved with `getpwuid_r`), `start()`, `respond()`, `abort()`, and the signals `completed(PamResult)`, `error(PamError)`, `pamMessage()`. `start()` **returns false** when the config file is missing, which is why the card can say so instead of hanging. And the conversation genuinely happens in a `fork()`ed child (`subprocess.cpp`) — the comment there says why: PAM has no way to abort a module that is waiting on a fingerprint reader except by killing the process it is in. |
| Both are really compiled in | `CMakeLists.txt` | `WAYLAND_SESSION_LOCK` and `SERVICE_PAM` are both `ON` by default, and `os-image/build_files/stage-quickshell.sh` fails the image build if either is off. |
| Which module they live in | `src/wayland/CMakeLists.txt`, `src/services/pam/CMakeLists.txt` | `Quickshell.Wayland` and `Quickshell.Services.Pam`. |

**labwc 0.20.2** (the tag `aquarius-os.env` pins), read in its own source:

| Protocol | Where | Notes |
|---|---|---|
| `ext-session-lock-v1` | `src/session-lock.c` | Present. ⚠️ It focuses **the first lock surface that maps** and keeps it — which is why every screen here keeps a password box. See the note at the top of `LockSurface.qml`. |
| `ext-idle-notify-v1` | `src/idle.c` | Present. |
| `idle-inhibit-unstable-v1` | `src/idle.c` | Present, and wired into the one above: an inhibitor appearing calls `wlr_idle_notifier_v1_set_inhibited(true)`. So `respectInhibitors` is honoured by the compositor, not by us. |
| `wlr-output-power-management-v1` | `src/server.c` | Present. This is what `wlopm` speaks. |
| A built-in lock or idle action | `src/action.c` | **None.** There is no `Lock` action in labwc's list, so Super+L has to run something — hence `qs ipc call lock lock`. labwc's own documentation recommends driving all of this from outside with `swayidle` + a locker + `wlopm`; we do the same three jobs from inside the shell, with the compositor still doing the counting. |

**Fedora**, read out of the real packages:

- `swaylock` 1.8.6, `hyprlock` 0.4.1 and `gtklock` 4.0.0 all ship `/usr/bin/<name>` at mode **0755 with no setuid and no file capabilities**, and each ships an `/etc/pam.d/<name>` containing the single line `auth include login`. Ours is the same line for the same reasons.
- `/usr/bin/unix_chkpwd`, from `pam` 1.7.2, is mode **4755** — setuid root. Fedora does not use the newer file-capabilities form. It is the only privileged step in the chain.
- `wlopm` 1.0.0 is in Fedora 44.
- `qt6-qtdeclarative` is 6.10.2, so `QtQuick.Effects` (Qt 6.5+) is present — which is what the veil's blur needs.

### Two things the spec assumed that turned out not to be there

- **A helper of our own to write.** The spec asked for "a PAM conversation through a small helper". Quickshell already forks exactly that helper, in C, and it is the same shape swaylock's is. Writing a second one would have meant a second piece of security-critical C to keep correct, for nothing. What we do own is the pam.d file.
- **"Switch user".** greetd cannot hold a second session on a seat, so the word is not there. The spec said to leave it out if so.

---

## What broke on the bench, 6 September 2026

The first time a real machine loaded `lock/`, the desktop failed to start twice.
Both were one-line fixes, both passed every check in `tests/test-shell.sh`
first, and both now have a check of their own.

1. **`Type LockLayer unavailable`** — `lock/qmldir` names `LockState` as a
   singleton, and a folder with a qmldir shows the outside world *only* what the
   qmldir names. `shell.qml` could not see `LockLayer` until it was listed too.
   Test 39 sweeps every folder for this.
2. **`LockLayer.qml[101:5]: Non-existent attached object`** — the line is
   `Component.onCompleted`. `Component` is not part of the language; it is an
   attached type that arrives with QtQuick, and LockLayer.qml draws nothing so
   it never imported QtQuick. The message does not mention imports. Test 40
   now checks every file that writes `Component.on…` for the import. The same
   wire had already been tripped over on 1 September in the notification
   layer, and the warning written there was not enough on its own.

---

## "The dark flip didn't carry over to the lock screen" — 8 September 2026

**What was reported.** On the bench, the machine was set to dark and the lock
screen still looked light.

**What was found when it was actually run.** It could not be reproduced, and
this section exists so nobody spends another afternoon reasoning about it.

The whole chain was driven on the bench machine itself, on the real appearance
portal, with the shell running in an invisible labwc beside the live desktop
(the same trick `harness/load-check.sh` uses, so the person's session was never
touched). Three screenshots were taken:

| Step | What was done | What the lock screen was |
|---|---|---|
| A | machine set to dark, shell started, screen locked | **Midnight** — dark, as it should be |
| B | flipped to light **while still locked** | **Ice** — it changed, live, in about a second |
| C | flipped back to dark **while still locked** | **Midnight** again |

So on this machine, on this build, every link works: the portal answers, the
shell's watcher hears the change, `Theme.dark` follows, and the veil repaints —
including while the screen is already locked, which is the hardest case.

**What is genuinely still wrong, and is a different thing.** The **desktop's**
wallpaper does not follow the theme. It is drawn by `swaybg`, which the session
starts once at login with the Ice picture and never touches again (see
[`session.md`](session.md), "The wallpaper does not follow light and dark").
So a machine flipped to dark has a Midnight bar, a Midnight dock and a *light*
picture behind them. That is the most likely thing to have been seen and read
as "dark did not carry over", and fixing it needs a change on the session's
side, not in the shell.

**And there is now one command instead of an afternoon.** Ask the running shell
what it believes:

```bash
qs ipc call theme status
```

```
system     : following the system (portal, live)
             portal answered: yes; value: 1 (0 no preference, 1 dark, 2 light)
theme      : Midnight (dark)
             because: the system asked for it
wallpaper  : /usr/share/backgrounds/aquarius/the-pour-midnight-3840x2160.png
frames     : /usr/share/aquarius/labwc/generate-theme
desktop    : /usr/libexec/aquarius-wallpaper midnight
```

Read it top to bottom. If `system` says the portal never answered, the fault is
the portal (is `xdg-desktop-portal` running?). If `system` says dark and `theme`
says Ice, the fault is in the shell and that is a bug worth reporting. If both
say dark and the **screen** still looks light, the shell is right and what you
are looking at is something the shell does not draw — the wallpaper, the window
frames, or a GTK application. The file is `services/ThemeStatus.qml`; it only
reads, and there is deliberately no way to force a theme over IPC.

---

## Deviations from the approved spec

Written down rather than quietly done.

- **"Switch user" is not there.** The spec said to leave the word out if the
  login manager cannot do it, and it cannot: AquariusOS logs in through greetd,
  whose model is one session at a time on a seat. There is no way to ask it for
  a second login screen on another console while keeping this session alive.
  GDM can do that; greetd does not. So the row is one word, **Sleep**.
- **The card does not get a second blur of its own.** The spec asked for the
  card to be "surface at 86% with 22px blur". The veil beneath it is already
  blurred, and a translucent surface over a blurred picture is what frosted
  glass looks like; a second full-screen render pass to blur the same wallpaper
  again would cost real frames for a difference you would have to be told about
  to see. Same call, and the same reasoning, as the search palette's missing
  drop shadow.
- **The dim is a dark sheet, not a backlight change.** `brightnessctl` only
  reaches a laptop's built-in panel, and the bench machine's screen is a 55-inch
  monitor on the end of a cable.
- **The helper is Quickshell's, not ours.** See "How the password is actually
  checked". The `/etc/pam.d/aquarius-lock` file is ours.

---

## What is NOT here yet

Named so nobody goes looking.

- **Fingerprint unlock.** The pam.d file already inherits it — if the machine's
  login rules gain `pam_fprintd`, PAM will ask for a finger — but there is no
  UI for it: no prompt, no "touch the reader" line, no way to fall back to a
  password mid-attempt. Until there is, a machine with a reader will show a
  message from PAM that the card is not designed for.
- **An on-screen keyboard.** A tablet or a machine with no keyboard plugged in
  cannot be unlocked from the lock screen.
- **An accessibility menu.** No screen reader, no high-contrast switch, no way
  to change the text size from the lock screen — which is the one place a
  person cannot open Settings to fix it.
- **Media controls.** No play/pause, no track, deliberately (see "What is never
  shown") — but a decision to show *transport buttons only*, with no titles,
  would be a reasonable one and has not been made.
- **A second person's card.** One machine, one person, by design for now.
  Switching accounts means logging out.
- **A Settings page for the three idle timings.** They are defaults in
  `theme/Theme.qml`. The spec says plain language in Settings later; this is the
  "later".
- **A "Switch user" that works.** See the deviations above. It needs a login
  manager that can hold two sessions, which is a bigger decision than this
  screen.
