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

## Phase P2 — the rest of the shell, and a session that boots · **current**

Months 2–4 in the plan's estimate. **All six pieces WRITTEN 2026-08-31** (five
parallel tracks, merged the same day) — written, not proven: nothing below has
been executed by a QML engine. Each component's doc ends with its own unproven
list and bench steps.

- [x] **Dock** — centred, per the V2 design. Pinned apps plus running ones, off
  `ToplevelManager` and `DesktopEntries`. The centred running dot the KDE fork
  couldn't draw. Pinned list in `~/.config/aquarius-shell/dock.json`, watched
  live. `docs/dock.md`.
- [x] **Quick Settings** — the 330px panel: Wi-Fi, Bluetooth, Focus, adaptive
  4th tile, sound + brightness, battery. Build finding: Quickshell v0.3.0 HAS
  a NetworkManager service (`Quickshell.Networking`) — no `nmcli`; but Fedora
  may still package 0.2.1, so Wi-Fi sits behind a `Loader`. No brightness
  service exists anywhere — `brightnessctl` via `Process`, fenced as the
  documented interim. `docs/quick-settings.md`.
- [x] **Notifications** — the shell IS the freedesktop notification daemon
  (`NotificationServer`), with toasts, the 350px stacked-by-app panel off the
  clock, inline actions and reply, and Focus-until-morning (deadline, auto-off
  timer, persisted across restarts). Critical urgency breaks through Focus.
  `docs/notifications.md`.
- [x] **Flow Search palette** — one box; apps, math, session actions (honest
  scope — no faked file/web search). Summoned by
  `qs ipc -c aquarius-shell call search toggle`; there is NO portable
  global-shortcut path in Quickshell today (its `GlobalShortcut` is
  Hyprland-only), so the compositor binds the key. `docs/flow-search.md`.
- [x] **The status cluster** — real: live network/sound/battery glyphs, the
  system tray (StatusNotifierItem), click opens Quick Settings.
- [x] **The experimental Aquarius Session** — written, has never booted:
  session entry + loud-failure launcher + configs for BOTH candidate
  compositors. Build finding that feeds the compositor gate: the plan's
  `-gtk`+`-wlr` portal mix is right for labwc but wrong for niri, which needs
  the GNOME portal for capture — per-compositor portals.conf, selected by
  `XDG_CURRENT_DESKTOP`. Beginner walkthrough: `docs/session.md`.
- [x] **Theme follows the system** — `Theme.dark` is now a binding on the
  appearance portal via `services/SystemAppearance.qml` (`gdbus` under
  `Process`; Quickshell has no portal module), falling back to Ice-light.
- [ ] **Run it.** The bench boots the nested harness first, then the real
  session, and works through the five docs' bench lists. Until then P2 is
  written, not proven — same honest state P1's bar is in.

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
