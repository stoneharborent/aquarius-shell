# ADR 0001 — What we build the Aquarius Shell on

- **Status:** Accepted
- **Date:** 2026-08-31
- **Decision:** **Quickshell.** The shell is a Quickshell configuration. The repo
  stays **Apache-2.0**.
- **Phase:** P1 of the Aquarius Desktop track (Track 2 — PROTOTYPE).

> **Plain-language summary, if you read nothing else.** We are writing the
> desktop's bar, dock and panels in QML — a small, readable UI language. Two
> things could run that QML: **Quickshell**, a purpose-built program for exactly
> this that already handles the tray, the battery, the audio and the windows for
> us; or **LayerShellQt**, a small library that only knows how to pin a window to
> the edge of a screen and leaves everything else to us. We picked Quickshell,
> because it is packaged in Fedora, three other people's desktops already ship on
> it, and it would save us roughly a year of writing the boring parts. Its
> licence does not touch our code: our files stay Apache-2.0 and we just ship
> Fedora's unmodified Quickshell alongside them.

---

## Context

The custom-DE plan (`docs/custom-de/PLAN.md`, 2026-08-31) chose Path 4: build the
**shell** — bar, dock, overlays, search, notifications — as one coherent QML
application riding a compositor somebody else maintains, and speak **only
standardised Wayland protocols** so it runs anywhere. It named the first
engineering decision of the track explicitly:

> **Phase P1:** scaffold `aquarius-shell`; pick Quickshell vs LayerShellQt.

Two constraints frame that choice.

**1. The standardised-protocols law.** Every team that built a shell against a
private compositor seam ended up forking that compositor and later fleeing the
fork. Whatever we pick has to reach layer-shell, session lock, StatusNotifierItem
(the tray), foreign-toplevel (which window is focused) and the desktop portals
through their published protocols, and nothing else.

