// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SettingsLauncher — the one place the shell opens the Settings app
// =============================================================================
// THE BUG THIS FILE EXISTS TO KILL
//
//   Found on the bench on 2026-09-06, by Royce, in one sentence:
//
//     "System Settings still doesn't open. Nor does its icon in the dock.
//      About This PC also doesn't work. Quick settings arrows are there but
//      don't open into settings."
//
//   Every one of those is the same failure, and none of them is in this shell's
//   code. The Settings app on AquariusOS is GNOME's — `gnome-control-center` —
//   and that program refuses to start unless it believes it is running inside
//   GNOME. Its own source does the checking (shell/cc-application.c, the
//   function `is_supported_desktop()`, called from
//   `cc_application_handle_local_options()`): it reads the environment variable
//   XDG_CURRENT_DESKTOP, splits it on colons, and unless one of the names is
//   "GNOME" or "Unity" it prints
//
//       Running gnome-control-center is only supported under GNOME and Unity,
//       exiting
//
//   and exits with status 1. That is the whole story. The launch happened, the
//   process started, and it was gone again before a window could exist. Nothing
//   appeared on screen and nothing was written anywhere the person could see,
//   because a program that exits immediately after being launched detached
//   leaves no trace in the session log.
//
// WHAT XDG_CURRENT_DESKTOP IS SET TO HERE, AND WHY IT STAYS THAT WAY
//
//   The Aquarius session sets it deliberately (../session/aquarius-session):
//
//       XDG_CURRENT_DESKTOP=aquarius-labwc:aquarius:wlroots     (on labwc)
//       XDG_CURRENT_DESKTOP=aquarius-niri:aquarius:niri         (on niri)
//
//   That line is LOAD-BEARING and must not be changed to say GNOME. It is how
//   xdg-desktop-portal decides which back end answers a screen-recording or
//   file-dialog request: the portal takes each colon-separated name in turn and
//   looks for `<name>-portals.conf`, which is exactly how
//   ../session/portals/aquarius-labwc-portals.conf gets found. Rename the
//   variable and OBS silently shows no screens to record, and the file dialog in
//   a Flatpak silently never appears. The `aquarius` names in there are the keys
//   those files are named after; they are a mechanism, not a label.
//
//   So the fix cannot be session-wide. It has to be PER LAUNCH: the one program
//   that insists on the GNOME name gets told GNOME, and nothing else on the
//   machine hears about it.
//
//       env XDG_CURRENT_DESKTOP=GNOME gnome-control-center [panel]
//
//   `env` is the standard POSIX program that runs another program with an
//   altered environment. The change lives and dies with that one process; the
//   session's own variable is untouched. This is not a trick we invented — it is
//   what sway, labwc and Hyprland users have done for years for exactly this
//   program, for exactly this reason.
//
// WHY IT IS A SINGLETON AND NOT A LINE IN EACH FILE
//
//   Before this file there were five copies of that launch, in five files: the
//   Aquarius menu's "About This PC" and "System Settings", and the Wi-Fi,
//   Bluetooth and Performance chevrons in Quick Settings. Five copies of a fact
//   about somebody else's program is five places to forget when the fact
//   changes — and it will change, because the shell will eventually have its own
//   Settings app and every one of these will point there instead. One singleton
//   means that day is a one-file edit, and it means a fix like this one cannot
//   be applied to four callers out of five.
//
//   The one place that still writes the command out longhand is the desktop's
//   right-click menu, ../session/labwc/menu.xml — that menu is drawn by labwc
//   from an XML file and cannot call into QML at all. It carries its own copy of
//   the env prefix and a comment saying so.
//
// WHAT THIS DOES NOT FIX — the honest part
//
//   Getting gnome-control-center to START is not the same as getting every page
//   inside it to WORK. Some of its panels talk to pieces of GNOME that are not
//   running in an Aquarius session: Displays wants Mutter's own display
//   configuration interface, Keyboard shortcuts and Multitasking want the GNOME
//   shell and gnome-settings-daemon. On labwc those pages will open empty, show
//   an error, or offer settings that change nothing. The pages this shell
//   actually sends people to — Wi-Fi, Bluetooth, Power, About — are backed by
//   NetworkManager, BlueZ, UPower/power-profiles-daemon and plain system
//   information, all of which are running, so those are the ones expected to be
//   right.
//
//   That gap is not a bug in this file. It is the reason AquariusOS is meant to
//   grow its own Settings app (R6 work), and borrowing GNOME's is the interim.
//
// THE SECOND HALF, FOUND ON THE SAME BENCH THE FOLLOWING RUN
//
//   With the env prefix in place every one of those clicks opened the Settings
//   app — and "About This PC" opened it on the SYSTEM panel's front page, which
//   is a list of rows, one of which says About. That is not what the item says
//   it does. gnome-control-center takes a PAGE INSIDE a panel as a second
//   command-line word (`gnome-control-center system about`), so `open()` below
//   takes an optional list of parameters and the menu asks for that page by
//   name. The full paper trail — the three functions in that app's own source
//   that carry the word from the command line to the page — is on `open()`.
//
// NOT PROVEN. No QML engine has run this file. It is checked statically by
// tests/test-shell.sh section 34b and will be exercised on the bench.
// =============================================================================
pragma Singleton

