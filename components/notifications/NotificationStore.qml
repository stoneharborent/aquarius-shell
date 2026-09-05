// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// NotificationStore — the shell IS the notification daemon
// =============================================================================
// This is the only file in the repo that talks to the notification protocol.
// Every other file in components/notifications/ draws what this one hands it.
// That split is on purpose: when Quickshell changes an API, there is exactly one
// place to look, and the drawing code can be read by somebody who knows nothing
// about D-Bus.
//
// WHAT "THE SHELL IS THE DAEMON" ACTUALLY MEANS
//   `org.freedesktop.Notifications` is a D-Bus service that exactly one program
//   on the session may own. Applications call `Notify()` on it and it decides
//   what to draw. On a normal GNOME machine that program is GNOME Shell; on KDE
//   it is plasmashell. In the Aquarius Session it is US — the moment this object
//   exists, `notify-send` and every application on the machine is talking to
//   this file.
//
//   The consequence, and it matters on the bench: only one daemon can hold the
//   name. If a GNOME or KDE session is already running, our server will not get
//   it. Inside the nested harness (harness/run-nested.sh) the nested compositor
//   does NOT get its own session bus, so the outer desktop's daemon usually
//   still owns the name — see docs/notifications.md, "Testing this for real",
//   for how to get around that.
//
// WHAT WE ADVERTISE, AND WHY EACH ANSWER IS THE HONEST ONE
//   The specification lets a server list its capabilities so applications can
//   tailor what they send. Quickshell defaults nearly all of them to FALSE, so
//   every `true` below is a promise this shell actually keeps. Claiming a
//   capability we do not implement is worse than claiming none: an application
//   that is told we render images will stop sending the text fallback.
//
// THE ONE THING THIS FILE DELIBERATELY DOES NOT DO
//   It does not filter, mute or blacklist anything. Every notification the
//   session sends is kept and shown. Per-application muting is a Settings
//   surface and belongs to Phase P3; inventing a silent drop rule here would
//   mean notifications going missing with nowhere to look for why.
//
// API reference (every type and property below was read off these pages, not
// remembered):
//   https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/NotificationServer/
//   https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/Notification/
//   https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/NotificationAction/
//   https://quickshell.org/docs/v0.3.1/types/Quickshell/ObjectModel/
// =============================================================================
pragma ComponentBehavior: Bound

import QtQuick

import Quickshell
import Quickshell.Services.Notifications

import "../../services"
import "progress.js" as Progress

