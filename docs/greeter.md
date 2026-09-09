# The login screen

*Written 2026-09-04. The shell's second entry point: `greeter/greeter.qml`.*

---

## Why this exists

Royce photographed the bench machine booting on 2026-09-04. The screen he logs
in at was stock Fedora GDM — flat light grey, two small name tiles adrift on a
55" 4K monitor — while the screen he unlocks at inside the session is the
Aquarius design. His note was short: make the first one look like the second.

They are two different programs. The one inside the session is this shell. The
one at boot is GNOME's, and there is a limit to how far it can be pushed
(there is no setting for its background in any GNOME up to 50, and the only
ways round that are the theme treadmill this project refuses to walk). The
AquariusOS side of that story is in the os-image repository at
`docs/restart/login.md`.

This folder is the other answer: **our own login screen, drawn by this shell.**

---

## What it is

```
                      09:42
                 Friday 4 September

        ┌──────────────────────────────────────┐
        │             ◭  AquariusOS            │
        │                                      │
        │                ( RA )                │
        │           ‹  Royce Adkins  ›         │
        │                                      │
        │   ┌──────────────────────────────┐   │
        │   │ ••••••••                     │   │
        │   └──────────────────────────────┘   │
        │   Password:                          │
        │                                      │
        │          ◇ Aquarius Desktop          │
        └──────────────────────────────────────┘

   Enter to sign in  ·  Esc to start over  ·  ← → for another desktop
```

On the Ice wallpaper — "The Pour" — with the Aquarius mark, the shell's
typefaces, the shell's colours and the shell's spacing, because it is built out
of `theme/` like everything else here.

It is a **second entry point** for this repository, not a second application.
`shell.qml` is the desktop; `greeter/greeter.qml` is the login screen; they share
`theme/` and the Aquarius mark and nothing else. Run it the same way:

```bash
qs -p greeter/greeter.qml
```

Without a greetd socket in the environment it draws, shows the accounts on the
machine, and cannot log anybody in — which is exactly what you want when you are
working on how it looks.

---

## The five steps of logging in

A login screen does not check passwords. It is not allowed to: a program that
could check passwords could also be tricked into saying yes. It holds a
conversation with a small trusted program that can — **greetd** — and the
conversation always goes the same way:

| | what happens | the call |
| --- | --- | --- |
| 1 | we say who is logging in | `Greetd.createSession("royce")` |
| 2 | greetd asks a question — usually "Password:" | `authMessage(…)` |
| 3 | we answer it | `Greetd.respond("…")` |
| 4a | greetd says no | `authFailure("…")` |
| 4b | greetd says yes | `readyToLaunch()` |
| 5 | we ask for the desktop to start, and exit | `Greetd.launch(cmd, env, true)` |

**Forgetting one step does not produce an error. It produces a login screen
that hangs** — you press Enter and nothing happens, for ever. That is why
`tests/test-shell.sh` section 32 checks that every one of them is reached from
somewhere in `greeter/`.

### The thing that is easy to get wrong

People type their password and press Enter *before* greetd has been asked
anything, because the box is right there and that is how every login screen has
ever worked. So the first Enter does two jobs: it starts the conversation, and
it puts the typed password aside to answer step 2 with the moment it arrives.
`GreeterState.pendingAnswer` is that put-aside password. It is cleared the
instant it is used, the instant an attempt fails, and whenever the chosen
account changes — a password half-typed for one person must never be sent as
another person's.

---

## The files

| File | What it is |
| --- | --- |
| `greeter/greeter.qml` | The front door. One full-screen window per monitor, and nothing else. Kept short on purpose, like `shell.qml`. |
| `greeter/qmldir` | Declares `GreeterState` a singleton. Without this line the login screen fails to start with "GreeterState is not a type". |
| `greeter/GreeterState.qml` | **Everything that thinks.** Who can log in, what they can log in to, which is selected, and the whole conversation with greetd. |
| `greeter/GreeterWindow.qml` | One screen's worth: the wallpaper, the clock, the card, the keyboard hints. Only the first monitor gets the card and the keyboard. |
| `greeter/GreeterCard.qml` | The card itself — mark, person, password box, status line, desktop pill. |
| `greeter/GreeterField.qml` | The password box, and every key the login screen understands. |
| `greeter/GreeterAvatar.qml` | The round mark with a person's initials in it. |
| `greeter/GreeterStepArrow.qml` | The ‹ › either side of the name. |
| `greeter/GreeterDesktopPill.qml` | Which desktop is about to start. |
| `greeter/aquarius-greeter-info` | A small Python program that prints the accounts and the desktops as JSON. AquariusOS installs it at `/usr/libexec/aquarius-greeter-info`. |

---

## Telling the boot animation it can let go