import QtQuick

import Quickshell

Singleton {
    id: root

    // The front half of every Settings launch, kept as a named property rather
    // than written inline at the call, so the one fact this file exists to hold
    // is a thing you can see at a glance and a thing a test can point at. Read
    // it as a sentence: "run gnome-control-center, and while it runs, let
    // XDG_CURRENT_DESKTOP say GNOME."
    readonly property var argvPrefix: [
        "env",
        "XDG_CURRENT_DESKTOP=GNOME",
        "gnome-control-center"
    ]

    // The names GNOME's Settings app answers to in the application menu. A
    // .desktop file's id is what a launcher — the dock, the search palette —
    // has in its hand when somebody clicks the Settings icon, and clicking that
    // icon hits exactly the same wall as everything else here: the desktop entry
    // runs `gnome-control-center`, which reads XDG_CURRENT_DESKTOP and exits.
    //
    // Two spellings because both are real. Modern GNOME ships
    // org.gnome.Settings.desktop; older packages, and some distributions, still
    // ship gnome-control-center.desktop. Matching is case-insensitive and
    // ignores a trailing ".desktop", because a desktop entry id is written both
    // ways in the wild (see the dock's own dock.json, which accepts either).
    readonly property var desktopEntryIds: [
        "org.gnome.settings",
        "gnome-control-center"
    ]

    // "Is this desktop entry the Settings app?" — asked by anything that would
    // otherwise launch an entry the ordinary way, so the one fact about
    // gnome-control-center stays in this file instead of being copied into the
    // dock. Answering false is always safe: the caller launches the entry
    // normally, which is right for every other program on the machine.
    function ownsDesktopEntry(entry): bool {
        if (entry === null || entry === undefined)
            return false;

        const raw = (entry.id === null || entry.id === undefined)
            ? "" : String(entry.id);
        const id = raw.toLowerCase().replace(/\.desktop$/, "");

        for (let i = 0; i < root.desktopEntryIds.length; i++) {
            if (id === root.desktopEntryIds[i])
                return true;
        }
        return false;
    }

    // Open the Settings app: a panel, and optionally a page INSIDE that panel.
    //
    //   open("")                     the app, wherever it opens by default
    //   open("wifi")                 the Wi-Fi panel
    //   open("bluetooth")            the Bluetooth panel
    //   open("power")                the Power panel
    //   open("system")               the System panel, on its own front page
    //   open("system", ["about"])    the System panel, ALREADY ON About
    //
    // THE SHAPE OF THE API, AND WHY IT IS TWO ARGUMENTS RATHER THAN ONE STRING
    //
    //   `open("system about")` would have read a little shorter, and it is the
    //   thing you would type in a terminal. It is the wrong shape here, because
    //   this function does not run a shell: it hands `execDetached` a LIST of
    //   arguments, and a list has to be built by somebody. Splitting a string on
    //   spaces to build it means every caller's argument is silently reshaped by
    //   its own whitespace, and the day a value legitimately contains a space
    //   the split quietly produces two arguments and the wrong page opens. Two
    //   parameters — a panel, and a list — is exactly the shape of the argv that
    //   comes out the other end, so nothing is parsed and nothing can be
    //   misparsed. `parameters` is optional; leaving it off is the whole of the
    //   old one-argument behaviour, which is why every existing caller is
    //   unchanged.
    //
    // WHERE "system" AND "about" COME FROM — read out of the app's own source
    //
    //   The FIRST word after the program name is the panel id, and everything
    //   after it is passed on to that panel. gnome-control-center says so
    //   itself. In shell/cc-application.c, `cc_application_command_line()` takes
    //   the leftover command-line words and does this:
    //
    //       start_id = start_panels[0];
    //       g_variant_builder_init (&builder, G_VARIANT_TYPE ("av"));
    //       for (i = 1; start_panels[i] != NULL; i++)
    //         g_variant_builder_add (&builder, "v",
    //                                g_variant_new_string (start_panels[i]));
    //       parameters = g_variant_builder_end (&builder);
    //       ...
    //       cc_window_set_active_panel_from_id (self->window, start_id,
    //                                           parameters, &err)
    //
    //   — word 0 is the panel, words 1..n become an array of strings called
    //   `parameters`. Its own `--help` text says the same in one line:
    //   `N_("[PANEL] [ARGUMENT…]")`.
    //
    //   That array then reaches the panel. shell/cc-window.c's
    //   `set_active_panel_from_id()` (called by
    //   `cc_window_set_active_panel_from_id`) ends with
    //
    //       g_object_set (G_OBJECT (self->current_panel), "parameters",
    //                     parameters, NULL);
    //
    //   and shell/cc-panel.c handles that property in `cc_panel_set_property()`,
    //   case PROP_PARAMETERS:
    //
    //       g_variant_get_child (parameters, 0, "v", &v);
    //       if (g_variant_is_of_type (v, G_VARIANT_TYPE_STRING))
    //         set_subpage (CC_PANEL (object), g_variant_get_string (v, NULL));
    //
    //   — the FIRST parameter, if it is a string, is the name of a SUBPAGE to
    //   open. `set_subpage()` looks that name up among the panel's pages and,
    //   failing, warns `Invalid subpage: '%s'` and stays on the front page. So a
    //   wrong name costs the wrong page and never a crash, exactly as a wrong
    //   panel id does.
    //
    //   And the System panel registers its subpages by name in
    //   panels/system/cc-system-panel.c, in `cc_system_panel_init()`:
    //
    //       cc_panel_add_static_subpage (CC_PANEL (self), "about", ...);
    //       cc_panel_add_static_subpage (CC_PANEL (self), "datetime", ...);
    //       cc_panel_add_static_subpage (CC_PANEL (self), "region", ...);
    //       cc_panel_add_static_subpage (CC_PANEL (self), "remote-desktop", ...);
    //       cc_panel_add_static_subpage (CC_PANEL (self), "users", ...);
    //
    //   Which is why "About This PC" asks for `system` `about` and lands on the
    //   About page itself, rather than on the System panel's front page with a
    //   row called About that still has to be clicked. (Bench, Royce,
    //   2026-09-06: About This PC opened Settings, but not the About page.)
    //
    //   Panel ids are stable across GNOME versions and
    //   `gnome-control-center --list` prints the full set on any machine that
    //   has it. Subpage names are NOT printed by anything — they are only in
    //   that source file — so the five above are written down here rather than
    //   left to be rediscovered.
    //
    // execDetached, not Process, for the same reason every other launch in this
    // shell uses it: the launched program has to outlive a shell reload, and
    // nothing here wants to own its lifetime. It is a launch, not the kind of
    // system-control shell-out tests/test-shell.sh section 22 guards.
    function open(panel: string, parameters: var): void {
        // slice() so the shared prefix is copied rather than appended to. Push
        // onto the property itself and the second launch would ask for
        // "gnome-control-center wifi bluetooth".
        const argv = root.argvPrefix.slice();

        if (panel !== undefined && panel !== null && String(panel) !== "")
            argv.push(String(panel));

        // A parameter without a panel in front of it would be read by
        // gnome-control-center as the PANEL — word 0 is the panel id, always —
        // so a caller that passes parameters and no panel would silently open
        // some other page. Dropping them is the safe half of that mistake, and
        // saying so is better than doing it quietly.
        if (parameters !== undefined && parameters !== null
                && parameters.length !== undefined && parameters.length > 0) {
            if (argv.length === root.argvPrefix.length) {
                console.warn("aquarius-shell: SettingsLauncher.open was given"
                             + " parameters with no panel; ignoring them");
            } else {
                for (let i = 0; i < parameters.length; i++) {
                    const one = parameters[i];
                    if (one !== undefined && one !== null && String(one) !== "")
                        argv.push(String(one));
                }
            }
        }

        Quickshell.execDetached(argv);
    }
}
