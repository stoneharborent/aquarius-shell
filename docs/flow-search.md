# Flow Search — the one box

*Phase P2. Lives in `components/search/`. Design source: the V2 artboard
`os-image/branding/design-system/AquariusOS Shell Search.html`, which is an
iframe onto `AquariusOS Desktop Shell.html#search`.*

---

## What it is

One search box, centred over a dimmed desktop. You type what you want. There is
no prefix to remember, no `:` command, no mode to switch into. Working out
whether you meant an application, a sum or a system action is the shell's job,
not yours.

That premise comes from the design, whose subtitle is literally *"KRunner power,
zero commands visible"* and whose footnote reads *"one box, no commands to
learn"*. Everything in this document is downstream of that one idea.

```
 the whole desktop, dimmed
┌────────────────────────────────────────────────────────────┐
│                                                            │
│           ┌──────────────────────────────────────┐         │
│           │ ⌕  kd|                               │         │
│           ├──────────────────────────────────────┤         │
│           │ ▢  Kdenlive                 ↵ open   │         │
│           │    Video editor                      │         │
│           │ =  1440                              │         │
│           │    24 * 60 · press Enter to copy     │         │
│           │ ⏻  Lock screen                       │         │
│           ├──────────────────────────────────────┤         │
│           │ apps · math · actions — one box, no  │         │
│           └──────────────────────────────────────┘         │
└────────────────────────────────────────────────────────────┘
```

---

## The providers, and the two that are missing on purpose

The design's footnote names five things: **apps · files · settings · math ·
actions**. Three of those are real today. Two are not, and this palette does not
pretend otherwise — the footnote it actually draws reads **"apps · math ·
actions"**, and it grows when the providers do.

| Provider | Status | What it is built on |
|---|---|---|
| **Apps** | Shipped | `DesktopEntries` — Quickshell's index of every installed `.desktop` file. |
| **Math** | Shipped | `components/search/calc.js`, ours, no dependency. |
| **Actions** | Shipped, **interim** | `loginctl` / `systemctl` through `Quickshell.Io.Process`. See below. |
| **Files** | Not built | Needs an index. |
| **Settings** | Not built | Needs a settings app. |
| Web | Never | Not a provider. |

### Why files is not here

A file provider is four lines of QML if you are willing to lie about it: run
`find` on every keystroke, show whatever comes back, call it search. That is not
file search. It is a way to make a laptop hot and a palette slow, and it gets
worse the more files a person has — which, for the creator this OS is built for,
is the entire point of their machine.

Real file search means a real index. On a Fedora desktop that almost certainly
means talking to **Tracker** over D-Bus, which already indexes the home
directory and already has the metadata a creator would want to search by. That
is a provider worth building and it is P3 work, alongside the other services.

### Why settings is not here

There is no settings application yet. Searching one that does not exist would
mean hard-coding a list of rows that open nothing. P3.

### Why web search is not on the list at all

Typing into a desktop search box should never quietly become a network request.
Not as a fallback, not "only when nothing else matched". If a web search is ever
wanted it is an explicit action with an explicit row, chosen deliberately.

### The session actions are interim, and here is the honest note

`Lock screen`, `Log out`, `Suspend`, `Restart` and `Power off` shell out to
`loginctl` and `systemctl`. That is not the eventual design — a desktop should
talk to logind over D-Bus — but Quickshell 0.3.1 ships no logind binding, so the
choice was between running systemd's own front-end commands or shipping no
session actions at all.

What makes it acceptable: those two commands are present on every system this OS
can run on, and they call exactly the D-Bus interfaces we would otherwise call
ourselves. What makes it interim: spawning a process per action is slower, gives
worse errors, and cannot tell us whether an action is even *permitted* before
offering it. Replace when a logind binding exists.

Three details worth knowing:

- **Log out only appears when `XDG_SESSION_ID` is set.** `loginctl
  terminate-session` needs to be told which session, systemd puts the answer in
  the environment, and if it is not there we do not guess. A "Log out" that ends
  the wrong session is worse than a missing row.
