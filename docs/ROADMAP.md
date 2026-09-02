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
- Is 30px right on a real screen, or is that an artboard number?
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
sixth, the login session, has still never been booted. The full record of what
that run proved and what it did not is
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
- [x] **The experimental Aquarius Session** — written, has never booted.
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

  **Still outstanding, and it is the bigger half: the real session has never
  been booted.** Also untested: dragging a dock tile, the Focus timer expiring,
  launching a pinned dock app, and the destructive session actions (deliberately
  never triggered on Royce's own machine).

**Gate (verbatim from the plan):** *OBS records, Steam desktop works, a full
workday survives on the bench.*

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
