# Resuming on the Linux machine — read this first after the move

*Written 2026-08-31, the day P2 was merged. Royce is moving this whole folder
from the Mac to the Linux bench machine. This page is the "what now" — written
for a beginner, one copyable line per step.*

## What moved, and what that means

This folder IS the repository — the `.git` directory inside it carries the
full history, all branches, everything. Nothing is lost by moving the folder.

**After the move, the Linux machine is this repo's home.** The copy that used
to live on the Mac (in the iCloud vault at
`Workflow/Branches/Apps/AquariusOS/aquarius-shell/`) is stale the moment any
work happens here. Do not edit both — one home, and it is this one now. That
is also the better home: the shell can only *run* on Linux, so the
edit-save-watch-it-reload loop only exists here.

## Step 0 — put it somewhere without spaces

Put the folder in your home directory, for example `~/aquarius-shell`. Avoid
paths with spaces (the vault path had them; shells fight you over them).

## Step 1 — give the scripts back their permission to run

Depending on how the folder travelled (zip, USB, network copy), Linux may have
forgotten which files are programs. From inside the folder:

```bash
chmod +x harness/run-nested.sh tests/test-shell.sh session/aquarius-session session/install-session.sh session/labwc/autostart session/labwc/shutdown
```

Harmless if they were already fine.

## Step 2 — check nothing broke in transit

```bash
bash tests/test-shell.sh
```

Every section should pass, same as it did on the Mac the day of the move
(25 sections + the search palette's 73 executed assertions via
`node tests/search-js-tests.mjs`, if node is installed).

## Step 3 — the tools, in a throwaway container

AquariusOS is atomic — plain `dnf install` is refused on purpose. Use a
distrobox (ships with the OS):

```bash
distrobox create --name aq-shell --image fedora:latest
```

```bash
distrobox enter aq-shell
```

```bash
sudo dnf install quickshell niri
```

If `quickshell` is not found: `sudo dnf copr enable errornointernet/quickshell`
then retry. Paste tip: use **Ctrl+Shift+V** in the terminal — plain Ctrl+V can
glue invisible `[200~` junk onto commands.

## Step 4 — first light

From the folder, inside the distrobox:

```bash
./harness/run-nested.sh
```

A window opens containing a small desktop. What SHOULD be in it, as of the P2
merge: the Ice bar on top (mark, bold app name, live status glyphs, clock),
the centred dock at the bottom, and — on interaction — Quick Settings from the
status cluster, the notifications panel from the clock, the search palette
from the Aquarius mark or the dock's `+`.

**Expect errors.** None of the QML has ever been executed; P2 was five
parallel tracks written in one day. If the window opens with nothing in it,
the terminal prints the QML error with file and line — that error message is
the deliverable of the first run. `harness/README.md` has the fuller
walkthrough and a table of known failure shapes.

## Step 5 — work through the bench lists

Each component doc ends with its own numbered bench steps and its honest
unproven list: `docs/dock.md`, `docs/quick-settings.md`,
`docs/notifications.md`, `docs/flow-search.md`, `docs/session.md` (the real
login session — only after the harness works).

The two open gates, from `docs/ROADMAP.md`:
- **P1's:** does the Ice bar feel better than the themed panel?
- **P2's:** OBS records, Steam desktop works, a full workday survives.

## How Claude resumes work on this repo

- **On the Linux machine:** open Claude Code in this folder. This page plus
  `docs/ROADMAP.md` and the component docs are the full context; the git log
  tells the story commit by commit.
- **From the Mac session:** the Mac's AquariusOS project (master `ROADMAP.md`,
  Track D) records that the repo moved to the bench on 2026-08-31. Planning
  can continue there; shell code changes should happen where the shell can
  run — here.
- **If the repo ever gets a GitHub remote** (Royce's call, standing rule from
  P1): push from here, and `.github/workflows/lint.yml` wakes up and runs
  qmllint on a real Fedora container — the check the Mac never could.
