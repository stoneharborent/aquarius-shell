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
│  About This PC             │   Settings, ON its About page
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
  program: both call `SettingsLauncher.open()` — `("system", ["about"])` for
  About This PC, `("")` for System Settings. See
  [Opening Settings](#opening-settings) and
  [Asking for a page inside a panel](#asking-for-a-page-inside-a-panel).
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

### Asking for a page inside a panel

*Fixed 2026-09-06, second bench pass.*

With the `env` prefix in place, every Settings click opened the app — and
**About This PC** opened it on the **System panel's front page**, which is a
list of rows, one of which says *About*. An item called "About This PC" that
makes you click *About* is not doing what it says.

gnome-control-center takes a page **inside** a panel as a further word on the
command line:

```bash
gnome-control-center system about
#                    ^^^^^^ ^^^^^
#                    panel  page inside it
```

That form is not folklore; it is three steps through the app's own source.

1. **`shell/cc-application.c`, `cc_application_command_line()`** splits the
   leftover words: word 0 is the panel, the rest become an array called
   `parameters`.

   ```c
   start_id = start_panels[0];
   g_variant_builder_init (&builder, G_VARIANT_TYPE ("av"));
   for (i = 1; start_panels[i] != NULL; i++)
     g_variant_builder_add (&builder, "v", g_variant_new_string (start_panels[i]));
   parameters = g_variant_builder_end (&builder);
   ...
   cc_window_set_active_panel_from_id (self->window, start_id, parameters, &err)
   ```

   Its own `--help` text says the same in one line: `N_("[PANEL] [ARGUMENT…]")`.

2. **`shell/cc-window.c`, `set_active_panel_from_id()`** hands that array to the
   panel:

   ```c
   g_object_set (G_OBJECT (self->current_panel), "parameters", parameters, NULL);
   ```

3. **`shell/cc-panel.c`, `cc_panel_set_property()`, case `PROP_PARAMETERS`**
   reads the FIRST parameter and treats it as the name of a subpage:

   ```c
   g_variant_get_child (parameters, 0, "v", &v);
   if (g_variant_is_of_type (v, G_VARIANT_TYPE_STRING))
     set_subpage (CC_PANEL (object), g_variant_get_string (v, NULL));
   ```

   An unknown name warns `Invalid subpage: '%s'` and stays on the front page —
   the wrong page, never a crash, exactly as a wrong panel id behaves.

The System panel registers its pages by name in
**`panels/system/cc-system-panel.c`, `cc_system_panel_init()`**:

```c
cc_panel_add_static_subpage (CC_PANEL (self), "about", CC_TYPE_ABOUT_PAGE);
cc_panel_add_static_subpage (CC_PANEL (self), "datetime", CC_TYPE_DATE_TIME_PAGE);
cc_panel_add_static_subpage (CC_PANEL (self), "region", CC_TYPE_REGION_PAGE);
cc_panel_add_static_subpage (CC_PANEL (self), "remote-desktop", CC_TYPE_REMOTE_DESKTOP_PAGE);
cc_panel_add_static_subpage (CC_PANEL (self), "users", CC_TYPE_USERS_PAGE);
```

Panel ids are printed by `gnome-control-center --list`. **Subpage names are
printed by nothing** — they exist only in that source file — which is why the
five above are written down here and in the launcher's header.

#### The API

```qml
SettingsLauncher.open(panel, parameters)     // parameters is optional

SettingsLauncher.open("")                    // the app, on its default page
SettingsLauncher.open("wifi")                // the Wi-Fi panel
SettingsLauncher.open("bluetooth")           // the Bluetooth panel
SettingsLauncher.open("power")               // the Power panel
SettingsLauncher.open("system")              // the System panel's front page
SettingsLauncher.open("system", ["about"])   // the About page itself
```

**Why two arguments and not one string.** `open("system about")` reads shorter
and is what you would type in a terminal — and it is the wrong shape here,
because this function does not run a shell. It hands `execDetached` a *list* of
arguments, and building that list by splitting on spaces means every caller's
argument is silently reshaped by its own whitespace; the day a value legitimately
contains a space, the split quietly produces two arguments and the wrong page
opens. A panel and a list is exactly the shape of the argv that comes out the
other end, so nothing is parsed and nothing can be misparsed. `parameters` is
optional, so every caller written before this is unchanged.

Passing parameters with **no** panel is refused with a warning rather than
obeyed: word 0 is always the panel id, so those parameters would be read as a
panel name and open some unrelated page.

`tests/test-shell.sh` **section 34b** checks that `open()` still takes the second
argument, and that About This PC still passes `["about"]`.

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

### What it looks like

*Added 2026-09-06, second bench pass — "the right click menu does not have a
design yet".*

labwc drew this menu in its own default Openbox grey, because nothing had told
it otherwise. It now wears the Aquarius look, and the reference for that look is
the shell's own menu two inches above it: a bright Ice card, one hairline around
it, deep-navy text, an accent-tinted row under the pointer, hairline separators,
and a fixed width.

That look is **written by a program** rather than typed out:
**`session/labwc/generate-theme`**, next to `rc.xml`. It reads `theme/Ice.qml` or
`theme/Midnight.qml` and writes labwc's own theme file for it, every time the
desktop starts and every time the machine goes light or dark. There is no second
copy of the palette to keep in step, because the second copy is made.

labwc reads that file out of its configuration directory — the same folder as
`rc.xml`, which for this session is the generated one in your home
(`aquarius-session` runs the generator, then starts labwc with
`labwc -C ~/.config/aquarius/labwc`). (labwc-theme(5): *"Theme settings specified
in themerc can be overridden by creating a 'themerc-override' file in the
configuration directory"*; and its `src/common/dir.c` is explicit that `-C`
"trumps everything else".)

| themerc key | Palette token | Ice | Midnight |
|---|---|---|---|
| `menu.items.bg.color` | `surface` | `#F7FBFE` | `#121C2E` |
| `menu.items.text.color` | `ink` | `#16273A` | `#DCE9F4` |
| `menu.items.active.bg.color` | `accentWash` | `#2C8FC429` | `#00BFFF1F` |
| `menu.items.active.text.color` | `ink` | `#16273A` | `#DCE9F4` |
| `menu.border.color` | `lineStrong` | `#16273A2E` | `#DCF3FF29` |
| `menu.separator.color` | `line` | `#16273A1A` | `#DCF3FF14` |
| `menu.title.bg.color` / `.text.color` | `surfaceAlt` / `inkSoft` | `#E4EDF6` / `#47586B` | `#1B2940` / `#93A7BC` |
| `menu.width.min` / `.max` | `Theme.logoMenuMinWidth`, both, so it is one fixed width | `240` | `240` |
| `menu.items.padding.x` / `.y` | `Theme.logoMenuRowPaddingH`, and a `y` chosen to land near `logoMenuRowHeight` | `16` / `9` | `16` / `9` |
| `menu.border.width`, `menu.separator.width` | `Theme.hairline` | `1` | `1` |
| `menu.separator.padding.width` / `.height` | `Theme.logoMenuSeparatorMargin` | `8` / `8` | `8` / `8` |

Every size in that table is multiplied by `AQ_UI_SCALE`, which the old
hand-written file could not do.

**The same program draws window title bars,** so it styles those too — otherwise
an Aquarius menu and a stock Openbox title bar would share a screen. Active title
bar `panel` (the top bar's own colour), inactive `surfaceAlt`, label `ink` /
`inkMute`, borders `lineStrong` / `line` at one pixel, and three round buttons
drawn as SVG into `~/.local/share/themes/Aquarius/labwc/`. Restrained on purpose:
no accent anywhere except the close button under the pointer, because a window
frame is chrome, and chrome that draws attention to itself is chrome you end up
looking at. The window-switcher OSD is not given keys of its own — labwc's
documented inheritance already points it at those same four values.

**The font is not in that file.** labwc splits one look across two: colours come
from the themerc, fonts come from `rc.xml`'s `<theme>` section. So `rc.xml` sets
`MenuItem`, `MenuHeader`, `ActiveWindow` and `InactiveWindow` to **Inter** — what
`Theme.fontBody` picks — at sizes in pixels (labwc-config(5): *"Font size in
pixels"*, the same unit `Theme` uses): `19` = `Theme.fsBody` for a menu row, `15`
= `Theme.fsCaption` for a menu title, and `13` at weight `medium` for a window's
own title. Those are generated too, so they scale as well.

#### The colour rule, and how it is kept now

Colour in this project lives in `theme/Ice.qml` and `theme/Midnight.qml` and
nowhere else — **including here**. A themerc cannot import QML, and for one day
in September 2026 that meant a hand-written second copy of the Ice palette. It
does not any more: the generator reads the QML and writes the themerc, so a
colour cannot drift out of step with the palette because it is never separated
from it.

`tests/test-shell.sh` **section 15b** proves it by running the generator for both
palettes at 1× and 1.25× and checking that every colour it wrote appears in the
matching QML file, that the design's own values are there, that the sizes really
scale, that all sixteen button pictures were drawn, and that every line is one
labwc can actually parse.

Translucent values are written labwc's way (`#rrggbbaa`, opacity last) and QML's
way (`#aarrggbb`, opacity first); the test compares the six colour digits.

A themerc has **no end-of-line comments** — labwc takes everything after the
first colon as the value, so `key: value  # why` silently sets nothing. The
generator writes every explanation on a line of its own, and there is a check for
that too.

#### Both themes, both desktops

Two things that were open questions on 2026-09-06 and are now closed:

- **Midnight.** A themerc is read once, at start-up, so when
  `services/SystemAppearance.qml` flips the shell to dark it also re-runs the
  generator and then runs **`labwc --reconfigure`**. The menu and the title bars
  follow the theme in place, with no logout.
- **The os-image twin.** An installed machine reads
  `system_files/usr/share/aquarius/labwc/` in the `os-image` repo, which ships
  its own copy of the generator and runs it the same way. `check-labwc-drift.sh`
  there runs *both* copies and compares what they produce, so **CHANGE ONE,
  CHANGE BOTH** is enforced rather than remembered.

| File | What it is |
|---|---|
| `session/labwc/menu.xml` | The menu's contents (`root-menu`). |
| `session/labwc/generate-theme` | The program that WRITES its look — and window title bars', and the round window buttons — out of `theme/Ice.qml` or `theme/Midnight.qml`. |
| `session/labwc/rc.xml` | The `<mouse>` section that binds Root right-click to it, with `<default />` so window dragging still works; and the `<theme><font>` block those surfaces are drawn in. |

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
3. **About This PC / System Settings.** *About This PC* should land **on the
   About page**, with the machine's model, memory and disk on screen — not on the
   System panel's list of rows. (Landing on that list is the exact 2026-09-06
   complaint; if it happens again, run `gnome-control-center system about` in a
   terminal inside the session. If that lands on About, the shell has stopped
   passing the second word; if it does not, the shipped GNOME has renamed the
   subpage and the new name is in its `panels/system/cc-system-panel.c`.)
   *System Settings* should open the app at its top level. Confirm the panel id
   on the shipped GNOME with `gnome-control-center --list` if either opens the
   wrong page. **This is the item that failed on 2026-09-06**, so also check the two
   other roads to the same app: the Settings icon in the dock, and the Quick
   Settings chevrons. If any of them still does nothing, run
   `env XDG_CURRENT_DESKTOP=GNOME gnome-control-center` in a terminal inside the
   session — if that opens the window, the shell is not adding the prefix
   somewhere; if it does not, the problem has moved into the app itself.
4. **Check for Update.** With the updater installed it should launch it; with it
   removed the item should be greyed and read *Updates unavailable*.
5. **Right-click the empty desktop.** The labwc menu should appear at the
   pointer, and it should **look like the mark's menu** — a bright card, a
   hairline round it, navy text, the row under the pointer tinted blue. If it is
   grey with black text, labwc has not read the generated themerc: check that
   `~/.config/aquarius/labwc/themerc-override` exists (its first lines say which
   theme and which size it was built for), and that labwc was started with that
   folder — `~/.local/state/aquarius-session/session.log` prints the folder it
   used, and falls back to the shipped template if generating failed. Try Search (the palette should open), Change Wallpaper (Settings'
   background page), and — carefully — Sleep.
6. **Look at a window's title bar.** It should be the same pale blue as the top
   bar, with the focused window's title in navy and an unfocused one's in grey,
   and a one-pixel border. The menu and the window frame should read as the same
   design.
7. **Press Super + Return.** A terminal should open (`ptyxis` on AquariusOS;
   nothing at all on a plain Fedora clone that does not have it, which is
   expected).
8. **Switch the system to dark** (`gsettings set org.gnome.desktop.interface
   color-scheme prefer-dark`). The shell should turn Midnight and **the desktop
   menu and title bars should stay light** — that is the known Ice-only seam, not
   a bug. It is written up in `docs/session.md` and in the themerc's header.
9. **Drag a window's title bar, resize from an edge, alt-drag to move.** All must
   still work: that is the check that `<default />` in the `<mouse>` section kept
   labwc's own bindings.
