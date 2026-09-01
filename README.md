# Aquarius Shell

**The beginning of AquariusOS's own desktop.** The bar, and eventually the dock,
the panels, the search box and the notifications — written by us, looking the way
we designed them, rather than someone else's desktop wearing our colours.

It does not replace anything yet. It runs beside the real thing, in a window.

---

## What this is, and why it exists

AquariusOS ships **GNOME** today, themed to look like ours. That works, it is
real product, and it keeps shipping. But a themed desktop can only ever look
*mostly* right — the shapes, the spacing and the behaviour belong to somebody
else, and the parts that matter most to a creator (a bar that knows what you are
rendering, a search box that can find a shot inside your footage) are not things
a theme can add.

So there are two tracks:

| Track | What it is | Status |
|---|---|---|
| **SHIP** | Bazzite + GNOME, themed. The operating system people install. | Live, in `../os-image/` |
| **PROTOTYPE** | This repo. Our own shell, built piece by piece. | Phase P1 — one bar exists |

The prototype track never puts the shipping track at risk. That rule does not
bend.

---

## The one architectural law

> **The shell speaks only standardised Wayland protocols. Never a private
> interface belonging to one particular window manager.**

In plain terms: there are two ways for a bar to ask a window manager "let me be a
bar". One is a published protocol that many window managers implement. The other
is a back door into one specific window manager's internals.

We only ever use the published one — `wlr-layer-shell` for panels,
`ext-session-lock` for the lock screen, `StatusNotifierItem` for the tray,
`wlr-foreign-toplevel-management` for knowing which app is focused, and the
desktop portals for screen recording and file dialogs.

This is not fussiness. Every desktop project that took the back door ended up
maintaining a fork of somebody else's window manager, and every one of them
eventually fled the fork after years of work. Deepin spent five years proving it.
Because we obey the law, this shell runs unchanged on labwc, niri, sway,
Hyprland and KWin — and could run on a compositor we write ourselves one day,
with no rewrite.

---

## How to run it

**Nothing here runs on a Mac.** This is a Wayland desktop shell; Wayland does not
exist on macOS. The code is *written* on the Mac and *run* on a Linux bench
machine or VM.

On a Linux box:

```bash
sudo dnf install quickshell niri     # Fedora; see harness/README.md for Bazzite
./harness/run-nested.sh
```

That opens a window containing a small complete desktop, with our bar across the
top of it. Edit a `.qml` file, save, and the bar reloads by itself.

**Why a window and not the real screen?** GNOME's window manager does not
implement `wlr-layer-shell` and has declined to for years, so this shell cannot
be the real bar on a GNOME machine — on any framework. Running a window manager
that *does* implement it, inside a window, is how the whole ecosystem develops
these. Full explanation and troubleshooting: **[`harness/README.md`](harness/README.md)**.

---

## What is in here

| Path | What it is |
|---|---|
| `shell.qml` | The front door. Everything hangs off this file. Deliberately tiny. |
| `theme/` | **Ice** (light) and **Midnight** (dark) as the single source of truth for every colour, size and typeface. No component anywhere contains a hex value. |
| `components/bar/` | The top bar — the first real piece. Aquarius mark, active app name, status cluster (live glyphs + system tray), clock. |
| `components/dock/` | The centred dock: pinned + running apps, hover lift, the centred running dot. `docs/dock.md`. |
| `components/quicksettings/` | The 330px Quick Settings panel and the bar glyphs that open it. `docs/quick-settings.md`. |
| `components/notifications/` | The notification daemon, toasts, and the panel off the clock. `docs/notifications.md`. |
| `components/search/` | The Flow Search palette — apps, math, session actions. `docs/flow-search.md`. |
| `services/` | Shared single-instance state: Focus (do-not-disturb) and the system light/dark preference. |
| `session/` | The experimental Aquarius Session: login entry, launcher, niri + labwc configs, portals. `docs/session.md`. |
| `assets/` | The Aquarius logo, copied from `os-image/branding/`. |
| `harness/` | How to run it on Linux, written for a beginner. |
| `docs/adr/` | Decision records. `0001-framework.md` is why this is built on Quickshell and why the licence is still Apache-2.0. |
| `docs/ROADMAP.md` | P1 (the bar — runs) → P2 (the rest of the shell — five of six run, the session does not) → P3 (services, session polish) → P4. |
| `tests/` | The checks that can run without a Linux machine. |
| `.github/workflows/` | The same checks in CI. **Dormant** — see below. |

---

## Ice: a light desktop, on purpose

The colours come from **Ice**, the light theme in Aquarius Writer, chosen by
Royce on 2026-08-31 as the OS's main identity. **Midnight** is its designed dark
twin.

Almost every Linux desktop leads with dark. AquariusOS leads with light. That is
a brand decision, not an accident, and this shell is Ice-first from its first
commit.

Colour lives in exactly two files — `theme/Ice.qml` and `theme/Midnight.qml` —
and nowhere else. Every role in one has a twin in the other with the same name,
which is what lets a component be written once and be right in both.

---

## Honest status

**It runs — as of 2026-09-01, on the bench PC.** Everything before that date was
written on a Mac and had never been executed.

What that first run proved: the bar draws and tracks the focused window, the
dock draws its six pinned apps and puts a running dot under an open one, Quick
Settings reads the real machine, Flow Search does sums and finds applications,
and the shell really is the machine's notification daemon. The theme follows the
system's light/dark setting, and saving a `.qml` file reloads the shell in about
a second.

What it does not prove: **that any of it responds to being used.** Opening a
panel is not clicking things in it. Launching from a search result, pressing a
notification's action, dragging a dock tile, toggling Wi-Fi — none of that has
been done. And the real login session has still never been booted; all of the
above was the nested harness.

The record, including the five bugs that run found and what is still untested,
is **[`docs/first-run-on-hardware.md`](docs/first-run-on-hardware.md)**. Read it
before trusting a tick anywhere else.

One thing worth taking from it: all four failures that stopped the shell loading
had passed `tests/test-shell.sh` first. Those checks read the files; they do not
run them. They are the cheap gate, and they stay useful — but the bench lists at
the end of each `docs/*.md` are the real one.

**Also true, and easy to lose track of:**

- This is **not** in the OS image. Nothing in `os-image/` references it.
- The whole P2 layer — dock, Quick Settings, notifications, search, the
  session — was written in one day by five parallel tracks and merged the same
  day. Each component's doc ends with its own unproven list; read it before
  trusting the component.
- Quickshell, which runs this, is pre-1.0 alpha software and says so. Breaking
  changes are promised, with migration notes. See ADR 0001.

---

## CI is dormant, and that is deliberate

`.github/workflows/lint.yml` runs the QML checks on a Fedora container. It does
nothing today, because **this repository has no GitHub remote** — it is local
only, on Royce's machine, until he says otherwise. The workflow is written now so
that pushing a remote later is a one-step action rather than a small project.

Run the same checks by hand, on any machine including the Mac:

```bash
./tests/test-shell.sh
```

---

## Licence

**Apache-2.0**, matching `os-image/` and the rest of the project.

Quickshell — the program that runs these files — is LGPL-3.0. That does not reach
our code: we ship text files that its unmodified, distro-packaged binary reads at
runtime. The full reasoning, and the two small obligations it does create, are
written out in [`docs/adr/0001-framework.md`](docs/adr/0001-framework.md).
