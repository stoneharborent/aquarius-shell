# Notifications

*The notification pipeline: the daemon, the toasts that appear on their own, and
the panel that drops out of the bar clock. Phase P2.*

**Proven end to end 2026-09-01** on the bench PC: `notify-send` in, toast out,
and the panel grouping them by application with counts, timestamps and the
footer clock. Testing it needs a message bus of its own — only one program per
bus can be the notification daemon, and on AquariusOS GNOME already is, so the
harness has `AQ_PRIVATE_BUS=1`. The inline reply and the action buttons have
still never been pressed. See
[`first-run-on-hardware.md`](first-run-on-hardware.md).

---

## The one-sentence version

The Aquarius Shell **is** the machine's notification daemon — applications talk
to it directly, it shows a popup, and it keeps a record of everything in a panel
you open by clicking the clock.

---

## What was built

| File | What it is |
|---|---|
| `components/notifications/NotificationLayer.qml` | The whole thing, as one line in `shell.qml`. Owns the store and builds the windows per monitor. |
| `components/notifications/NotificationStore.qml` | **The daemon.** The only file that talks to the notification protocol. Grouping, Focus policy, toast queue, clear-all. |
| `components/notifications/ToastLayer.qml` | The top-right window the arriving popups stack up in. |
| `components/notifications/Toast.qml` | One popup. |
| `components/notifications/NotificationPanelWindow.qml` | The full-screen transparent window that positions the panel and catches the click-away. |
| `components/notifications/NotificationsPanel.qml` | The 350px panel from the design: header, list, Focus banner, big clock, Focus pill. |
| `components/notifications/NotificationGroup.qml` | One application's notifications, folded together. |
| `components/notifications/NotificationRow.qml` | One notification, as a slab in the panel. |
| `components/notifications/IconChip.qml` | The 34px rounded chip: picture, then app icon, then initials. |
| `components/notifications/ActionButtons.qml` | The buttons an application attaches. |
| `components/notifications/InlineReply.qml` | Answering a chat message from the panel. |
| `services/FocusState.qml` | **Rewritten.** Focus now has a deadline, turns itself off, and survives a restart. |

Also touched: `shell.qml` (four lines), `components/bar/TopBar.qml` (one property,
one binding), `components/bar/BarClock.qml` (two accessibility lines, one comment
block), `components/bar/BarItem.qml` (an `active` property), `theme/Theme.qml`
(new tokens), `theme/Ice.qml` + `theme/Midnight.qml` (one new colour role each),
`services/qmldir`, `tests/test-shell.sh` (three new checks).

---

## Decisions, and the reasons

### The shell is the daemon, not a client of one

`org.freedesktop.Notifications` is a D-Bus service that exactly one program per
session may own. On GNOME that program is GNOME Shell; on KDE it is plasmashell.
In the Aquarius Session it is us.

This is a different architecture from the Wave-2 Plasma widget, which was a
*reader* of KDE's notification library. As a consequence:

- Everything is ours, including the parts KDE was doing for us: what "clear all"
  means, when a popup goes away, what happens on a reload.
- There is no second, sadder empty state. The Plasma widget had to say "the
  notification service isn't running", because it might not have been. If this
  panel is on screen, the service is running, because the panel *is* the service.
- Only one daemon can hold the name. See **Testing this for real** below — this
  is the single biggest practical obstacle to trying it on the bench.

### Grouping: GNOME 48's stacked-by-app model

**This is the one deliberate departure from the V2 design in this track.**

The artboard draws a flat list of three notifications from three applications,
which does not settle the question of what happens when one application has said
eleven things. Grouping settles it: one header per application, newest
application first, collapsed to its newest notification with a count and a slab
peeking out from behind, expandable in place, clearable per application.

The Wave-2 Plasma widget went flat, and its own comment says why — KDE's history
model was doing the work and grouping would have meant header rows the design had
no drawing for. Here we own the model, so the cost is ours to pay and the
benefit is real on a normal morning.

**The grouping key** is the `desktop-entry` hint when the application sends one,
because it survives an application translating its own name; then the app name;
then a single `"unknown"` bucket, so anonymous senders land together instead of
each making a group of one.