Added 8 September 2026, after the bench boot showed a few seconds of black
screen and then a few seconds of scrolling text before the login screen.

**The problem, in one sentence.** The Aquarius boot animation is drawn by a
program called Plymouth, and if Plymouth lets go of the screen before the login
screen has painted anything, the text console takes the screen in the gap. That
gap is the "commands, terminals and text during boot" Royce asked never to see.

**The handshake.** It is the same one GNOME's login screen uses. The login
screen touches a file the moment it has drawn; the session watches for that
file, and only then runs `plymouth quit --retain-splash`, which hands the screen
over with the last frame of the animation still on it.

```
/run/aquarius-greeter/ready
```

**Why a folder and not a file loose in `/run`.** `/run` belongs to root and the
login screen does not run as root — it runs as greetd's own unprivileged user,
which cannot create anything there. So `greetd.service` makes
`/run/aquarius-greeter/` first, owned by that user, and the greeter writes
inside it. (An earlier draft of the contract said `/run/aquarius-greeter-ready`,
loose in `/run`; that could never have been written. The watchdog accepts both
names; the greeter writes the one that works.)

**When it is written.** On the primary screen only — there is one login screen
even on a desk with three monitors — one turn of the event loop after the window
is really visible, which is the same pattern the keyboard grab uses and for the
same reason: the surface has to exist before anything can be said about it. It
is written once; a second monitor appearing later does not touch it.

**If it fails, nothing breaks.** On somebody's own desktop, or in the harness,
there is no `/run/aquarius-greeter` and no way to make one. The touch fails, one
sentence goes into the log, and the login screen carries on exactly as before.
On a real machine the worst case is that the boot animation is dismissed by the
watchdog's timer instead of by us — a second of plainness, not a computer nobody
can log into. A login screen may never be taken down by a piece of housekeeping.

**To try it without being root**, point it somewhere you can write:

```bash
AQ_GREETER_READY_STAMP=/tmp/greeter-ready qs -p greeter.qml
```

The file appears as soon as the login screen draws, and the log says so.

> ⚠️ **One QML trap, found writing this.** An object may have exactly **one**
> handler per signal. `GreeterWindow.qml` already had an `onVisibleChanged` (it
> is what puts the cursor in the password box), so adding a second one for the
> stamp did not warn — it failed the whole login screen to load with *"Property
> value set multiple times"*. Both things now happen in the one handler at the
> bottom of that file, with a note beside the stamp saying so.

---

## Decisions worth knowing about

**Layer-shell, not an ordinary window.** A layer-shell surface covers the whole
screen with no title bar and nothing able to appear over it — which is what a
login screen is. It also means the compositor underneath only has to speak
layer-shell, so AquariusOS runs it on labwc, which it already ships.

**The keyboard is taken exclusively.** `focusable: true` maps to OnDemand, which
means "focus me if the system decides to". On a screen where nobody has clicked
anything the system may decide not to, and a password box that does not take
typing looks exactly like a frozen computer.

**No photographs on the avatars — initials instead.** The reasoning is written
out in full at the top of `GreeterAvatar.qml`. The short version: those pictures
live in a folder with a long cross-distribution history of unreadable
permissions, and making them round needs an effects module this shell does not
otherwise import — which would mean the *whole login screen* failing to load on
the day that module is missing. Bad trade for a decoration. The helper already
reports where each picture is, so the day it is worth doing, this is the only
file that changes.

**The accounts are read from `/etc/passwd`, not AccountsService.** AccountsService
is the "proper" way and needs a D-Bus client this shell has none of. The one
thing we want from it — a person's real name — is already in `/etc/passwd`.

**The `Exec=` line is split in the helper, not in QML.** greetd is handed a list
of words, not a line of shell; something has to split it, and `shlex` in Python
understands quotes exactly the way a shell does.

---

## What is NOT here yet

Written down so nobody has to guess whether it was forgotten.

- **No restart or shut down buttons.** They need a polkit conversation the
  greeter user does not have set up yet.
- **No fingerprint reader.** greetd can carry it — it arrives as another
  `authMessage` — but it has never been tried here.
- **No on-screen keyboard**, so this is not yet a login screen for a machine
  with no physical keyboard.
- **No accessibility menu.** GDM has one; this does not. That is a real
  regression against GDM and it is why GDM stays installed.
- **The clock, the card and the keyboard live on the first monitor only.** The
  others show the wallpaper.

---

## Trying it

On any Linux machine with Quickshell:

```bash
qs -p greeter/greeter.qml
```

On AquariusOS, the whole chain — greetd, labwc, this — plus how to switch to it
and how to switch back, is in the os-image repository at
`docs/restart/login.md`. The short version is `sudo aq login use greetd`, and
the way back out is `sudo aq login use gdm` from a text console.
