# Resuming on the Linux machine — read this first after the move

*Written 2026-08-31 the day P2 was merged, for the move from the Mac to the
Linux bench machine. **Updated 2026-09-01: the move is done and the shell has
run.** Everything below is now the record of how it was set up plus the way back
in, rather than a list of things to try.*

> **The shell runs.** First light was 2026-09-01 on the bench PC. What that
> proved, what broke on the way, and what is still unproven is on one page:
> **[`first-run-on-hardware.md`](first-run-on-hardware.md)**. Read that first;
> this page is just how to get the window back on screen.

## What moved, and what that means

This folder IS the repository — the `.git` directory inside it carries the full
history. **The Linux machine is this repo's home now.** The copy that used to
live on the Mac is stale. One home, and it is this one. That is also the better
home: the shell can only *run* on Linux, so the edit-save-watch-it-reload loop
only exists here.

It lives at:

```
/run/media/system/Internal Drive/Workflow/Branches/Apps/AquariusOS/aquarius-shell
```

**That path has spaces in it, and it turned out not to matter.** The earlier
version of this page said to move the folder to `~/aquarius-shell` to avoid
them. Everything — the scripts, the harness, Quickshell's `-p`, the tests — was
already quoting properly, and none of it minded. Left where it is.

## Getting it running again

**One command, from this folder:**

```bash
distrobox enter aq-shell
```

```bash
./harness/run-nested.sh
```

A window opens with a small desktop in it and the Aquarius shell inside that.
`harness/README.md` is the full walkthrough — what you should see, how to drive
the panels from a script, and the six things that actually go wrong.

The `aq-shell` distrobox already has everything: `quickshell`, `niri`, plus
`foot`, `grim`, `wlrctl`, `wtype`, `ImageMagick` and `dbus-daemon` for testing.
It also has a `~/.config/fontconfig/fonts.conf` pointing at the host's fonts, so
the harness renders in the real Sora / Inter / JetBrains Mono. If that container
is ever rebuilt, `harness/README.md` has the font step; everything else the
harness now wires up by itself.

**To test notifications**, which needs a message bus of its own:

```bash
AQ_PRIVATE_BUS=1 ./harness/run-nested.sh
```

## The cheap check, before running anything

```bash
bash tests/test-shell.sh
```

25 sections plus the search palette's 73 executed assertions. Worth running, but
know what it is: every one of the four failures that stopped the shell loading on
2026-09-01 passed this suite first. It reads the files; it does not run them.

## Where the work stands

- **P1's gate** — *does the Aquarius bar feel better than the themed panel?* —
  is finally askable, and is a judgement for Royce at the machine. Note it comes
  up **Midnight, not Ice**, because it follows the system's dark setting.
- **P2's gate** — *OBS records, Steam desktop works, a full workday survives* —
  needs the real login session, which has still never been booted.
- **The next real step is the session**: `docs/session.md`. Everything so far has
  been the nested harness.
- Each component doc still ends with its own unproven list: `docs/dock.md`,
  `docs/quick-settings.md`, `docs/notifications.md`, `docs/flow-search.md`,
  `docs/session.md`.

## How Claude resumes work on this repo

- **On the Linux machine:** open Claude Code in this folder. This page,
  `first-run-on-hardware.md`, `docs/ROADMAP.md` and the component docs are the
  full context; the git log tells the story commit by commit.
- **From the Mac session:** planning can continue there; shell code changes
  should happen where the shell can run — here.
- **If the repo ever gets a GitHub remote** (Royce's call, standing rule from
  P1): push from here, and `.github/workflows/lint.yml` wakes up and runs
  qmllint on a real Fedora container — the check the Mac never could.
