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

## Phase P1 — the bar · **current**

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
- [ ] **Run it.** Nothing in this list above has been executed by a QML engine.
      Until the harness runs on the bench, P1 is written, not proven.

**Gate (verbatim from the plan):** *does it feel better than the themed panel?*

Practically, that means standing the Ice bar next to the shipped one and
answering honestly. Sub-questions worth writing down when the bench run happens:

- Does the light bar read cleanly against real wallpapers, or does it wash out?
- Is 30px right on a real screen, or is that an artboard number?
- Does the active-app name change fast enough to feel connected to the window?
- Does the bar survive plugging a monitor in and out?

**If the gate fails**, the answer is not "keep building" — it is back to the
design project with what was learned.

---

## Phase P2 — the rest of the shell, and a session that boots

Months 2–4 in the plan's estimate.

- **Dock** — centred, per the V2 design. Pinned apps plus running ones, off
  `ToplevelManager` and `DesktopEntries`.
- **Quick Settings** — the tray panel: Wi-Fi, Bluetooth, Focus, Game Mode, sound
  and brightness. On `Quickshell.Services.{UPower,Pipewire}` and
  `Quickshell.Bluetooth`; NetworkManager over D-Bus.
- **Notifications** — a real `NotificationServer`, GNOME 48/49's stacked-by-app
  model with inline actions.
- **Flow Search palette** — one search box with all the command syntax hidden.
- **The status cluster** — the placeholder slots in `components/bar/` become
  real, tray included (`Quickshell.Services.SystemTray`, StatusNotifierItem).
- **The experimental Aquarius Session** boots on the bench: an inherited
  compositor (labwc or niri — undecided, see ADR 0001) with this shell and the
  portals configured (`portals.conf` mixing `-gtk` and `-wlr`).
- **Theme follows the system** — `Theme.dark` stops being a stored value and
  becomes a binding to the freedesktop appearance portal.

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
- The Bazzite session-select patch (its Game↔Desktop switching hardcodes
  `plasma.desktop`, so a new session needs a small permanent patch, re-verified
  each Bazzite update).
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