Scope {
    id: root

    // =========================================================================
    // Tuning — the numbers that decide how long you are interrupted for
    // =========================================================================
    // These are behaviour, not design, so they live here rather than in Theme.

    // How long a toast stays up when the sending application does not ask for
    // anything in particular. Five seconds is the figure GNOME, KDE and every
    // libnotify default have converged on.
    readonly property int defaultToastMs: 5000

    // The band we will clamp an application's request into.
    //
    // THIS CLAMP IS ALSO A HEDGE, AND IT IS WORTH KNOWING WHY.
    //   `Notification.expireTimeout` is documented by Quickshell as "time in
    //   seconds", but Quickshell's own source passes the D-Bus `expire_timeout`
    //   argument straight through untouched, and the freedesktop specification
    //   says that argument is in MILLISECONDS. One of those two is wrong and we
    //   cannot tell which from a Mac. Clamping to this band makes the question
    //   survivable either way: a five-second request arrives as either 5000
    //   (read as 5s — correct) or 5 (clamped up to 2s — a little short, not a
    //   bug). Settle it on the bench; docs/notifications.md has the test.
    readonly property int minToastMs: 2000
    readonly property int maxToastMs: 30000

    // How many toasts may be on screen at once. The oldest is pushed off the
    // bottom when a fourth arrives — it is not lost, it is in the panel.
    readonly property int maxVisibleToasts: 3

    // =========================================================================
    // What the interface reads
    // =========================================================================

    // Notifications grouped by the application that sent them, newest group
    // first. Each entry is a plain JavaScript object:
    //
    //     {
    //         key:      "org.gnome.Screenshot"   stable id for this app
    //         appName:  "Screenshots"            what to print on the header
    //         appIcon:  "applets-screenshooter"  icon name, or ""
    //         items:    [ Notification, ... ]    newest first
    //         count:    3
    //         newest:   1756600000000            epoch ms, for ordering groups
    //         expanded: false
    //     }
    //
    // `items` holds the LIVE Notification objects, so a row's text keeps
    // updating if the sending application edits it in place (a download that
    // rewrites its own percentage does exactly this).
    property var groups: []

    // The toasts currently on screen, oldest first, so they stack downward in
    // arrival order.
    property var toasts: []

    // How many notifications are being held, in total.
    property int count: 0

    // How many arrived while Focus was on and therefore never made a sound.
    // The panel says this out loud, because a count of things you were not
    // told about is the one number that makes Focus safe to trust.
    property int heldBack: 0

    // =========================================================================
    // Private state
    // =========================================================================

    // id -> epoch milliseconds. The notification protocol carries no timestamp
    // and Quickshell's Notification has no `created` property, so the moment a
    // notification arrives is something we have to write down ourselves.
    property var arrival: ({})

    // group key -> true. Absent means collapsed.
    property var expanded: ({})

    // =========================================================================
    // The server
    // =========================================================================
    NotificationServer {
        id: server

        // WE DO show action buttons, so applications may send them.
        actionsSupported: true

        // We do NOT draw an icon inside an action button, so applications
        // should keep sending words rather than icon names.
        actionIconsSupported: false

        // Body text: yes (this is Quickshell's default, restated so the whole
        // set of answers can be read in one place).
        bodySupported: true

        // Markup: yes. Applications send `<b>` and `<i>` whether a server
        // advertises it or not, and Qt's Text renders that subset by default,
        // so saying "no" here would be a claim contradicted by what is on the
        // screen. NotificationRow renders bodies as Text.StyledText, which is
        // Qt's small safe subset — not a web view.
        bodyMarkupSupported: true

        // Hyperlinks: no. StyledText will still DRAW an <a href> that arrives,
        // but nothing in this shell opens one, so promising them would be a
        // promise we break on click.
        bodyHyperlinksSupported: false

        // Images inside the body: no. <img> tags are stripped before the body
        // is drawn — see NotificationRow.qml. An <img src="https://..."> in
        // text sent by any application on the machine is a tracking pixel with
        // extra steps, and there is no version of this panel that should fetch
        // one.
        bodyImagesSupported: false

        // The notification's own picture (a screenshot thumbnail, an album
        // cover, a sender's avatar) — yes, drawn in the icon chip.
        imageSupported: true

        // We keep notifications after they leave the screen; that IS the panel.
        persistenceSupported: true

        // Reply straight from the panel, for the applications that offer it.
        inlineReplySupported: true

        // Survive a live reload with the list intact. Quickshell re-emits the
        // previous generation's notifications with `lastGeneration` set, which
        // `ingest` uses to bring them back into the panel WITHOUT re-toasting
        // them — being shouted at by nine old notifications every time a file
        // is saved would make the dev loop unusable.
        keepOnReload: true

        onNotification: function (notification) {
            root.ingest(notification);
        }
    }

    // The tracked list changing is what drives every rebuild. Insert and remove
    // are the only structural events; an application editing a notification in
    // place changes properties on an object the delegates are already bound to,
    // so it needs no rebuild at all.
    Connections {
        target: server.trackedNotifications

        function onObjectInsertedPost(inserted, index) {
            root.rebuild();
        }

        function onObjectRemovedPre(removed, index) {
            root.forget(removed);
        }

        function onObjectRemovedPost(removed, index) {
            root.rebuild();
        }
    }

    // When Focus ends, the "held back" tally has been read and is spent.
    Connections {
        target: FocusState

        function onEnabledChanged() {
            if (!FocusState.enabled)
                root.heldBack = 0;
        }
    }

    // Pick up anything Quickshell carried across a reload.
    Component.onCompleted: root.rebuild()

    // =========================================================================
    // Arrival
    // =========================================================================

    function ingest(n): void {
        // Quickshell DISCARDS a notification unless the server claims it. This
        // one line is the difference between a working daemon and one that
        // silently drops everything.
        n.tracked = true;

        root.arrival[n.id] = Date.now();

        if (n.lastGeneration) {
            // Carried over from before a reload. It is already old news; put it
            // back in the list and say nothing.
            root.rebuild();
            return;
        }

        if (root.shouldToast(n))
            root.pushToast(n);
        else if (FocusState.enabled)
            root.heldBack += 1;

        root.rebuild();
    }

    // ---- FOCUS POLICY, IN ONE FUNCTION --------------------------------------
    // Written as one small function on purpose: "when may the machine interrupt
    // you" is a question that should have exactly one answer in one place.
    //
    //   * Focus off  -> everything toasts.
    //   * Focus on   -> nothing toasts, EXCEPT critical.
    //
    // WHY CRITICAL BREAKS THROUGH
    //   The specification defines three urgencies and says of the top one that
    //   it must never expire on its own — it is reserved for things the machine
    //   cannot handle for you: the battery is about to die, the disk is full, a
    //   drive is failing, an authentication attempt needs an answer. Every
    //   desktop that implements Do Not Disturb lets that level through, and the
    //   alternative is a Focus mode that can lose your unsaved work. If an
    //   application abuses the level, the fix is a per-application rule in
    //   Settings (Phase P3), not a Focus that lies.
    //
    //   Nothing else changes under Focus. Low and normal notifications are still
    //   kept, in full, in the panel — they are silenced, never dropped.
    function shouldToast(n): bool {
        if (n.urgency === NotificationUrgency.Critical)
            return true;
        return !FocusState.enabled;
    }

    // =========================================================================
    // Progress — a notification that is reporting a job, not announcing news
    // =========================================================================
    // The arithmetic and the paranoia both live in progress.js, so that they can
    // be RUN by node on a Mac (tests/notifications-js-tests.mjs) rather than
    // only read. These three are the doorway QML uses.

    //: -1 when a notification carries no usable progress; otherwise 0 to 100.
    function progressOf(n): int {
        if (!n)
            return Progress.NO_PROGRESS;
        return Progress.percentOf(n.hints);
    }

    function hasProgress(n): bool {
        return root.progressOf(n) !== Progress.NO_PROGRESS;
    }

    // The name a notification asks to be replaced under, or "".
    function progressTag(n): string {
        if (!n)
            return "";
        return Progress.tagOf(n.hints);
    }

    // How long this notification's toast should live, in milliseconds.
    // 0 means "until somebody deals with it".
    function toastTimeout(n): int {
        // A critical notification is never taken off the screen by a clock.
        if (n.urgency === NotificationUrgency.Critical)
            return 0;

        // Neither is a job that is still running. "Make Editor-Ready" converting
        // a card of footage takes twenty minutes; a progress bar that vanished
        // after five seconds of it is worse than no progress bar, because the
        // person is then left thinking the work stopped. The same notification
        // at 100% is finished news and expires like anything else.
        //
        // Note the shape of this: the toast holds because the notification SAYS
        // it is mid-job, not because we recognise which application sent it.
        // Anything on the machine that reports progress gets the same treatment.
        if (Progress.isRunning(n.hints))
            return 0;

        const requested = n.expireTimeout;

        // 0 is the specification's "never expire"; a negative number is its
        // "you decide".
        if (requested === 0)
            return 0;
        if (!(requested > 0))
            return root.defaultToastMs;

        return Math.max(root.minToastMs, Math.min(root.maxToastMs, requested));
    }

    // =========================================================================
    // Toasts
    // =========================================================================

    function pushToast(n): void {
        const next = root.copyOf(root.toasts);

        // ---- "replace the last one like me" ---------------------------------
        // Most applications that redraw a notification do it with `replaces_id`,
        // which never reaches this function at all: the server updates the
        // notification object in place and the toast already on screen changes
        // its own text. Some ask by NAME instead, with the
        // x-canonical-private-synchronous hint — a volume popup, a brightness
        // popup, a job reporting itself. Honouring that is the difference
        // between one toast that counts up and fifteen stacked ones.
        //
        // An untagged notification never replaces anything: `progressTag`
        // returns "" and progress.js refuses to match on it. Without that rule
        // every ordinary message on the machine would replace every other one.
        const tag = root.progressTag(n);
        if (tag) {
            const tags = [];
            for (let i = 0; i < next.length; ++i)
                tags.push(root.progressTag(next[i]));

            const at = Progress.replacesIndex(tags, tag);
            if (at !== -1) {
                const replaced = next[at];
                next[at] = n;
                root.toasts = next;

                // The one it replaced is GONE — not moved to the panel.
                //
                // This is the one place the store closes a notification the
                // person did not close, and it needs its reason in writing. The
                // rule everywhere else is "silenced, never dropped". But
                // `x-canonical-private-synchronous` does not mean "quieter", it
                // means REPLACES: the sender is redrawing one message, and
                // keeping the old drafts would fill the panel with a trail of
                // "30%", "60%", "90%" — the same stack the hint exists to
                // prevent, just moved somewhere less visible.
                //
                // Done AFTER root.toasts is assigned, so the rebuild that
                // dismissing sets off reads the finished list rather than the
                // half-edited one.
                if (replaced !== n)
                    replaced.dismiss();
                return;
            }
        }

        next.push(n);

        const overflow = [];
        while (next.length > root.maxVisibleToasts)
            overflow.push(next.shift());

        root.toasts = next;

        for (let i = 0; i < overflow.length; ++i)
            root.afterToast(overflow[i]);
    }

    // The toast has left the screen — by its own clock, by being pushed off the
    // bottom, or because the person swept it away. The notification itself
    // usually stays in the panel.
    //
    // The exception is the `transient` hint, which the specification defines as
    // "show it, then forget it" — a volume popup, a caps-lock indicator. Keeping
    // those in the panel would fill it with things nobody wants a record of.
    function hideToast(n): void {
        const next = [];
        for (let i = 0; i < root.toasts.length; ++i) {
            if (root.toasts[i] !== n)
                next.push(root.toasts[i]);
        }
        root.toasts = next;
        root.afterToast(n);
    }

    function afterToast(n): void {
        if (n.transient)
            n.expire();
    }

    // The person pressed the toast's close button: that is a dismissal of the
    // whole notification, not just of the popup, and the sending application is
    // told so.
    function closeFromToast(n): void {
        n.dismiss();
    }

    function clearToasts(): void {
        root.toasts = [];
    }

    // =========================================================================
    // Grouping — GNOME 48's stacked-by-app model
    // =========================================================================
    // One header per application, newest application first, newest notification
    // first inside each. A collapsed group shows only its newest notification
    // with the rest stacked behind it; expanding shows them all.
    //
    // WHY GROUP AT ALL, WHEN THE V2 ARTBOARD DRAWS A FLAT LIST
    //   The artboard draws three notifications from three different
    //   applications, which is a flat list AND a grouped list at the same time —
    //   it does not settle the question. A real morning's messages does settle
    //   it: without grouping, one chat application buries everything else. The
    //   Wave-2 Plasma widget went flat because KDE's own history model was doing
    //   the work; here we own the model, so we can do the thing that survives
    //   contact with a real day. This is the one deliberate departure from the
    //   drawing, and it is recorded in docs/notifications.md.
    //
    // WHY THE WHOLE LIST IS REBUILT RATHER THAN PATCHED
    //   The list is a handful of items. A rebuild is a few microseconds and it
    //   cannot drift; incremental updates to a grouped list are where this kind
    //   of code goes wrong. The cost, stated plainly: rebuilding recreates the
    //   delegates, so half-typed text in an inline reply is lost when a new
    //   notification arrives. Noted in docs/notifications.md as a known rough
    //   edge with a known fix (keying the Repeater and holding reply drafts in
    //   this file).
    function groupKey(n): string {
        // The desktop-entry hint is the stable one — it survives an application
        // translating its own name. Fall back to the name, then to a constant so
        // that anonymous senders at least land together instead of each making a
        // group of one.
        if (n.desktopEntry && n.desktopEntry.length > 0)
            return n.desktopEntry;
        if (n.appName && n.appName.length > 0)
            return n.appName;
        return "unknown";
    }

    function arrivalOf(n): real {
        const at = root.arrival[n.id];
        return at === undefined ? 0 : at;
    }

    function rebuild(): void {
        const items = server.trackedNotifications.values;

        const byKey = ({});
        const order = [];

        for (let i = 0; i < items.length; ++i) {
            const n = items[i];
            const key = root.groupKey(n);

            if (byKey[key] === undefined) {
                byKey[key] = {
                    "key": key,
                    "appName": n.appName && n.appName.length > 0 ? n.appName : key,
                    "appIcon": n.appIcon,
                    "items": [],
                    "count": 0,
                    "newest": 0,
                    "expanded": root.expanded[key] === true
                };
                order.push(key);
            }

            const group = byKey[key];
            group.items.push(n);

            const at = root.arrivalOf(n);
            if (at >= group.newest) {
                group.newest = at;
                // The newest notification decides the header's icon, so a group
                // does not keep showing an icon from a message three hours ago.
                if (n.appIcon && n.appIcon.length > 0)
                    group.appIcon = n.appIcon;
            }
        }

        const built = [];
        for (let i = 0; i < order.length; ++i) {
            const group = byKey[order[i]];
            group.items.sort(function (a, b) {
                return root.arrivalOf(b) - root.arrivalOf(a);
            });
            group.count = group.items.length;
            built.push(group);
        }

        built.sort(function (a, b) {
            return b.newest - a.newest;
        });

        root.groups = built;
        root.count = items.length;
    }

    function toggleExpanded(key: string): void {
        // Rebuilt rather than poked, because changing a property of a JavaScript
        // object in place tells QML nothing and the interface would not move.
        const next = ({});
        for (const k in root.expanded)
            next[k] = root.expanded[k];
        next[key] = !(next[key] === true);

        root.expanded = next;
        root.rebuild();
    }

    // A notification is about to be destroyed. Drop every reference we hold
    // BEFORE it goes, or a Repeater will be left drawing a dead object.
    function forget(n): void {
        const nextToasts = [];
        for (let i = 0; i < root.toasts.length; ++i) {
            if (root.toasts[i] !== n)
                nextToasts.push(root.toasts[i]);
        }
        if (nextToasts.length !== root.toasts.length)
            root.toasts = nextToasts;

        // Take it out of the groups too, here and now.
        //
        // rebuild() runs a moment later (from objectRemovedPost) and produces
        // the same answer, but the order in which Quickshell emits that signal
        // and actually destroys the object is not something to rely on. A
        // Repeater still holding a delegate bound to a destroyed object is the
        // worst kind of bug to find later, and this loop makes it impossible.
        const nextGroups = [];
        for (let i = 0; i < root.groups.length; ++i) {
            const group = root.groups[i];
            const items = [];
            for (let j = 0; j < group.items.length; ++j) {
                if (group.items[j] !== n)
                    items.push(group.items[j]);
            }
            if (items.length === 0)
                continue;
            nextGroups.push({
                "key": group.key,
                "appName": group.appName,
                "appIcon": group.appIcon,
                "items": items,
                "count": items.length,
                "newest": group.newest,
                "expanded": group.expanded
            });
        }
        root.groups = nextGroups;
        root.count = Math.max(0, root.count - 1);

        delete root.arrival[n.id];
    }

    // =========================================================================
    // Things the panel asks this file to DO
    // =========================================================================

    function clearAll(): void {
        // Snapshotted first: dismissing walks the same list we would be reading.
        const items = root.copyOf(server.trackedNotifications.values);
        for (let i = 0; i < items.length; ++i)
            items[i].dismiss();

        root.toasts = [];
        root.heldBack = 0;
    }

    function clearGroup(key: string): void {
        for (let i = 0; i < root.groups.length; ++i) {
            if (root.groups[i].key !== key)
                continue;
            const items = root.copyOf(root.groups[i].items);
            for (let j = 0; j < items.length; ++j)
                items[j].dismiss();
            return;
        }
    }

    // The specification reserves the action identifier "default" for "what
    // happens when you click the notification itself" — open the folder, focus
    // the chat window. It is never drawn as a button.
    function defaultAction(n) {
        const actions = n.actions;
        for (let i = 0; i < actions.length; ++i) {
            if (actions[i].identifier === "default")
                return actions[i];
        }
        return null;
    }

    // The actions that DO get drawn as buttons.
    function buttonActions(n) {
        const out = [];
        const actions = n.actions;
        for (let i = 0; i < actions.length; ++i) {
            if (actions[i].identifier !== "default")
                out.push(actions[i]);
        }
        return out;
    }

    // Clicking the body of a notification.
    function activate(n): void {
        const action = root.defaultAction(n);
        if (action) {
            // `invoke()` closes the notification for us unless the sender asked
            // to stay resident, so there is no dismiss() here on purpose.
            action.invoke();
        } else {
            n.dismiss();
        }
    }

    // A QML `list<QtObject>` is not a JavaScript array and does not have
    // .slice(). This is that, spelled out.
    function copyOf(list) {
        const out = [];
        for (let i = 0; i < list.length; ++i)
            out.push(list[i]);
        return out;
    }
}
