// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// SearchEngine — what the Flow Search box actually knows how to find
// =============================================================================
// This object holds no interface at all. You set `query`, you read `results`,
// and you call `activate()` on the one you want. FlowSearch.qml draws it.
//
// THE PROVIDERS, AND THE ONES DELIBERATELY MISSING
//   The V2 design's footnote reads "apps · files · settings · math · actions".
//   Three of those five are real today and two are not, and this file ships the
//   three:
//
//     apps     DesktopEntries — the index of every installed .desktop file.
//              Real, standardised, and already used by the top bar.
//     math     calc.js. Real, and entirely ours.
//     actions  A fixed list of session commands run through loginctl and
//              systemctl. Real, but INTERIM — see the note above them.
//
//   NOT here, and not faked:
//
//     files    Would need an index. Nothing in this shell indexes anything,
//              and shelling out to `find` on every keystroke is not a file
//              search, it is a way to heat a laptop. A real provider means a
//              real indexer (Tracker's D-Bus interface is the obvious candidate
//              since it is already on a Fedora desktop) and that is P3 work.
//     settings A settings app has to exist before it can be searched. It does
//              not. That is P3 too.
//     web      Not a provider. Typing into a desktop search box should never
//              quietly become a network request.
//
//   Every one of those is a row we could have drawn with fake data in an hour.
//   docs/flow-search.md says why we did not, and the roadmap says when they land.
//
// THE SHAPE OF A RESULT
//   Each entry in `results` is a plain JavaScript object:
//
//     kind       "app" | "math" | "action"   — what activate() will do with it
//     title      the bold line
//     subtitle   the quiet line under it
//     hint       the right-hand key cap: "↵ open", "↵ copy", "↵ run"
//     monogram   two letters, drawn when there is no icon (the design's tiles)
//     iconSource an image URL from the system icon theme, or "" for none
//     glyph      a single character drawn instead of an icon, or ""
//     tint       "accent" | "success" | "warn" | "ink" — a THEME ROLE NAME, not
//                a colour. ResultRow.qml turns it into one. No colour value
//                ever appears in this file.
//     confirm    true if activating it needs a second Enter (see FlowSearch)
//     score      how well it matched; only used for sorting
//     entry      the DesktopEntry, for apps
//     command    the argv list, for actions
//     value      the answer as text, for math
// =============================================================================
import QtQuick

import Quickshell
import Quickshell.Io

import "fuzzy.js" as Fuzzy
import "calc.js" as Calc