**2. The daily driver is now GNOME.** AquariusOS pivoted to a GNOME base on
2026-08-31. **GNOME's compositor, Mutter, does not implement wlr-layer-shell** —
this is long-standing and deliberate upstream ([mutter#973](https://gitlab.gnome.org/GNOME/mutter/-/issues/973),
[gnome-shell#1141](https://gitlab.gnome.org/GNOME/gnome-shell/-/issues/1141)).
So this shell **cannot** run as panels inside the GNOME session, on any
framework. That is not a mark against either option; it changes only how we
*test*, and the answer is a nested compositor (see `harness/`). It does mean
neither framework gets credit for "GNOME integration", because there isn't any to
be had.

## Options considered

### Option A — Quickshell

A toolkit whose entire purpose is building desktop shells out of QtQuick/QML. You
write QML; the `qs` binary runs it.

What I verified, with sources:

| Claim | Verified | Source |
|---|---|---|
| Layer-shell windows, spelled portably | `PanelWindow` — "decorationless window attached to screen edges by anchors", with `anchors`, `margins`, `exclusiveZone`, `exclusionMode`, `focusable`, `aboveWindows`. Becomes `zwlr_layer_shell_v1` on Wayland via `WlrLayershell` | [PanelWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/) |
| Which window is focused, portably | `ToplevelManager` singleton: `toplevels`, `activeToplevel`. Explicitly built on **zwlr-foreign-toplevel-management-v1**. `Toplevel` gives `appId`, `title`, `activated`, `activate()`, `close()` | [ToplevelManager](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/ToplevelManager/), [Toplevel](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/Toplevel/) |
| System tray | `Quickshell.Services.SystemTray` — `SystemTray`, `SystemTrayItem` (StatusNotifierItem), plus `Quickshell.DBusMenu` for their menus | Module index, quickshell.org/docs/v0.3.1/types/ |
| Audio | `Quickshell.Services.Pipewire` — `Pipewire`, `PwNode`, `PwNodeAudio`, `PwLink`, peak monitoring | same |
| Media players | `Quickshell.Services.Mpris` — `Mpris`, `MprisPlayer` | same |
| Notifications | `Quickshell.Services.Notifications` — a full `NotificationServer` | same |
| Battery / power | `Quickshell.Services.UPower` — `UPower`, `UPowerDevice`, `PowerProfiles` | same |
| Bluetooth | `Quickshell.Bluetooth` — `Bluetooth`, `BluetoothAdapter`, `BluetoothDevice` | same |
| Lock screen | `Quickshell.Wayland` — `WlSessionLock`, `WlSessionLockSurface` (ext-session-lock) | same |
| Login greeter | `Quickshell.Services.Greetd` | same |
| Authentication | `Quickshell.Services.Pam`; **Polkit agents** added in v0.3.0 | same, [changelog](https://quickshell.org/changelog/) |
| App index | `DesktopEntries` / `DesktopEntry` — reads installed `.desktop` files, `byId()` and `heuristicLookup()` | [DesktopEntries](https://quickshell.org/docs/v0.3.1/types/Quickshell/DesktopEntries/) |
| Clock without a `date` subprocess | `SystemClock`, with hour/minute/second precision to save battery | [SystemClock](https://quickshell.org/docs/v0.3.1/types/Quickshell/SystemClock/) |
| Compositor-specific extras, cleanly separated | `Quickshell.Hyprland` and `Quickshell.I3` exist as **optional** modules — the portable core does not depend on them | Module index |
| Reload on save | "Quickshell live-reloads your code. You can leave it open and edit the original file. The panel will reload when you save it." | [Introduction guide](https://quickshell.org/docs/v0.3.1/guide/introduction/) |
| Fedora packaging | **Official Fedora package.** `quickshell` 0.2.1 snapshot builds in Rawhide, F45, F44. Docs say "Release versions of Quickshell are available in Fedora Rawhide as `quickshell`". Also a COPR (`errornointernet/quickshell`, with a `-git` variant), Arch `extra` (0.3.1), Debian unstable/testing, Nixpkgs, OBS, an Ubuntu PPA | [Fedora packages](https://packages.fedoraproject.org/pkgs/quickshell/quickshell/), [install guide](https://quickshell.org/docs/v0.3.1/guide/install-setup/) |
| Other people ship real desktops on it | **DankMaterialShell** (~7.8k stars, "optimized for niri, hyprland, sway, MangoWC, labwc, MiracleWM"), **Caelestia**, **Noctalia**. niri's own README tells new users to "grab a desktop shell like DankMaterialShell or Noctalia" | [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), [Caelestia](https://github.com/caelestia-dots/shell), [niri](https://github.com/niri-wm/niri) |
| Maturity, honestly | **Alpha.** Install guide: "Quickshell is still in a somewhat early stage of development. There will be breaking changes before 1.0, however a migration guide will be provided." v0.3.0 shipped one breaking change (config path canonicalisation) with a written migration note; v0.3.1 is a pure bug-fix release, and it is a long list of crash fixes | [install guide](https://quickshell.org/docs/v0.3.1/guide/install-setup/), [changelog](https://quickshell.org/changelog/) |
| Licence | **LGPL-3.0.** Upstream README: "Licensed under the GNU LGPL 3." The GitHub mirror lists LGPL-3.0 **and** GPL-3.0, which is simply how LGPLv3 is always shipped (LGPLv3 is a set of additional permissions written on top of GPLv3, so both texts travel together). Fedora's package metadata records `LGPL-3.0-or-later AND BSD-3-Clause AND HPND-sell-variant` — the extra two cover vendored third-party pieces inside the binary, not the toolkit's own terms | [README](https://git.outfoxxed.me/quickshell/quickshell), [mirror](https://github.com/quickshell-mirror/quickshell), [Fedora packages](https://packages.fedoraproject.org/pkgs/quickshell/quickshell/) |

### Option B — LayerShellQt, and hand-roll the rest

KDE's `layer-shell-qt` is a small Qt library. Its README describes the whole of
it: call `LayerShellQt::Shell::useLayerShell()` before creating windows, then use
`LayerShellQt::Window` to set that surface's layer-shell properties. It is
C++-only, works on `QWindow` (so QWidget users have to dig the QWindow out), and
it does exactly one thing: **anchor a window to a screen edge.**
([README](https://github.com/KDE/layer-shell-qt/blob/master/README.md),
[repo](https://invent.kde.org/plasma/layer-shell-qt))

Everything else in the "verified" table above would be ours to write, in C++,
and then expose to QML by hand:

- a StatusNotifierItem host and a DBusMenu client (the tray — this alone is a
  notorious multi-week job with a long tail of misbehaving apps),
- a `org.freedesktop.Notifications` server,
- PipeWire, UPower, BlueZ and NetworkManager D-Bus clients,
- a `zwlr_foreign_toplevel_manager_v1` client for "which app is focused",
- `ext-session-lock` plumbing for the lock screen,
- a `.desktop` file index,
- a build system, a packaging story, and a reload-on-save development loop.

It also means the project acquires a C++ build — meson/CMake, a compile step, a
CI toolchain, and an RPM to maintain — where Quickshell means the project ships
**text files** that an already-packaged binary reads.

### Option C — a third path we did not take

Noctalia reportedly rewrote its rendering layer in C++ for v5 and moved off
Qt/Quickshell (secondary source: [tux.fan, 2026-07](https://tux.fan/2026/07/14/noctalia-wayland-desktop-shell-2026/) —
recorded as a signal, not verified against the project's own release notes). The
lesson taken from it is not "avoid Quickshell". It is that a QML shell's exit
route is a rewrite of the *rendering* layer with the *design and behaviour*
preserved — which is exactly the position `theme/` and `components/` are arranged
to leave us in.

## Decision

**Quickshell.**

The reasoning in one line: Quickshell already provides, as tested and packaged
software, roughly the entire "Services" layer that the custom-DE plan calls *"the
forgotten 70% — this is what separates a rice from a DE"*, and every piece of it
is spoken through a standardised protocol. LayerShellQt provides the one part of
that list which was never the hard part.

Secondary reasons:

1. **It is in Fedora proper.** AquariusOS is built on Bazzite, which is Fedora
   Atomic. A `dnf install quickshell` line in a Containerfile with no third-party
   repository is worth a great deal — it means the OS image does not grow a COPR
   dependency to keep the shell alive.
2. **The dev loop already exists.** Save the file, the bar reloads. Building that
   for a C++ shell is real work, and without it every iteration costs a rebuild.
3. **Three independent desktops are the proof.** DankMaterialShell, Caelestia and
   Noctalia are not demos; niri's own documentation points new users at two of
   them. The pattern the plan bet on is a pattern other people are already
   living in.
4. **It does not lock us to a compositor.** The Hyprland and i3 integrations are
   separate optional modules. Our shell imports `Quickshell`,
   `Quickshell.Wayland` and `QtQuick`, and nothing compositor-specific. That is
   checked by `tests/test-shell.sh`, not left to good intentions.

## Licence consequences (this is the part that needed checking)

**Question:** Quickshell is LGPL-3.0. AquariusOS repos are Apache-2.0. Does using
it force the shell — or the OS image — to change licence?

**Answer: no, on two independent grounds. The repo stays Apache-2.0.**

1. **We do not link against it. We are not even a plugin.** Our deliverable is a
   folder of `.qml` and `qmldir` text files. The `qs` binary reads them at
   runtime the way `python` reads a `.py` file or `bash` reads a `.sh` file.
   Running a program does not place conditions on the input you feed it — the
   LGPL, like the GPL, governs copying, modifying and distributing *the library*,
   not the works an interpreter processes. Nothing of Quickshell's source is
   copied into or compiled into our files.
2. **Even treating it as linking, the LGPL is satisfied.** The LGPL's whole point
   is that a work which *uses* the library may be under any terms, provided the
   user can replace the library with their own version. We ship the **unmodified
   Fedora RPM**, installed by the package manager, in a normal system library
   path. A user can `rpm -e` it and drop in their own build; Fedora publishes the
   corresponding source for every binary it ships. That is the LGPL's relinking
   requirement met by ordinary distribution mechanics, before we do anything.

**Two obligations we do take on, and they are small:**

- **If we ever patch Quickshell itself**, those patches are LGPL-3.0 and must be
  published. Standing rule for this repo: **we do not carry a Quickshell fork.**
  Something missing upstream gets contributed upstream or worked around in QML.
- **The OS image redistributes an LGPL binary**, so it must carry the licence
  text and an offer of source. It already does this for the thousands of GPL
  packages Bazzite inherits; Quickshell adds nothing new to that machinery.

**Therefore:** `LICENSE` in this repo is Apache-2.0, matching `os-image/` and the
project norm. No file in this repo is derived from Quickshell.

*(Not legal advice. It is a good-faith reading of LGPL-3.0 against how this
software is actually assembled, written down so the next person does not have to
re-derive it. If AquariusOS is ever commercially distributed under a contract
with licence warranties, have a lawyer confirm it.)*

## Consequences

**Good**

- P1 is a bar in a few hundred lines of QML with no build step.
- P2's dock, Quick Settings, notifications and search each start from a service
  that already exists rather than from a D-Bus specification.
- The shell runs on any compositor implementing the standard set — labwc, niri,
  sway, Hyprland, KWin. That is the plan's whole hedge, kept intact.
- Wave-2's Plasma widget work ports: the QML internals move, only the packaging
  wrapper differs.

**Bad, and accepted**

- **Alpha software, pre-1.0, breaking changes promised.** Mitigation: pin to a
  released version in the OS image (never `-git`), read the changelog before
  bumping, and keep every Quickshell-specific call inside `components/` so the
  blast radius of an API change is small. `theme/` imports Quickshell for one
  thing only — the `Singleton` type.
- **A dependency on one small project.** The exit is a rewrite of the runtime
  with the design intact, which is why `theme/` holds no logic and `components/`
  holds no colours.
- **The shell cannot be demoed inside the GNOME daily driver.** Mutter, not
  Quickshell. Every option had this. The answer is `harness/run-nested.sh`.
- **Qt 6 in the image.** A GNOME-based AquariusOS is otherwise mostly GTK, so
  Quickshell pulls in Qt 6 QML runtime packages. Measure the image-size cost
  before P2 ships anything to a real image.

## What this decision does not settle

- **Which compositor the eventual "Aquarius Session" runs on.** labwc (boring,
  Budgie-proven) and niri (scrollable strip) are both still open; P2's gate
  decides. Both are in Fedora proper (`labwc`; `niri` 26.04 in F43/44/45), and
  both speak the protocols this shell needs.
- **Whether the shell ever replaces the GNOME session.** Not a P1 question. The
  standing rule from the plan holds: never burn the boats.
- **Accent colour and light/dark defaults.** `theme/` ships Ice-first with
  Aquarius Blue; that follows Royce's 2026-08-31 call and is a design decision,
  not this ADR's.