**Arrival times are ours.** The protocol carries no timestamp and Quickshell's
`Notification` has no `created` property, so the store writes down the moment each
notification arrives, keyed by id, and forgets it when the notification goes. The
consequence: notifications carried across a live reload all report the time of
the reload, not their real age. There is nowhere to get the real one from.

### Focus semantics

The rule is one function — `NotificationStore.shouldToast()`:

| | Toast appears | Kept in the panel |
|---|---|---|
| Focus **off** | yes | yes |
| Focus **on**, low or normal urgency | **no** | yes |
| Focus **on**, **critical** urgency | **yes** | yes |

**Nothing is ever dropped.** Focus silences; it does not filter. Everything that
arrives during Focus is in the panel, and the panel says how many things arrived
that way ("Focus is on until 6:00. 4 held back.").

**Critical breaks through, and that is on purpose.** The specification reserves
the top urgency for things the machine cannot handle for you — the battery is
about to die, the disk is full, an authentication attempt needs an answer — and
says a critical notification must never expire on its own. Every desktop that
implements Do Not Disturb lets that level through. The alternative is a Focus
mode that can lose your unsaved work. If an application abuses the level, the fix
is a per-application rule in Settings (P3), not a Focus that lies.

**"Focus until morning"** means the next 06:00 — today's if it has not happened
yet, otherwise tomorrow's. 06:00 is the hour KDE picked for its own equivalent,
so somebody moving between the shipping desktop and this one gets the same
answer. One deliberate difference from KDE: KDE always skips to *tomorrow's*
06:00, so turning it on at 01:00 buys 29 hours of silence. We take whichever
06:00 comes next.

**It turns itself off** — a 20-second poll in `FocusState.qml`, rather than one
long timer, because a timer armed for seven hours does not survive a suspend and
does not notice the system clock being corrected.

**It survives a restart.** `enabled` and the deadline are written to
`focus.json` in Quickshell's own per-shell state directory
(`~/.local/state/quickshell/by-shell/<id>/`). A Focus whose deadline passed while
the shell was down comes back **off** — which is the whole reason the deadline is
stored and not just the switch.

### Toast placement

**The design does not draw a toast.** The V2 artboards have the panel and the
bar, and nothing else. So this is a decision, not a port:

Toasts appear in the **top-right corner, 350px wide, 8px under the bar, 12px in
from the edge** — exactly the panel's geometry. A notification therefore appears
in the same place it will later be found, and opening the panel over it reads as
the same object growing rather than a second unrelated surface.

Not centred at the top like GNOME's: a creator watching a preview or a timeline
has their eye in the middle of the screen, and the top centre is the worst place
to put something that covers what they are looking at.

At most **three** are on screen at once; a fourth pushes the oldest off, and the
one pushed off is still in the panel. Hovering a toast pauses its countdown and
moving away gives the full time back.

### How long a toast lives

Critical: **until dealt with**. Everything else: what the application asked for,
clamped to 2–30 seconds, defaulting to 5.

The clamp is also a hedge against a documentation discrepancy — see the
**unproven** list below.

### Capabilities we advertise, and what each means

Quickshell defaults nearly all of these to `false`, so every `true` is a promise
this shell keeps.

| Capability | Us | Why |
|---|---|---|
| `actionsSupported` | yes | Action buttons are drawn. |
| `actionIconsSupported` | no | We draw words, not icons, in a button. |
| `bodySupported` | yes | |
| `bodyMarkupSupported` | yes | Applications send `<b>` regardless and Qt renders it; saying "no" would be contradicted by the screen. Rendered as `Text.StyledText` — Qt's small safe subset, not a web view. |
| `bodyHyperlinksSupported` | no | A link is drawn if one arrives, but nothing opens it, so promising them would be a promise broken on click. |
| `bodyImagesSupported` | no | **`<img>` tags are stripped from the body before it is drawn.** An `<img src="https://…">` in text written by any application on the machine is a tracking pixel with extra steps. |
| `imageSupported` | yes | The notification's own picture goes in the icon chip. |
| `persistenceSupported` | yes | The panel is that persistence. |
| `inlineReplySupported` | yes | The reply box in the panel. |
| `keepOnReload` | yes | The list survives a live reload — but survivors do **not** re-toast, or every file save would shout the last nine notifications at you. |

