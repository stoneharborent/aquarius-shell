# `session/` — everything needed to log INTO the Aquarius Shell

The harness in `../harness/` runs the shell **in a window**, on top of whatever
desktop you are already using. This folder is the other thing: the shell as a
**session you pick at the login screen**, next to GNOME.

**The walkthrough lives in [`../docs/session.md`](../docs/session.md).** It is
written for somebody who has never used Linux, and it is the file to read.
This one is just the map.

| File | What it is |
|---|---|
| `aquarius-session` | The launcher. The login screen runs this. It checks what is installed, sets the environment, and starts a compositor. |
| `aquarius.desktop` | The entry that makes "Aquarius Session (experimental)" appear at the login screen. |
| `install-session.sh` | Puts those two, plus the configs, in the right places — **without modifying the OS image.** Also `--uninstall`. |
| `niri/config.kdl` | The session on **niri** (scrollable tiling). |
| `labwc/rc.xml` + `autostart` + `shutdown` + `environment` | The session on **labwc** (plain stacking windows). |
| `portals/aquarius-niri-portals.conf` | Which portal back ends answer which question, on niri. |
| `portals/aquarius-labwc-portals.conf` | The same, for labwc. **Different file, on purpose** — the two compositors need different screen-capture back ends. |

## Two compositors, because the choice is not made yet

`docs/adr/0001-framework.md` deliberately left the compositor question open, and
P2's gate is where it gets answered. So both are configured, both work the same
way from the outside, and switching is one word:

```bash
mkdir -p ~/.config/aquarius-session
echo labwc > ~/.config/aquarius-session/compositor   # or: niri
```

## The rules these files obey

- **No colours.** Not in the niri config, not in the labwc config. Colour lives
  in `theme/Ice.qml` and `theme/Midnight.qml` and nowhere else. The compositors'
  own chrome stays at their own defaults until the shell owns it.
- **No paths.** No compositor config names a directory. The shell is started
  with a bare `qs`, which works because `aquarius-session` exports
  `QS_CONFIG_PATH` first. That is what keeps these files identical on every
  machine.
- **Never burn the boats.** Nothing here removes, replaces or reorders the GNOME
  session. It is added alongside, and `--uninstall` removes it again.

## Honest status

**None of this has ever been run.** It was written on a Mac, where there is no
Wayland, no compositor, no `qs`, no systemd and no D-Bus. What has been checked
is that the XML parses, the key files are present, the shell scripts pass
`shellcheck`, no colour or machine-specific path has crept in, and every API and
config key used here was read from its project's own documentation or source.

The full list of what that does and does not cover is at the bottom of
[`../docs/session.md`](../docs/session.md).
