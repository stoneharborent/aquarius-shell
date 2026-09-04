# Aquarius Shell — roadmap

*This is the roadmap for **the shell**. The roadmap for the whole operating
system is one level up, at `../../ROADMAP.md`. The strategy this plan came out of
is the custom-DE plan (`docs/custom-de/PLAN.md` on the `research/custom-de`
branch of `os-image`) — read that first if you want the "why".*

**Where this sits in the bigger picture.** AquariusOS has two tracks running side
by side:

- **Track 1 — SHIP.** The real operating system people install: Bazzite +
  GNOME, themed. That is the daily driver and it keeps shipping.
- **Track 2 — PROTOTYPE.** This repo. The beginning of a fully custom desktop,
  built as one QML application on top of a compositor somebody else maintains.
  It is not anybody's daily driver and will not be until it earns it.

**The standing rule, from the plan, that never changes:** *every phase ships
behind a fallback session; no burn-the-boats moments.*

---

## Phase P1 — the bar

Scaffold the repo, pick the framework, and ship **one real piece**: the Ice top
bar.

- [x] Repo scaffolded, `git init`, local only — no remote until Royce says.
- [x] Framework decided and written up: `docs/adr/0001-framework.md` (Quickshell).
- [x] `theme/` — Ice and Midnight as QML singletons, one source of truth for
      colour, spacing, type and motion.
- [x] `components/bar/` — the top bar: Aquarius mark, active app name, spacer,
      placeholder status cluster, clock.
- [x] `shell.qml` — the entry point, wiring the bar as a top-anchored layer-shell
      panel.
- [x] `harness/` — run it in a nested compositor window on any Linux box.
- [x] `tests/` + `.github/workflows/lint.yml` — the first automated QML checking
      this project has ever had.
- [x] **Run it.** Done 2026-09-01 on the bench PC. The bar draws, the active app
      name tracks the focused window, the theme follows the system's dark
      setting, and the file-watching reload loop works. Four load failures and
      one silent layout bug were found and fixed — the full record, including
      what is still unproven, is **[`first-run-on-hardware.md`](first-run-on-hardware.md)**.

**Gate (verbatim from the plan):** *does it feel better than the themed panel?*

**PASSED — 2026-09-01, Royce, at the machine: "the bar does feel better."**
P1's gate is closed. He also confirmed the widgets and notifications worked and
that the Aquarius mark opens the search palette, and answered the three open
questions the first run raised: the bar's Drop/Search placeholders stay as they
are for now, the fuzzy search breadth is right, and the Quick Settings text
truncation is fine as it is.

The sub-questions below were written before the bar existed; they are kept as
the record of what the gate was asking.
One thing the first run already settled: the bar comes up **Midnight, not Ice**,
because it follows the system setting and the bench machine is set to dark. The
gate's phrase "the light bar" needs re-reading with that in mind.

Practically, that means standing the Aquarius bar next to the shipped one and
answering honestly. Sub-questions worth writing down when it is judged:

- Does the light bar read cleanly against real wallpapers, or does it wash out?
- ~~Is 30px right on a real screen, or is that an artboard number?~~ Answered
  2026-09-03: it was an artboard number, and the bar is 38 now. See "the base
  sizes read small" below.
- Does the active-app name change fast enough to feel connected to the window?
- Does the bar survive plugging a monitor in and out?

**If the gate fails**, the answer is not "keep building" — it is back to the
design project with what was learned.

---

## Phase P2 — the rest of the shell, and a session that boots · **current**

Months 2–4 in the plan's estimate. **All six pieces WRITTEN 2026-08-31** (five
parallel tracks, merged the same day).

**FIVE OF THE SIX NOW RUN — 2026-09-01, on the bench PC.** The dock, Quick
Settings, notifications, Flow Search and the status cluster were all executed by
a QML engine, drew on screen, and read real data from the real machine. The
sixth, the login session, **booted on 2026-09-02 — and the shell did not start
inside it**, because the layered Quickshell cannot run on this image at all
(`docs/session.md` § *The Qt ABI trap*). The full record of what
those runs proved and what they did not is
**[`first-run-on-hardware.md`](first-run-on-hardware.md)** — read it before
trusting any tick below, because "runs" is not "finished": what was checked was
that each piece draws and shows true information, not that every interaction
inside it works. Each component's doc still ends with its own unproven list.