- **Session actions never appear on a one-letter query.** Typing `l` should not
  put "Log out" on screen next to your text editor.
- **Restart, Power off and Log out ask twice.** The first Enter arms the row and
  the subtitle changes to "Press Enter again to confirm"; the second runs it.
  Nothing moves on screen between the two presses, so the second Enter lands
  where you are already looking. Changing the query or the selection disarms.

---

## Summoning: the IPC contract

**This is the part another branch depends on. It is a contract, and
`tests/test-shell.sh` section 14 fails if any part of it drifts.**

### Why the shell cannot bind a key itself

On Wayland there is no such thing as an application registering a global hotkey
with the display server. Keybinds belong to the **compositor** — that is the
design of the platform, not a gap in it. A layer-shell client only receives keys
while it holds keyboard focus, and a palette that is not on screen holds nothing.

So the shell cannot bind Super. What it can do is open a door for the
compositor's own keybind to knock on.

### What was checked before choosing IPC

Quickshell 0.3.1 **does** ship a `GlobalShortcut` type. It is in the
`Quickshell.Hyprland` module, and it speaks `hyprland-global-shortcuts-v1`,
which is Hyprland's own protocol and not a standard. Using it would break this
repo's one architectural law, and `tests/test-shell.sh` fails the build if
anybody imports that module.

