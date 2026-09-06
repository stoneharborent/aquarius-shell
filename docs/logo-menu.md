# The Aquarius menu (and the desktop right-click menu)

*Added in R6, 2026-09-06. Two menus arrived together: the shell-drawn dropdown
off the Aquarius mark, and the labwc right-click menu on the empty desktop.*

**Not proven on hardware.** Everything below is written and passes
`tests/test-shell.sh`; none of it has been run on the bench yet. The
[On the bench](#on-the-bench) list is what settles it.

> **Bench fix, 2026-09-06.** The first run of this menu found *About This PC* and
> *System Settings* doing nothing at all, along with the Quick Settings chevrons
> and the dock's Settings icon. One cause, and it is not in this shell: GNOME's
> Settings app refuses to start unless `XDG_CURRENT_DESKTOP` names GNOME, and an
> Aquarius session deliberately calls itself something else. Every Settings
> launch in the shell now goes through one file,
> `services/SettingsLauncher.qml`, which puts `env XDG_CURRENT_DESKTOP=GNOME` in
> front of the command. See [Opening Settings](#opening-settings) below.

---

## The Aquarius menu — off the mark

Click the Aquarius mark at the top-left of the bar and a small Ice dropdown
opens under it. It is the desktop's equivalent of the Apple menu.

```
┌────────────────────────────┐
│  About This PC             │   Settings, on its About page
│  System Settings          │   Settings
│  Check for Update         │   /usr/libexec/aquarius-updater
├────────────────────────────┤
│  Log Out                  │   loginctl terminate-session $XDG_SESSION_ID
│  Sleep                    │   systemctl suspend
│  Restart                  │   systemctl reboot        (asks twice)
│  Power Off                │   systemctl poweroff      (asks twice)
└────────────────────────────┘
```

- **It is drawn by the shell**, not by the compositor — a `wlr-layer-shell`
  overlay, exactly like the Flow Search palette, so it looks like the rest of the
  shell and answers the keyboard on any compositor. Up/Down walk the items,
  Enter runs the selected one, Esc closes, a click anywhere outside closes.
- **It takes the keyboard**, so it is an exclusive overlay: opening it closes
  Quick Settings, the search palette and the notifications panel, and they close
  it. `services/Overlays.qml` holds that rule.
- **The two Settings items go through one launcher.** Neither of them names a
  program: both call `SettingsLauncher.open()` — `"system"` for About This PC,
  `""` for System Settings. See [Opening Settings](#opening-settings).
- **Check for Update is guarded.** The menu probes `test -x
  /usr/libexec/aquarius-updater` when it opens; if the updater is not installed
  the item reads *Updates unavailable* and cannot be clicked, so the menu never
  launches something that is not there. The updater window itself is the
  os-image side's to provide.
- **Restart, Power Off and Log Out ask twice.** The first activation arms the
  row (it says *Confirm?*); the second runs it. A session ended by a stray click
  is the one mistake worth guarding against. logind lets the active-session user
  suspend, reboot and power off without a password by default, so no polkit
  prompt is expected.
- **Log Out is not a new teardown.** It runs `loginctl terminate-session
  $XDG_SESSION_ID` — the shell's existing session-action, the same thing the
  Flow Search palette's *Log out* does, ending the session the same way
  `Super+Shift+E` does by another road.

## Opening Settings

*The one thing on this page that is somebody else's bug, and the one place the
shell works around it.*

AquariusOS borrows GNOME's Settings app until it has its own. That app checks
which desktop it was started under and refuses to run under one it does not
recognise. Its own source does the checking — `shell/cc-application.c`,
`is_supported_desktop()`, called from `cc_application_handle_local_options()` —
by reading the `XDG_CURRENT_DESKTOP` environment variable, splitting it on
colons, and looking for `GNOME` or `Unity`. Finding neither, it prints

```
Running gnome-control-center is only supported under GNOME and Unity, exiting
```

and exits 1. Nothing appears on screen, and because the shell launches it
detached, nothing appears in the session log either. That is the whole of the
2026-09-06 bench report: *"System Settings still doesn't open. Nor does its icon
in the dock. About This PC also doesn't work. Quick settings arrows are there but
don't open into settings."*

**Why the session's variable is not simply changed.** The Aquarius session sets
it deliberately:

```
XDG_CURRENT_DESKTOP=aquarius-labwc:aquarius:wlroots     (on labwc)
XDG_CURRENT_DESKTOP=aquarius-niri:aquarius:niri         (on niri)
```

That is the mechanism `xdg-desktop-portal` uses to find
`aquarius-labwc-portals.conf`: it takes each colon-separated name and looks for
`<name>-portals.conf`. Rename it to GNOME and screen recording and file dialogs
break, silently. So the fix is per-launch, which is what sway, labwc and Hyprland
users have done for this program for years:

```bash
env XDG_CURRENT_DESKTOP=GNOME gnome-control-center [panel]
```

**Where that lives.** `services/SettingsLauncher.qml`, a singleton, and nowhere
else. `SettingsLauncher.open(panel)` is called by this menu (`"system"`, `""`),
by the Quick Settings chevrons (`"wifi"`, `"bluetooth"`, `"power"`), and — via
`SettingsLauncher.ownsDesktopEntry(entry)` — by the dock tile and the search
palette, both of which would otherwise run Settings' `.desktop` entry the
ordinary way and get the same silent exit. The desktop right-click menu
(`session/labwc/menu.xml`) is the one place that spells the prefix out by hand,
because labwc draws that menu from XML and cannot call into QML.
`tests/test-shell.sh` **section 34b** fails if any component names
`gnome-control-center` in code again.

**What this does not fix, honestly.** Starting is not working. Some of that app's
panels talk to parts of GNOME that an Aquarius session does not run — Displays
wants Mutter's display configuration, Keyboard shortcuts and Multitasking want
GNOME Shell and gnome-settings-daemon — so on labwc those pages will open empty
or offer settings that change nothing. The pages the shell actually points at
(Wi-Fi, Bluetooth, Power, About) are backed by NetworkManager, BlueZ,
UPower/power-profiles-daemon and plain system information, all of which are
running. Closing the rest of that gap is the Settings-app work in R6, not a bug
in the launcher.

### How it is summoned

Clicking the mark. Or, from a keybind or a script:

```bash
qs ipc -c aquarius-shell call logomenu toggle
```

`open`, `close` and `isOpen` are there too, the same shape as the search
palette's IPC.

### Why launches use `execDetached`

Settings and the updater are launched with `Quickshell.execDetached`, so they
outlive a shell reload — the same primitive `DesktopEntry.execute()` uses. The
power actions (`systemctl` / `loginctl`) are the very same systemd front doors
the Flow Search palette already runs for its session actions; this menu does not
invent a second way to end a session. Neither form is the `Process { command:
[...] }` shape `tests/test-shell.sh` section 22 guards, so no file was added to
that allow-list.

| File | What it is |
|---|---|
| `components/bar/LogoMenu.qml` | The overlay, the item list, the keyboard, the two-step confirm, the updater probe, the IPC door. |
| `components/bar/MenuRow.qml` | One line in the menu (and the separator). Shared with the dock's drive menu. |
| `theme/Theme.qml` | The `logoMenu*` sizes, in the block after the top bar. |

---

## The desktop right-click menu — labwc

Right-clicking the empty desktop opens the Aquarius menu: **Search**, **System
Settings**, **Change Wallpaper**, and the session actions (**Log Out**,
**Sleep**, **Restart**, **Power Off**). Left-clicking the desktop does nothing —
this is a clean desktop with no icons, and only a context menu was asked for.

### Why this one is labwc's, not shell-drawn

The mark's menu can be a layer-shell popup because it hangs off a bar item the
shell owns. The desktop **root** is the compositor's surface, and there is no
standard, compositor-agnostic way for a layer-shell client to be told "the user
right-clicked the wallpaper here" and to place a popup at that point. labwc's own
menu is the right tool for a right-click on labwc's own root. On a different
compositor the mark menu and `Super+Space` still work; only this root menu is
labwc's.

| File | What it is |
|---|---|
| `session/labwc/menu.xml` | The menu's contents (`root-menu`). |
| `session/labwc/rc.xml` | The `<mouse>` section that binds Root right-click to it, with `<default />` so window dragging still works. |

`Log Out` here uses labwc's own `Exit` — the same teardown as `Super+Shift+E`.

---

## On the bench

```bash
./harness/run-nested.sh
```

Then:

1. **Click the Aquarius mark.** The dropdown should open under it, in Ice, with
   the seven items above. Press Down a few times — the highlight should walk the
   items and skip the separator. Press Esc — it should close. Click the mark,
   then click empty desktop — it should close.
2. **Arrow to Restart, press Enter.** The row should say *Confirm?* and nothing
   should happen. Press Enter again — *only now* should it act. (On the bench,
   test with Sleep first, which does not ask twice, so you do not reboot the
   machine by accident.)
3. **About This PC / System Settings.** Each should open GNOME's Settings — the
   About/System page and the top level respectively. Confirm the panel id on the
   shipped GNOME with `gnome-control-center --list` if either opens the wrong
   page. **This is the item that failed on 2026-09-06**, so also check the two
   other roads to the same app: the Settings icon in the dock, and the Quick
   Settings chevrons. If any of them still does nothing, run
   `env XDG_CURRENT_DESKTOP=GNOME gnome-control-center` in a terminal inside the
   session — if that opens the window, the shell is not adding the prefix
   somewhere; if it does not, the problem has moved into the app itself.
4. **Check for Update.** With the updater installed it should launch it; with it
   removed the item should be greyed and read *Updates unavailable*.
5. **Right-click the empty desktop.** The labwc menu should appear at the
   pointer. Try Search (the palette should open), Change Wallpaper (Settings'
   background page), and — carefully — Sleep.
6. **Drag a window's title bar, resize from an edge, alt-drag to move.** All must
   still work: that is the check that `<default />` in the `<mouse>` section kept
   labwc's own bindings.