### No filtering, no muting, no blacklist

Every notification the session sends is kept and shown. Per-application muting is
a Settings surface and belongs to P3. A silent drop rule invented here would mean
notifications going missing with nowhere to look for why.

---

## Design fidelity

Measured off `os-image/branding/design-system/AquariusOS Desktop Shell.html`, the
block with `id="ovNotif"`.

| Design | Built | Note |
|---|---|---|
| Panel `width:350px` | `Theme.notifPanelWidth` | exact |
| Panel `padding:16px` | `Theme.sp4` | exact |
| Panel `border-radius: --radius-lg` | `Theme.radiusLg` (12) | exact |
| Panel `right:12px; top:38px` | `sp3` right, `sp2` top, on a window that starts below the bar | 30 + 8 = 38. There is no `38` in the code, deliberately. |
| Row `padding:12px`, `gap:12px`, `radius:12px` | `sp3`, `sp3`, `radiusLg` | exact |
| Gap between rows `8px` | `sp2` | exact |
| Icon chip `34x34`, `radius:9px` | `notifChipSize`, `radiusMd` | exact |
| Header `600 13px` | `fsSmall` (14) DemiBold | +1px — 13 is not on the token ladder |
| Row title `600 12.5px` | `fsCaption` (12) DemiBold | −0.5px |
| Row body `400 11.5px` | `fsMicro` (11) | **new token** |
| Age `400 10px` mono | `fsMonoSm` (10) mono | **new token** |
| "Clear all" `400 11.5px`, `--text-3` | `fsMicro`, `inkMute` | |
| Footer time `600 20px` display | `fsSubhead` (18) display DemiBold | −2px — 20 is not on the ladder |
| Footer date `400 11px`, `--text-3` | `fsMicro`, `inkMute` | exact |
| Focus pill `padding:8px 12px`, `radius:12px`, accent at 16% when on | `sp4`/`sp5`, `radiusLg`, `accentWash` | **new colour role** |
| Panel `--shadow-pop` | **not drawn** | see below |
| Panel frosted glass | **solid** | the glass came out of the shipping desktop on 2026-08-30; this follows so the two look like one product |

### New design tokens

Three, and they exist because the design's inline values fall off the published
scale.

- **`Theme.fsMicro: 11`** and **`Theme.fsMonoSm: 10`** — `tokens/typography.css`
  stops at caption (12px); the notifications artboard sets its body at 11.5px and
  its timestamps at 10px, inline, because there was no token for either. Named
  once here rather than invented twice in two components.