QtObject {
    id: root

    // ---- what the person typed ---------------------------------------------
    property string query: ""

    // The palette shows a short list on purpose. A launcher that fills the
    // screen with near-misses is one you have to read instead of one you can
    // glance at.
    property int maxResults: 8

    // Session actions never appear on a one-letter query. "l" should not put
    // "Log out" on screen next to your text editor.
    property int minimumActionQuery: 2

    // ---- what it found -------------------------------------------------------
    // A binding, not a stored list: it re-runs whenever `query` changes AND
    // whenever the set of installed applications changes, because both are read
    // while it evaluates.
    readonly property var results: root.build(root.query)

    // =========================================================================
    // Session actions — INTERIM, and this is the honest note about them
    // =========================================================================
    // These shell out to `loginctl` and `systemctl`. That is not the eventual
    // design. A desktop should ask logind over D-Bus, and Quickshell has no
    // logind service in 0.3.1, so the choice was between running the same two
    // commands every other desktop's fallback path runs, or shipping no session
    // actions at all.
    //
    // What makes it acceptable as an interim: `loginctl` and `systemctl` are
    // systemd's own front doors, present on every system this OS can run on,
    // and they talk to exactly the D-Bus interfaces we would otherwise call
    // ourselves. What makes it interim: spawning a process per click is slower,
    // gives worse errors, and cannot tell us whether the action is even allowed
    // before offering it. Replace it when a logind binding exists. Tracked in
    // docs/flow-search.md.
    //
    // Logging out needs the session's own id. systemd puts it in the
    // environment as XDG_SESSION_ID. If it is not there we do not guess and we
    // do not offer the action — a "Log out" that logs the wrong session out, or
    // nothing out, is worse than a missing row.
    readonly property string sessionId: {
        const value = Quickshell.env("XDG_SESSION_ID");
        return (value === null || value === undefined) ? "" : String(value);
    }

    readonly property var sessionActions: {
        const actions = [];

        actions.push({
            key: "lock",
            title: qsTr("Lock screen"),
            subtitle: qsTr("System action · loginctl"),
            keywords: ["lock", "screen", "secure", "away"],
            glyph: "⏻",
            tint: "warn",
            confirm: false,
            command: root.sessionId === ""
                ? ["loginctl", "lock-session"]
                : ["loginctl", "lock-session", root.sessionId]
        });

        if (root.sessionId !== "") {
            actions.push({
                key: "logout",
                title: qsTr("Log out"),
                subtitle: qsTr("System action · ends this session"),
                keywords: ["log out", "logout", "sign out", "exit", "session"],
                glyph: "⏻",
                tint: "warn",
                confirm: true,
                command: ["loginctl", "terminate-session", root.sessionId]
            });
        }

        actions.push({
            key: "suspend",
            title: qsTr("Suspend"),
            subtitle: qsTr("System action · sleep"),
            keywords: ["suspend", "sleep", "standby"],
            glyph: "⏻",
            tint: "warn",
            confirm: false,
            command: ["systemctl", "suspend"]
        });

        actions.push({
            key: "restart",
            title: qsTr("Restart"),
            subtitle: qsTr("System action · reboot the machine"),
            keywords: ["restart", "reboot"],
            glyph: "⏻",
            tint: "danger",
            confirm: true,
            command: ["systemctl", "reboot"]
        });

        actions.push({
            key: "poweroff",
            title: qsTr("Power off"),
            subtitle: qsTr("System action · shut the machine down"),
            keywords: ["power off", "poweroff", "shut down", "shutdown", "halt"],
            glyph: "⏻",
            tint: "danger",
            confirm: true,
            command: ["systemctl", "poweroff"]
        });

        return actions;
    }

    // The one process this component owns. `exec()` replaces whatever was
    // running, which is fine because every command here returns immediately.
    // stderr is collected rather than discarded so that a refused action leaves
    // a trace in `qs log` instead of silently doing nothing — which is the
    // single most likely failure on the bench.
    property Process runner: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0)
                    console.warn("aquarius-shell: session action said:", this.text.trim());
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("aquarius-shell: session action exited with", exitCode);
        }
    }

    // =========================================================================
    // Building the list
    // =========================================================================
    function build(rawQuery: string): var {
        const trimmed = (rawQuery || "").trim();
        if (trimmed.length === 0)
            return [];

        const apps = root.appResults(trimmed);
        const actions = root.actionResults(trimmed);
        const math = root.mathResult(trimmed);

        // Where the sum goes. If what you typed STARTS like arithmetic — a
        // digit, a bracket, a sign, a decimal point — then the sum is the thing
        // you asked for and belongs at the top. If it only happens to also parse
        // as arithmetic, the apps you were probably looking for come first.
        const out = [];
        const mathFirst = math !== null && root.looksLikeSum(trimmed);

        if (mathFirst)
            out.push(math);

        for (let i = 0; i < apps.length; i++)
            out.push(apps[i]);

        if (math !== null && !mathFirst)
            out.push(math);

        for (let j = 0; j < actions.length; j++)
            out.push(actions[j]);

        return out.slice(0, root.maxResults);
    }

    function looksLikeSum(text: string): bool {
        const first = text.charAt(0);
        return (first >= "0" && first <= "9")
            || first === "("
            || first === "."
            || first === "-"
            || first === "+";
    }

    // ---- apps ----------------------------------------------------------------
    function appResults(trimmed: string): var {
        const entries = DesktopEntries.applications.values;
        const scored = [];

        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            if (!entry || entry.noDisplay)
                continue;

            const score = root.scoreEntry(entry, trimmed);
            if (score < 0)
                continue;

            const name = entry.name || entry.id || "";

            scored.push({
                kind: "app",
                title: name,
                subtitle: entry.genericName || entry.comment || "",
                hint: qsTr("↵ open"),
                monogram: root.monogram(name),
                iconSource: entry.icon ? Quickshell.iconPath(entry.icon, true) : "",
                glyph: "",
                tint: "ink",
                confirm: false,
                score: score,
                entry: entry,
                command: [],
                value: ""
            });
        }

        scored.sort(function (a, b) {
            if (b.score !== a.score)
                return b.score - a.score;
            return a.title.localeCompare(b.title);
        });

        return scored;
    }

    // Which parts of a .desktop file are worth matching against, and how much
    // each is worth. The name is what people type; everything else is a way to
    // find something whose name you have forgotten.
    function scoreEntry(entry, trimmed: string): int {
        const fields = [];

        fields.push({ text: entry.name || "", weight: 1.0 });

        if (entry.genericName)
            fields.push({ text: entry.genericName, weight: 0.7 });

        const keywords = entry.keywords || [];
        for (let i = 0; i < keywords.length; i++)
            fields.push({ text: keywords[i], weight: 0.65 });

        if (entry.id)
            fields.push({ text: entry.id, weight: 0.6 });

        // The long description matches weakly. It is how "edit video" reaches
        // an editor that never says "video" in its name — and it is weak so it
        // cannot outrank something you nearly spelled.
        if (entry.comment)
            fields.push({ text: entry.comment, weight: 0.5 });

        return Fuzzy.bestScore(fields, trimmed);
    }

    // "Kdenlive" -> "Kd". The design's icon tiles, used whenever the system icon
    // theme has nothing for this application.
    function monogram(name: string): string {
        const clean = (name || "").trim();
        if (clean.length === 0)
            return "?";
        if (clean.length === 1)
            return clean.charAt(0).toUpperCase();
        return clean.charAt(0).toUpperCase() + clean.charAt(1).toLowerCase();
    }

    // ---- math ----------------------------------------------------------------
    function mathResult(trimmed: string): var {
        const sum = Calc.evaluate(trimmed);
        if (!sum.ok)
            return null;

        return {
            kind: "math",
            title: sum.text,
            subtitle: qsTr("%1 · press Enter to copy").arg(sum.expression),
            hint: qsTr("↵ copy"),
            monogram: "",
            iconSource: "",
            glyph: "=",
            tint: "success",
            confirm: false,
            score: 1000,
            entry: null,
            command: [],
            value: sum.text
        };
    }

    // ---- session actions ------------------------------------------------------
    function actionResults(trimmed: string): var {
        if (trimmed.length < root.minimumActionQuery)
            return [];

        const scored = [];
        const actions = root.sessionActions;

        for (let i = 0; i < actions.length; i++) {
            const action = actions[i];
            const fields = [{ text: action.title, weight: 1.0 }];

            for (let k = 0; k < action.keywords.length; k++)
                fields.push({ text: action.keywords[k], weight: 0.8 });

            const score = Fuzzy.bestScore(fields, trimmed);
            if (score < 0)
                continue;

            scored.push({
                kind: "action",
                title: action.title,
                subtitle: action.subtitle,
                hint: action.confirm ? qsTr("↵↵ confirm") : qsTr("↵ run"),
                monogram: "",
                iconSource: "",
                glyph: action.glyph,
                tint: action.tint,
                confirm: action.confirm,
                score: score,
                entry: null,
                command: action.command,
                value: ""
            });
        }

        scored.sort(function (a, b) { return b.score - a.score; });
        return scored;
    }

    // =========================================================================
    // Doing the thing
    // =========================================================================
    // Returns true if something happened. FlowSearch closes the palette on true
    // and leaves it open on false, so a result that cannot run does not make the
    // box vanish as though it had.
    function activate(result): bool {
        if (!result)
            return false;

        if (result.kind === "app") {
            if (!result.entry)
                return false;
            // DesktopEntry.execute() is Quickshell.execDetached() with the
            // entry's own parsed command and working directory — so the app
            // outlives a shell reload, which a launched app must.
            result.entry.execute();
            return true;
        }

        if (result.kind === "action") {
            if (!result.command || result.command.length === 0)
                return false;
            root.runner.exec({ command: result.command });
            return true;
        }

        if (result.kind === "math") {
            // Writing the clipboard only works while one of our windows holds
            // focus. The palette does, right up until this call returns, which
            // is exactly why the copy happens here and not after closing.
            Quickshell.clipboardText = result.value;
            return true;
        }

        return false;
    }
}