- [x] **Dock** — centred, per the V2 design. **RUNS 2026-09-01**: draws the six
  pinned apps with real artwork, and opening an app added a tile with the
  running dot underneath it. Pinned apps plus running ones, off
  `ToplevelManager` and `DesktopEntries`. The centred running dot the KDE fork
  couldn't draw. Pinned list in `~/.config/aquarius-shell/dock.json`, watched
  live. `docs/dock.md`.
- [x] **Quick Settings** — **RUNS 2026-09-01**, reading the real machine:
  Bluetooth naming the connected MX Vertical, Performance *Balanced*, sound at
  the system's true 38%. The Wi-Fi tile read *No adapter* that day, and **that
  reading was a bug, found and fixed 2026-09-01 (`bf23870`)**: the bench PC has
  a wireless adapter (`wlp7s0`); the tile's subtitle threw a `ReferenceError`
  the moment the adapter appeared and froze on its start-up text. The 330px
  panel: Wi-Fi, Bluetooth, Focus, adaptive 4th tile, sound + brightness,
  battery. Build finding, corrected: Fedora's `quickshell` is a **0.2.1 git
  snapshot that already ships `Quickshell.Networking`**, under older enum names
  (`DeviceConnectionState`, not 0.3.x's `ConnectionState`); the tile now
  resolves whichever exists. No brightness service exists anywhere —
  `brightnessctl` via `Process`, fenced as the documented interim.
  `docs/quick-settings.md`.
- [x] **Notifications** — **PROVEN END TO END 2026-09-01**: notify-send in, toast
  out, grouped by application in the panel. (Testing it needs a private message
  bus — GNOME owns the notification service otherwise; `AQ_PRIVATE_BUS=1`.)
  The shell IS the freedesktop notification daemon
  (`NotificationServer`), with toasts, the 350px stacked-by-app panel off the
  clock, inline actions and reply, and Focus-until-morning (deadline, auto-off
  timer, persisted across restarts). Critical urgency breaks through Focus.
  `docs/notifications.md`.
- [x] **Flow Search palette** — **RUNS 2026-09-01**: `12.5 * 8` gives 100 with
  *press Enter to copy*, and letters find real applications with real icons.
  One box; apps, math, session actions (honest
  scope — no faked file/web search). Summoned by
  `qs ipc call search toggle` (instance chosen by `QS_CONFIG_PATH`); there is NO portable
  global-shortcut path in Quickshell today (its `GlobalShortcut` is
  Hyprland-only), so the compositor binds the key. `docs/flow-search.md`.
- [x] **The status cluster** — **RUNS 2026-09-01**, and the run found two things:
  every tray icon was rendering as an empty box (a Row broken by an anchored
  child), and the bar wore a crossed-out Wi-Fi mark that was read at the time
  as "on a machine with no wireless adapter" — the machine has one, disconnected
  (see Quick Settings above). Both fixed. Real: live network/sound/battery glyphs, the
  system tray (StatusNotifierItem), click opens Quick Settings.
- [~] **The experimental Aquarius Session** — **IT BOOTS. THE SHELL DID NOT
  START. 2026-09-02, bench PC.** Be precise about the halves: GDM listed the
  session from `/usr/local/share/wayland-sessions` (the one assumption the whole
  no-image-changes story rested on — proven), the installer had put all five
  pieces in place, the launcher ran, and niri 26.04 came up with our config on a
  4K output and stayed up eighteen minutes. **No bar**, and the session log held
  only niri's output.
  The cause was not the session: the layered `quickshell` cannot start at all on
  this image — `qs: symbol lookup error: ... undefined symbol ... version Qt_6`.
  Fedora rebuilt quickshell (`-5.fc44`) against qt6-qtbase **6.11.2**; the image
  has **6.11.1**, and `rpm-ostree` cannot change the Qt underneath a layer. So a
  layered Quickshell only ever works by coincidence. Fixes: layer the matching
  `-3.fc44` build from Koji (a patch), or **bake quickshell into the OS image**
  (the answer) — `docs/session.md` § *The Qt ABI trap*.
  Two of our own blind spots hid it for eighteen minutes and are now fixed: the
  pre-flight only ran `command -v qs` (it now runs `qs --version` and dies loudly
  with the real error), and the compositor gave the shell `/dev/null` for its
  output (measured on niri 26.04) so nothing it printed reached the log — both
  compositor configs now append the shell's output to the session log, prefixed
  `[shell]`. `tests/test-shell.sh` section 29 guards both.
  Still unproven: everything the shell does in a real session.
  **Pre-flight 2026-09-01** on the bench PC (which runs AquariusOS itself,
  build 44.20260901): `/usr/local` is writable, the niri config validates, both
  portal back ends are already in the image, and two things were wrong — the
  login screen is **GDM, not SDDM**, and the Super + Space binding named a
  non-existent IPC target. Both corrected in `docs/session.md`; what remains
  needs a person at the login screen.
  Session entry + loud-failure launcher + configs for BOTH candidate
  compositors. Build finding that feeds the compositor gate: the plan's
  `-gtk`+`-wlr` portal mix is right for labwc but wrong for niri, which needs
  the GNOME portal for capture — per-compositor portals.conf, selected by
  `XDG_CURRENT_DESKTOP`. Beginner walkthrough: `docs/session.md`.
  **Two fixes from the Aquarius Keys work, 2026-09-03** (found while building the
  OS's keyboard-mode feature, both in `session/labwc/`):
  *(1)* labwc switched windows on Alt + Tab only, so in Aquarius Keys' **Mac
  mode** — where Command is mapped to Super — Command + Tab did nothing here
  while GNOME handled it fine. `W-Tab`/`W-S-Tab` now bind labwc's own
  `NextWindow`/`PreviousWindow`; Alt + Tab is unchanged.
  *(2)* the autostart file now runs `dbus-update-activation-environment
  --systemd --all` before starting `labwc-session.target`, so services started
  on demand inherit `WAYLAND_DISPLAY` and `XDG_CURRENT_DESKTOP` instead of each
  having to work the desktop out for itself. niri gets this from `--session`;
  labwc had no equivalent. Both written up in `docs/session.md`.
- [x] **Theme follows the system** — **PROVEN 2026-09-01**: the bench machine is
  set to dark and the shell came up Midnight. `Theme.dark` is now a binding on the
  appearance portal via `services/SystemAppearance.qml` (`gdbus` under
  `Process`; Quickshell has no portal module), falling back to Ice-light.
- [~] **Run it.** *2026-09-01. Drawing and behaviour both done in the harness;
  the session is not.* Five of the six pieces drew and read real data, and a
  second pass the same day drove them: search launches apps and copies sums,
  the arrow keys move a selection that is now actually drawn, the dock cycles
  windows, Focus toggles and persists, the sound slider reads and writes, and
  notification action buttons, inline reply and Clear all all work — inline
  reply verified on the bus. Full record, including the three defects left open
  for a decision: [`first-run-on-hardware.md`](first-run-on-hardware.md).

  **Still outstanding, and it is the bigger half: the real session BOOTS
  (2026-09-02) but the shell has never drawn inside it** — the layered
  Quickshell cannot start on this image (see the session entry above). Also untested: dragging a dock tile, the Focus timer expiring,
  launching a pinned dock app, and the destructive session actions (deliberately
  never triggered on Royce's own machine).

**Gate (verbatim from the plan):** *OBS records, Steam desktop works, a full
workday survives on the bench.*

### Settled — the base sizes read small on a real monitor (2026-09-03)

**Raised and answered by Royce on the bench the same day, 2026-09-03.** The
shell ran on the 55" 4K Odyssey Ark and the whole design read too small:
*"really small icons… will need to size everything up."*

Two separate things were behind that, and both are now fixed:

1. **The screen was at 100%.** The Aquarius Session set no output scale at all,
   while GNOME on the same machine had been running the monitor at 125% for
   weeks. Fixed in the os-image repository (`aquarius-display-scale`, which
   reads that GNOME setting and applies it). Nothing in this repository needed
   to change for it.

2. **Our own base sizes were simply too small for a desktop monitor.** A 30px
   bar and a 12px caption were measured off the V2 artboards, which were drawn
   for a page rather than for a 55" screen at arm's length. Whether they were
   right was a judgement about how the desktop should FEEL, and that judgement
   was Royce's to make. He made it — see below — and the tokens moved.

So `theme/Theme.qml` now has one knob — `AQ_UI_SCALE` — that multiplies every
size, gap, corner and font size in the design at once:

```
AQ_UI_SCALE=1.25 qs -p .          # try it here
aq display ui 1.25                # set it on AquariusOS, then log back in
```

That knob was a way of ASKING the question, not an answer to it. Royce answered
it the same day, on the Ark, with the session at output scale 1.25:

> **1.25 reads right for the whole shell, except the dock, which should be the
> size it has at 1.5.**

**So the tokens moved, and the knob went back to 1.0.** Every size token in
`theme/Theme.qml` is now 1.25x the original 2026-08 artboard number, and the
whole `THE DOCK` block is 1.5x. The rounding is the same rounding `px()` would
have done, so what ships at 1.0 is pixel-for-pixel what he approved on the
bench. `AQ_UI_SCALE` still works and still defaults to 1.0 — it now means what a
knob should mean, "bigger or smaller than the design", rather than "the design,
plus the correction we already know it needs".

| | artboard (2026-08) | ships (2026-09-03) |
|---|---|---|
| bar height | 30 | **38** |
| dock tile | 44 | **66** |
| body text | 15 | **19** |
| caption (the bar's text) | 12 | **15** |
| spacing unit (`sp1`) | 4 | **5** |

The dock being out of step is the point, not drift: the bar and the panels are
*read*, and text has its own legible size; the dock is *aimed at*, and a pointer
target across a big desk wants to be bigger than the type beside it.

Two checks keep it honest. `tests/test-shell.sh` section 30 keeps the knob
total — every numeric size token in `Theme.qml` is written `root.px(N)`, and a
bare number fails the build. Section 31 keeps the dock's relationship to the bar
inside a band, so a later reasonable-sounding "the bar is a touch tall" cannot
quietly shrink the dock along with it.

**Still to see on the bench:** the shell has never actually drawn inside the
real session (see the P2 entry above), so these sizes have been judged through
the nested harness and the knob, not in the session Royce logs into. First look
confirms them or reopens this.

---

## Phase P3 — services and session polish

Months 4–9 in the plan's estimate. This is the unglamorous 70% that separates a
desktop environment from a nice-looking configuration.

- Settings surfaces in plain language, backed by NetworkManager / BlueZ / UPower
  directly.
- Session polish: lock and idle (`WlSessionLock`), autostart, polkit agent,
  keyring.
- On-screen keyboard for handheld.
- The Bazzite session-select patch. (Corrected by the P2 session track: both
  `os-session-select` and `bazzite-autologin` branch on `base-image-name` and
  hardcode `plasma.desktop` OR `gnome.desktop` — on our GNOME bases the value
  in the way is `gnome.desktop`. Same small permanent patch, different lines;
  see docs/session.md § "when this ships in the image".)
- Flatpak theme extensions so third-party apps do not look foreign.

**Gate (verbatim from the plan):** *a fresh install where a stranger never needs
the fallback.*

---

## Phase P4 — later, and only if P3's gate passed

- Consider making the Aquarius Session the default per variant.
- Consider the scrollable handheld mode.
- Consider — **only then** — our own compositor underneath the stable shell.
  This is the Treeland sequence run in the safe order: shell first, compositor
  last.

---

## Rules that outlive any phase

1. **Standardised protocols only.** layer-shell, ext-session-lock,
   StatusNotifierItem, foreign-toplevel, the portals. Never a private seam into
   KWin or Mutter. Every project that took the shortcut ended up maintaining
   somebody else's window manager.
2. **One source of truth for design.** Colour, spacing and type live in
   `theme/`. A component containing a hex value is a bug.
3. **No fork of Quickshell.** Missing upstream features get contributed upstream
   or worked around in QML. See ADR 0001's licence section for why this matters.
4. **Honesty in the docs.** If something has not been run, the docs say it has
   not been run.