- **`Ice.accentWash` / `Midnight.accentWash`** — the accent as a tint rather than
  a fill, for a toggle that is switched on. Added to **both** palettes, as the
  rule requires. Ice uses 16% (the design's number); Midnight uses 12%, because
  Midnight's accent is a much brighter blue and the same 16% glares on deep navy.
  **Known limitation, written down:** if Settings ever lets somebody pick indigo
  or turquoise as their accent, this role does **not** follow along on its own.

Plus four plain measurements: `notifPanelWidth`, `notifChipSize`, `notifIconSize`,
`notifGroupIconSize`, and one judgement call, `notifMaxListHeight: 420` (not a
design number — the artboard draws three rows and stops).

### The missing drop shadow

The design gives the panel a large soft shadow (`--shadow-pop`). It is not drawn.
A shadow in QtQuick needs `QtQuick.Effects` and a `MultiEffect`, and adding an
untested effects pipeline to a component that has never been run once is a poor
trade. A heavier border (`lineStrong` instead of `line`) stands in for it. When
the bench run happens and the panel looks flat against a photograph, the fix is
`MultiEffect` plus a `shadow` colour role in both palettes.

---

## What has NOT been proven

**Nothing in this component has ever been executed.** It was written on a Mac,
where there is no QML engine, no Wayland compositor and no D-Bus session. What
*has* been checked is what `tests/test-shell.sh` checks — brackets balance,
imports are the portable ones, no colour outside `theme/`, both palettes agree,
and every `Theme.*` and `FocusState.*` name a component uses actually exists —
plus every Quickshell type and property below having been read off the v0.3.1
documentation or the upstream source rather than remembered.

That is real. It is not the same as working. Specifically unproven:

### Things that could be wrong

1. **`expireTimeout` units.** Quickshell documents `Notification.expireTimeout`
   as *"time in seconds"*. Quickshell's own source
   (`src/services/notifications/notification.cpp`) assigns the D-Bus
   `expire_timeout` argument straight through untouched, and the freedesktop
   specification says that argument is in **milliseconds**. One of the two is
   wrong. The 2000–30000ms clamp in `NotificationStore.toastTimeout()` makes it
   survivable either way, but it should be settled and the clamp adjusted.
   *Test: `notify-send -t 12000 "long" "should stay up twelve seconds"`.*

2. **`focusable: true` on the panel's layer surface.** Asked for so that Escape
   closes the panel and the inline reply box can be typed into. What a compositor
   does with a keyboard-focusable layer surface varies, and this may steal focus
   from the application underneath, or may simply not work. **This is the
   least-proven line in the component.**

3. **A full-screen transparent `PanelWindow` as a click-away catcher.** The whole
   dismiss-by-clicking-elsewhere behaviour rests on it. Also untested: whether
   `color: "transparent"` on a window that starts hidden behaves the way the
   `surfaceFormat.opaque` warning in Quickshell's docs implies.

4. **`exclusiveZone: 0` positioning.** The claim that a `Normal`-mode surface with
   a zero zone starts *below* the bar rather than under it. If it is wrong, the
   panel and the toasts appear behind the bar and the fix is one margin.

5. **`Quickshell.statePath()` + `FileView` + `JsonAdapter` writing.** Whether
   Quickshell creates the state directory before the first write, and whether a
   first run with no file emits `loadFailed` cleanly rather than logging an error
   at the user.

6. **`ClippingRectangle` needs Qt 6.7+.** Fedora 42 and up satisfy it
   comfortably; an older bench box would not.

7. **`Notification.actions` as a Repeater model.** It is a `list<NotificationAction>`
   and is walked with an index loop rather than `.filter()` for exactly this
   reason, but the list is still handed to a `Repeater` after being copied into a
   plain array.

8. **`Accessible.AlertMessage`** as a role for a toast, and the `Accessible.*`
   attached properties generally. None of it has been through a screen reader.

9. **Every visual measurement.** 350px, a 34px chip and 11px body text are
   artboard numbers. Whether they are right on a real screen is a P1-gate-shaped
   question that only a bench run answers.

### Known rough edges (deliberate, not bugs to find later)

- **Half-typed inline replies are lost when a new notification arrives.** The
  group list is rebuilt wholesale on every insert and remove, which recreates the
  delegates. The fix is keying the `Repeater` and holding reply drafts in the
  store; it was not worth the complexity before the thing has run once.
- **Nothing animates on the way out.** A toast is removed from the list the
  moment it is finished, and the panel's window vanishes the instant it is
  hidden, so there is no object left for an exit animation to play on. Doing it
  properly means keeping the window alive for the length of the animation.
- **The panel opens on every monitor at once.** Working out which monitor a
  person is looking at needs a "focused output" service this shell does not have
  yet (P3).
- **Clicking elsewhere on the bar does not close the panel.** The catcher window
  starts below the bar, so bar clicks go to the bar. Clicking the clock toggles
  it closed, which is the one that matters.
- **No sound, no per-app muting, no notification history beyond the session.**
  All P3.

---

## Testing this for real

### The obstacle you will hit first

Only one program per session may own `org.freedesktop.Notifications`. If a GNOME
or KDE session is already running, **its** daemon owns the name and ours will not
get it — quietly. The nested harness does not fix this on its own: the nested
compositor does not get its own session bus, so the outer desktop's daemon is
still there.

Three ways around it, easiest first:

```bash
# 1. Stop the host's daemon for the length of the test (GNOME).
#    Notifications on the host desktop stop working until you log back in.
systemctl --user stop org.gnome.Shell.Notifications 2>/dev/null || true

# 2. Give the nested session its own bus. Everything inside it — the shell AND
#    the notify-send you test with — has to be launched under this bus.
dbus-run-session -- ./harness/run-nested.sh

# 3. Best answer, and the real one: boot the experimental Aquarius Session on
#    the bench machine, where our shell is the only daemon there is. That is a
#    P2 roadmap item, not something this component can do for you.
```

To check who currently owns the name:

```bash
busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
    org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications
```

### Firing test notifications

`notify-send` comes from `libnotify` (`sudo dnf install libnotify`).

```bash
# The plainest one. Expect: a toast top-right, gone in five seconds,
# and a row in the panel afterwards.
notify-send "Screenshot saved" "Added to Pictures. Click to open."

# Grouping. Send several from one "application" and one from another:
# expect two group headers, the chat one folded with a count of 3.
notify-send -a "Messages" "Mika" '"stream starting in 10 — you in?"'
notify-send -a "Messages" "Mika" '"bringing the good mic"'
notify-send -a "Messages" "Dee"  '"running five late"'
notify-send -a "Software" "You're up to date" "Tonight's updates installed themselves."
# Then: click the "Messages" header. Expect it to unfold to three rows.

# Action buttons. Expect two pills under the body; pressing one prints
# its id on the terminal you ran this from and closes the notification.
notify-send "Update ready" "Restart to finish installing." \
    -A "restart=Restart now" -A "later=Later"

# Urgency. The critical one must NOT go away on its own.
notify-send -u low      "Quiet"    "Low urgency."
notify-send -u normal   "Normal"   "Normal urgency."
notify-send -u critical "Battery"  "3% remaining. Plug in now."

# An image in the chip, rather than an app icon.
notify-send "Look at this" "With a picture." -i /usr/share/pixmaps/fedora-logo.png

# Transient: should toast and then NOT appear in the panel.
notify-send -h boolean:transient:true "Volume" "64%"

# Markup, and the <img> that must be stripped rather than fetched.
notify-send "Markup" "<b>bold</b>, <i>italic</i><img src=\"https://example.com/x.png\">"

# Timeout, for the units question in the unproven list above.
notify-send -t 12000 "Twelve" "Should stay up for twelve seconds."
```

### The Focus tests

```bash
# 1. Open the panel (click the clock). Press "Focus until morning".
#    Expect: the pill lights, a banner appears saying until when.
# 2. With the panel closed:
notify-send "Held" "Should NOT toast."
notify-send -u critical "Urgent" "SHOULD toast anyway."
# 3. Reopen the panel. Expect both rows present, and the banner
#    now reading "… 1 held back." (the critical one was not held).
# 4. Press the pill again. Expect the banner to go and the count to reset.
```

**Persistence** — the part that cannot be tested by looking at the screen:

```bash
# Turn Focus on, then:
cat ~/.local/state/quickshell/by-shell/*/focus.json
# Expect something like: {"enabled":true,"until":1756699200000}

# Now restart the shell (Ctrl-C the harness, run it again) and open the
# panel. Expect Focus still on, with the same deadline.

# And the lapse case: edit `until` in that file to a timestamp in the past,
# restart, and expect Focus to come back OFF.
```

**The auto-off timer** is the slow one. Rather than waiting until 06:00, set
`until` in `focus.json` to about ninety seconds ahead, restart the shell, turn
nothing on, and watch the pill go dark on its own within 20 seconds of that time.

### What "it works" looks like

- The clock stays lit while its panel is open.
- Clicking anywhere outside the panel closes it. So does Escape.
- The panel never scrolls the whole screen — long lists scroll inside it.
- Ice and Midnight both look deliberate. Flip `Theme.dark` in `theme/Theme.qml`,
  save, and watch it repaint without restarting anything.
- Nothing anywhere is see-through.