**There is no portable alternative in 0.3.1.** The full type index
(<https://quickshell.org/docs/v0.3.1/types/>, read 2026-08-31) contains exactly
one shortcut-related type outside the Hyprland module: `ShortcutInhibitor` in
`Quickshell.Wayland`, which stops the *compositor* eating keys while a window is
focused — the opposite problem. There is no binding to
`org.freedesktop.portal.GlobalShortcuts`; that portal exists as a specification,
but nothing in Quickshell speaks it and its backends are not universal across
compositors. **Finding recorded either way, as asked: the portal route is not
available to us today.** If Quickshell gains it, the palette grows a second
summoning path and loses nothing.

### The exact call

```
qs ipc -c aquarius-shell call search toggle
```

Broken down, because every piece of it is load-bearing:

| Piece | What it is | Where it comes from |
|---|---|---|
| `qs` | the Quickshell binary | Fedora package `quickshell` |
| `ipc` | the subcommand | `qs ipc --help` |
| `-c aquarius-shell` | **which shell instance** | the config *name*, i.e. the directory `~/.config/quickshell/aquarius-shell/` containing `shell.qml` |
| `call` | invoke a handler function | |
| `search` | **which handler** — `IpcHandler.target` | `components/search/FlowSearch.qml` |
| `toggle` | the function on it | same file |

> **Note for the coordinator, because the brief was ambiguous.** The brief said
> the compositor branch "will bind to the IPC target named `aquarius-shell`".
> Those are two different names in Quickshell's CLI and both appear above:
> `aquarius-shell` is the **config name**, selected with `-c`, and it matches
> this repo's directory name. The **IPC target** — the handler — is `search`,
> because the shell will grow more handlers (`notifications`, `quicksettings`,
> `dock`) and a single handler called `aquarius-shell` with `searchToggle`,
> `notificationsToggle`, … glued onto it is a worse shape. The command line
> above contains both strings, so a config written against either reading of the
> brief still works if it copies the whole line.

Config selection options attach to the `ipc` subcommand itself, which is why
`-c` sits between `ipc` and `call` (verified against Quickshell's
`src/launch/parsecommand.cpp`, where `addConfigSelection(sub, true)` is applied
to the `ipc` subcommand).

### The three endpoints

| Call | Does |
|---|---|
| `qs ipc -c aquarius-shell call search toggle` | open if closed, close if open — **this is the one to bind** |
| `qs ipc -c aquarius-shell call search open` | always open, and reset |
| `qs ipc -c aquarius-shell call search close` | always close — also the way out if it ever gets stuck |
| `qs ipc -c aquarius-shell call search isOpen` | prints `true` / `false`, for scripts |

`qs ipc show -c aquarius-shell` lists them at runtime. **That is the first thing
to run when a keybind does nothing.**

### Illustrative compositor binds

The compositor configs are a sibling branch's files, not this one's. These are
here so the contract is unambiguous, not as the final config.

**niri** — verified against niri's own `resources/default-config.kdl`, where
`spawn` takes each argument as its own quoted string:

```kdl
binds {
    Mod+Space hotkey-overlay-title="Search" {
        spawn "qs" "ipc" "-c" "aquarius-shell" "call" "search" "toggle";
    }
}
```

**labwc** — verified against labwc's own `docs/rc.xml`:

```xml
<keybind key="W-space">
  <action name="Execute" command="qs ipc -c aquarius-shell call search toggle" />
</keybind>
```

**sway** and **Hyprland**, for completeness — standard syntax, *not* verified
against their current documentation in this pass:

```
# sway
bindsym $mod+space exec qs ipc -c aquarius-shell call search toggle

# Hyprland
bind = SUPER, Space, exec, qs ipc -c aquarius-shell call search toggle
```

**Super alone versus Super+Space.** Binding the bare Super key is a compositor
feature, not a shell one: it needs the compositor to distinguish a tap from a
modifier hold, and not every one of them will. `Super+Space` works everywhere.
The compositor-config branch should ship `Super+Space` and add bare `Super` only
where the compositor genuinely supports it.

### The other way in

Clicking the Aquarius mark at the left of the top bar opens the same palette.
That is wired in `shell.qml`, and it means the palette is reachable on a bench
machine before any keybind exists.

---

## Keyboard focus on a layer-shell surface

A layer-shell surface gets no keyboard input unless it asks. `PanelWindow` has
`focusable`, which the Quickshell docs say maps to
`WlrLayershell.keyboardFocus`, whose three settings are `None`, `OnDemand` and
`Exclusive`.

**The palette asks for `Exclusive`**, because it is modal: it dims the desktop,
it is the only thing you can be typing at, and `OnDemand`'s own documentation
describes focus as *"as determined by the operating system"* — which for a
surface that appeared because of a keybind rather than a click is precisely the
case where an operating system might decide not to.

Two safety properties, both deliberate:

- **The surface only exists while the palette is open.** `visible` is bound to
  `isOpen`, so closing destroys the window and with it the keyboard grab. A
  crash cannot leave a grab behind.
- **There is a way out from outside.** `qs ipc -c aquarius-shell call search
  close` closes it from any terminal, another machine over SSH, or a TTY.

If `Exclusive` misbehaves on the bench, set `exclusiveKeyboard: false` on the
`FlowSearch` object and it falls back to `OnDemand`. The upgrade is applied in
`Component.onCompleted` rather than as a declarative binding, so it definitively
runs after `focusable` has had its say and there is no argument about which one
wrote the property last.

### Asking for the keyboard is not enough if something else already has it

Everything above is about *asking politely*. None of it helps while another
shell surface is holding a compositor **input grab** — and Quick Settings holds
one, being a `PopupWindow` with `grabFocus: true`.

That is defect 1 from the first run on hardware, reproduced on 2026-09-01: open
Quick Settings, then press the search key. The palette appears. The desktop
dims. The cursor blinks. And not one keystroke arrives, with nothing on screen
to say why.

**The rule the shell settled on:** opening any exclusive overlay closes the
others — Flow Search, Quick Settings and the notifications panel, in every
direction, on every screen. It lives in `services/Overlays.qml`, and the palette
takes part in three lines:

- `Overlays.register(root, () => root.closeSearch())` when it is created;
- `Overlays.unregister(root)` when it is destroyed;
- `Overlays.claim(root)` at the top of `openSearch()` — **before** `isOpen`
  becomes true, so the old grab has been told to let go while there is still
  nothing new asking for the keyboard.

Read the header of `services/Overlays.qml` for why the registry is a list rather
than a single "which one is open" value (Quick Settings exists once per monitor),
and `docs/quick-settings.md` for the same rule written from the other side.
`tests/test-shell.sh` section 27 fails if any of the three stops taking part.

**This has not been re-run on hardware.** See the unproven list below.

**Which screen it appears on.** The palette deliberately does *not* set `screen`
and is deliberately *not* wrapped in `Variants` the way the bar is. The bar wants
to exist once per monitor; a search box wants to exist once, where you are
looking. With `screen` unset the compositor places it, and the compositor is the
only thing that knows which output has your attention — asking ourselves would
need a compositor-specific "active monitor" call, which is the thing this repo
does not do.

---

## How matching works

`components/search/fuzzy.js`. Plain JavaScript, no QML, no state — which is why
it is the one part of this shell that is genuinely **unit tested** (see below).

Matching is **tiered**. Each tier is a band of scores that cannot overlap the
one below it, whatever the tie-breaks do:

| Score | Tier | Example |
|---|---|---|
| 1000 | the text **is** the query | `files` → "Files" |
| 860–900 | the text **starts with** it | `kd` → "**Kd**enlive" |
| 760–800 | a **word inside** starts with it | `term` → "GNOME **Term**inal" |
| 710–750 | it is the text's **initials** | `vlc` → "**V**ideo **L**an **C**lient" |
| 610–650 | it appears **somewhere inside** | `enli` → "Kd**enli**ve" |
| 200–500 | the letters appear **in order**, with gaps | `kde` → "**K**ate **D**ocum**e**nt" |
| −1 | no match | |

Within a tier, **shorter text wins** — when two programs both start with what you
typed you almost always meant the one whose name is closest to it. That
tie-break is capped at 40 points so it can never push a result out of its tier.

Each application is scored against several fields, weighted:

| Field | Weight | Why |
|---|---|---|
| `Name` | 1.0 | what people type |
| `GenericName` | 0.7 | "Video Editor" |
| `Keywords` | 0.65 | the `.desktop` file's own synonyms |
| `Id` | 0.6 | `org.kde.kdenlive` |
| `Comment` | 0.5 | the long description — how "edit video" finds an editor that never says "video" in its name |

Because the tiers are on a 1000 scale and the weights are fractions, a
**0.65-weighted exact match (650) still beats a full-weight scattered match
(≤500)** — a keyword you typed exactly is a better signal than a name you nearly
typed. That property is asserted in the tests.

Ties break on score, then alphabetically. At most **8 results** are shown: a
launcher that fills the screen with near-misses is one you have to read instead
of one you can glance at.

**There is no usage ranking, and this is a known gap.** Every other launcher
learns which apps you open and floats them up. Quickshell's `DesktopEntries`
documentation says outright that there is "currently no mechanism for usage
based sorting", so doing it means us storing a frequency table. That is a real
improvement and it is not in this branch.

**The empty query shows nothing.** Not the top eight apps alphabetically — with
no usage data that list is arbitrary noise, and a palette that opens onto noise
teaches you to ignore what is in it. The placeholder says what the box can do
instead.

### Ordering between providers

- If the query **starts like arithmetic** (a digit, a bracket, a sign, a decimal
  point) the sum goes first — that is what you asked for.
- Otherwise applications come first and the sum, if there is one, goes below
  them.
- Session actions always come last.

---

## The calculator

`components/search/calc.js`. Tokeniser plus a precedence-climbing parser, about
250 lines with the comments.

**It does not use `eval()`.** The string being evaluated is whatever a person
typed into a box that holds the whole desktop's keyboard focus, and `eval` would
happily run `Quickshell.reload()`, a loop that never ends, or anything else in
scope. Nothing about "it is only my own machine" makes that acceptable in a
shell. Every name that is not on a fixed whitelist is a parse error, not a
lookup, so there is no path out of the file.

Understands: `+ - * / % ^`, the typographic `×` and `÷`, brackets, `pi` `tau`
`e`, and `sqrt cbrt abs round floor ceil exp ln log log2 log10 sin cos tan asin
acos atan pow min max`. `^` binds right-to-left, so `2^3^2` is 512.

`%` is **remainder, not percent-of**. "50% of 80" is a future provider, not a
half-implemented one.

**It stays quiet unless something was actually calculated.** The whole string
must parse *and* at least one binary operator or function call must have run.
Typing `8` gets you your apps, not a row telling you that 8 is 8. Typing
`kdenlive` is not arithmetic and never becomes it.

Answers are rounded to 12 significant figures, so `0.1 + 0.2` reads `0.3` rather
than `0.30000000000000004`. Enter copies the answer to the clipboard — done
while the palette still holds focus, because Quickshell's clipboard only writes
while one of our windows is focused.

---

## What the palette does with keys

| Key | Does |
|---|---|
| anything printable | types into the box; results update as you go |
| `↑` / `↓` | move the selection, wrapping at both ends |
| `Tab` / `Shift+Tab` | the same — there is nowhere else for focus to go |
| `Enter` | run the selected row, or arm it if it needs confirming |
| `Esc` | close |
| click outside the panel | close |

Everything not listed falls through to the text box untouched, so Home, End,
word-jumps, selection and undo all still work.

---

## Deviations from the design

The V2 artboard is a dark, glass design; this shell is Ice-first and solid. Each
difference below is a decision, not drift.

| Design | Here | Why |
|---|---|---|
| `rgba(13,15,24,.76)` + `backdrop-filter: blur(24px)` panel | solid `Theme.surface` | Same call the top bar already made ("Glass removed", `os-image/docs/plasma-style.md`), kept so the two shells look like one product while both exist. |
| `box-shadow: var(--shadow-pop)` under the panel | a stronger hairline (`Theme.lineStrong`) | Qt's drop shadow lives in `QtQuick.Effects` — a second render pass and a second import for one flourish. Revisit if the bench says the panel does not read as floating. |
| footnote "apps · files · settings · math · actions" | "apps · math · actions" | The footnote is a promise. It grows when the providers do. |
| a file row and a "Keep display on" row in the mock | not drawn | See the providers section. |
| query text 17px, row title 13px, subtitle 11px | 18 / 14 / 12 | The nearest steps on the type ladder in `theme/Theme.qml`, which already rounds this way (13.5 → 14, 12.5 → 13). |
| keycap and footnote at 10.5px mono | 11px, new token `Theme.fsMonoSm` | The one genuinely off-ladder size; added as a token rather than typed into a component. |
| dark scrim `rgba(6,7,12,.45)` | `Theme.scrim` — Ice's navy at 35%, Midnight's at 60% | Ice is a light theme. The same 45%-black would turn a light desktop into a dark one. |

### New theme roles this branch added

Both were added to **`Ice.qml` and `Midnight.qml` in the same edit**, which
`tests/test-shell.sh` section 5 enforces:

| Role | Ice | Midnight | For |
|---|---|---|---|
| `scrim` | ink navy @ 35% | bg navy @ 60% | the dim behind a modal surface |
| `accentWash` | Aquarius Blue @ 14% | Deep Sky Blue @ 14% | the selected row — the accent's counterpart to `hoverWash` |

Plus, in `Theme.qml` only (these are not colours, so they have no twin): the
`fsMonoSm` type step and a `searchXxx` block of artboard measurements, written
the same way the existing `barXxx` block was.

---

## What has actually been tested

**The QML runs — 2026-09-01, on the bench PC.** The palette opens over its
scrim, takes keystrokes, and answers: `12.5 * 8` gives 100 with *press Enter to
copy*, and typing letters lists real applications with their real icons. It was
opened over IPC (`qs -p . ipc call search open`), which is itself the first proof
the summoning path works.

**What that does not cover:** pressing Enter on a result — launching an
application, copying a sum, running a session action — has still never been done.
Everything below the input box is proven to DRAW, not to ACT.

**The JavaScript has been run, and this is new.** `fuzzy.js` and `calc.js` are
deliberately plain `.pragma library` JavaScript rather than QML, so `node` can
load and execute them on the Mac this was written on.
`tests/search-js-tests.mjs` runs **73 assertions** against them:

- every tier of the matcher lands in its own band and never a lower one
- the right application wins the head-to-heads the tiers exist for
- the calculator gets the design's own example right, and 20 others
- and — the half that matters most — **every string the calculator must refuse**:
  `Math.PI`, `globalThis`, `process.exit(1)`, a function literal, an assignment,
  a template literal, an unclosed bracket, an unknown name, and expressions long
  or deep enough to be a denial of service.

Section 13 of `test-shell.sh` fails if either file ever reaches into QML, because
that is the change that would silently stop node being able to test them.

### The unproven list — everything below is a hypothesis

1. **That the QML parses at all.** Bracket-balanced and reviewed, not compiled.
2. **That `focusable: true` plus the `Component.onCompleted` upgrade to
   `WlrKeyboardFocus.Exclusive` actually yields keyboard focus.** The order in
   which `focusable` and a direct `keyboardFocus` write settle is reasoned
   about, not observed. If keys do not reach the box, this is the first suspect.
3. **That `Exclusive` does not lock out the compositor's own keybind**, i.e.
   that Super+Space still closes the palette rather than being swallowed.
   Compositors normally process their binds first; "normally" is not "verified".
4. **That an unset `screen` puts the palette on the output the user is looking
   at**, rather than always on the first one.
5. **That `readonly property var results: root.build(root.query)` re-evaluates
   when applications are installed or removed** — it should, because
   `DesktopEntries.applications.values` is read during evaluation, but QML's
   dependency capture through a function call is being trusted, not seen.
6. **That `Quickshell.iconPath(name, true)` returns `""` often enough** that the
   monogram fallback is the exception and not the rule. If most apps fall back,
   the icon theme in the image is the problem, not this code.
7. **That `DesktopEntry.execute()` launches the app** and that it survives a
   shell reload.
8. **That the `loginctl` and `systemctl` commands are permitted** for a normal
   user session on Bazzite without polkit prompting. `Restart` and `Power off`
   in particular may need an authorisation agent that this shell does not yet
   have (that is P3's polkit agent).
9. **That writing `Quickshell.clipboardText` while the palette is focused
   actually reaches the clipboard.**
10. **That the panel's geometry is right on a real screen.** 560px wide, 170px
    down, is an artboard number at 1280×800 — the same open question the roadmap
    asks about the bar's 30px.
11. **That `WlrLayershell.namespace` can be set declaratively.** The docs say it
    cannot be changed after the window connects; setting it in the declaration
    should be before that, but "should" is doing work.
12. **That `Qt.callLater(field.takeFocus)` is late enough** for the surface to
    exist and early enough that the first keystroke is not lost.
13. **That `Theme.easeOut` is a valid `easing.bezierCurve`.** The row's hover
    fade is the first thing in this repo to use it. `[0.22, 1, 0.36, 1, 1, 1]`
    is the right shape for a cubic curve, but Qt rejects a malformed one at
    runtime rather than at parse time.
14. **Every string in the interface.** No `qsTr` call has been through a
    translator or been seen at a real font size.
15. **That dismissing Quick Settings on the way open actually gets the keyboard
    back.** This is the fix for defect 1 (see the keyboard-focus section above),
    and it is the one that matters most on the next bench run. `openSearch()`
    calls `Overlays.claim()` before the surface goes up, which is the right
    order to ask in — but whether the compositor has released the grab by the
    time this palette's layer surface asks for focus is the compositor's
    business, and **it has not been re-tested on hardware**.

    What *has* been checked: the `Overlays` singleton's own logic was executed
    under Quickshell 0.2.1 on Qt 6.11 (register, refuse a duplicate, `claim()`
    closing everybody but the caller, `closeAll()`, `unregister()`), and the
    whole shell was loaded in the nested harness with all three overlays seen
    registering at start-up. That proves the wiring exists, not that the
    keystrokes land.
16. **That the palette closing does not leave the notifications panel's
    full-screen click-catcher behind**, or vice versa. Both are full-screen
    layer surfaces; they are now never open at the same time, which is the
    point, but the transition itself is unobserved.

---

## How to test it on the bench

On a Linux machine, following `harness/README.md` for the setup:

```bash
./harness/run-nested.sh
```

Then, in order — each step is a thing that can fail on its own:

1. **Does the shell start at all?** A QML syntax error stops everything. If the
   bar does not appear, run `qs log -c aquarius-shell` and read the first error,
   not the last.

2. **Is the handler registered?**
   ```bash
   qs ipc show -c aquarius-shell
   ```
   Expect a `target search` block listing `toggle`, `open`, `close`, `isOpen`.
   If it is not there, nothing else in this list can work.

3. **Does it open from the outside?**
   ```bash
   qs ipc -c aquarius-shell call search toggle
   ```
   The desktop should dim and the panel appear. Run it again to close.

4. **Does it take keystrokes?** With the palette open, type `fi`. If characters
   appear, `Exclusive` keyboard focus works and unproven item 2 is settled. If
   nothing appears, set `exclusiveKeyboard: false` in `shell.qml`'s `FlowSearch`
   block, save (the shell live-reloads), and try again.

5. **Do apps come back, and is the right one first?** Type the first two letters
   of something you know is installed. The nested compositor's environment may
   have very few `.desktop` files — install one deliberately if the list is
   empty, before concluding the provider is broken.

6. **Does Enter launch it?** The palette should close and the application appear
   in the nested compositor.

7. **Does the sum work?** Type `24 * 60`. Expect a green `=` row reading `1440`.
   Press Enter, then paste somewhere inside the nested session.

8. **Does the confirm work?** Type `power`. Expect "Power off" with `↵↵ confirm`.
   Press Enter **once** — the subtitle should change and *nothing should happen*.
   Press `Esc`. **Do this before testing anything else with `restart` in it.**

9. **Does Escape close, and does clicking the dimmed area close?**

9b. **Does it survive Quick Settings being open? (Defect 1.)** Click the bar's
    status cluster to open Quick Settings, then summon the palette without
    closing it. Quick Settings must vanish, and **typing must reach the search
    box** — that second half is the whole test; a palette that appears and
    ignores the keyboard is exactly the failure this was written to kill. Then
    the reverse: with the palette open, click the status cluster. The palette
    must close and the panel must open on that one click. Same both ways with
    the notifications panel from the clock.

10. **Does opening reset?** Type something, close, reopen. The box must be empty.

11. **Does the compositor keybind reach it?** Add the niri bind from the section
    above to the harness's config, restart the nested compositor, press
    Super+Space. Then press it *again while the palette is open* — that is the
    test for unproven item 3.

12. **The design questions**, which are the ones that actually decide whether
    this was worth building: does the palette land where your eye already is?
    Is 560px too wide on a laptop screen? Does the Ice scrim dim enough to focus
    attention without making the desktop look broken? Is the monogram tile
    charming or is it a missing icon?

---

## Files

| Path | What it is |
|---|---|
| `components/search/FlowSearch.qml` | the palette window, the IPC handler, keyboard and selection |
| `components/search/SearchEngine.qml` | the providers; produces the result list, runs the chosen one |
| `components/search/SearchField.qml` | the one box and its magnifier |
| `components/search/ResultRow.qml` | one row: tile, title, subtitle, key cap |
| `components/search/fuzzy.js` | the matcher — pure JavaScript, tested |
| `components/search/calc.js` | the calculator — pure JavaScript, tested |
| `tests/search-js-tests.mjs` | the 73 assertions, run by node |
| `services/Overlays.qml` | the one-overlay-at-a-time rule, shared with Quick Settings and the notifications panel |
| `theme/Theme.qml` | gained the `searchXxx` measurements and `fsMonoSm` |
| `theme/Ice.qml`, `theme/Midnight.qml` | each gained `scrim` and `accentWash` |
| `shell.qml` | gained `FlowSearch { id: flowSearch }` and the bar's launcher wiring |
