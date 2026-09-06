// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// LockState — everything the lock screen knows, and the talk with PAM
// =============================================================================
// WHAT A LOCK SCREEN ACTUALLY IS, IN PLAIN ENGLISH
//
// A lock screen does not check your password, and it must not be able to. A
// program that could check passwords by itself could also be argued into saying
// yes — by a bug, by a clever input, by somebody with a debugger. So it does
// the same thing the login screen does: it HOLDS A CONVERSATION with something
// trusted that can check, and does as it is told.
//
// The trusted thing here is **PAM** — the part of Linux that owns the question
// "is this really you". Every serious lock screen on Linux (swaylock, hyprlock,
// gtklock, GNOME's own) does exactly this and nothing else.
//
// The conversation is short, and it always goes the same way:
//
//   we say      "royce would like to prove who he is"     pam.start()
//   it asks     "Password:"                               pamMessage, responseRequired
//   we answer   the typed password                        pam.respond("…")
//   it says     either "no" ...                           completed(PamResult.Failed)
//               ... or "yes"                              completed(PamResult.Success)
//
// and on "yes" we set locked = false and the desktop comes back exactly as it
// was, because nothing was ever hidden or moved — the lock is a sheet of glass
// laid over the top by the compositor, not a change to your session.
//
// -----------------------------------------------------------------------------
// WHERE THE PASSWORD IS ACTUALLY CHECKED — AND WHY IT IS NOT HERE
// -----------------------------------------------------------------------------
// `PamContext` is Quickshell's front door to PAM, and the important part is
// what it does behind that door: it FORKS A SEPARATE LITTLE PROCESS and the
// whole PAM conversation happens in there, talking to this one over a pipe.
// The check does not happen in QML, it does not happen in the shell's process,
// and no part of this file ever sees a password hash or compares anything.
//
// That separate process is the "small helper with its own pam.d file" that
// every other Linux lock screen ships. We do not have to write one: the
// runtime already has it, it is written in C against libpam, and it is the same
// shape swaylock and hyprlock use. Writing a second one would mean a second
// piece of security-critical C to keep correct, for no gain.
//
// The rules it follows are a file the OPERATING SYSTEM installs:
//
//     /etc/pam.d/aquarius-lock
//
// That file is one line long and it says "use this machine's ordinary login
// rules" — so a password change, a fingerprint reader, a company policy or a
// smart card all apply to the lock screen automatically, because they are
// changes to that one shared set of rules and not to us. The whole path is
// written out in plain language in docs/lock-screen.md.
//
// ⚠️ If that file is missing, `pam.start()` returns false rather than hanging,
// and we say so on screen. A lock screen that silently ignores Enter is
// indistinguishable from a frozen computer.
//
// -----------------------------------------------------------------------------
// THE ONE THING THAT IS EASY TO GET WRONG
// -----------------------------------------------------------------------------
// A person walks up to a locked machine and starts typing IMMEDIATELY, before
// the card has finished appearing. Those first characters must not be lost.
//
// They are not, and the trick is duller than it sounds: the password box
// EXISTS from the moment the screen locks. In the calm state it is simply not
// drawn — the card is at zero opacity — but it still holds the keyboard, so
// every keystroke lands in it exactly as it would have. `answer` below is that
// text, held here rather than in the box, because on a two-monitor machine
// there is a box per screen and there is only ever one password.
//
// -----------------------------------------------------------------------------
// WHY THIS IS A SINGLETON
// -----------------------------------------------------------------------------
// One machine, one lock, one password being typed. See lock/qmldir.
// =============================================================================
pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Only for the two waits below — the ten seconds after three wrong passwords
// and the thirty after which the card puts itself away. They live in Theme with
// every other number the lock screen uses, so there is one place to change them
// when the Settings page that owns them properly is written.
import "../theme"

Singleton {
    id: root

    // =========================================================================
    // THE THREE STATES
    // =========================================================================
    // Written as strings rather than a QML enum on purpose: an enum declared in
    // a singleton has to be reached through the singleton's own name anyway
    // (`LockState.Phase.Calm`), which is longer to write and one more capitalised
    // name for tests/test-shell.sh section 28 to have to know about. A string
    // compares the same, prints usefully in a log, and cannot be undefined.
    //
    //   calm      the veil, the clock, and nothing to do. What you see when you
    //             walk up to the machine.
    //   password  the card is up and the box has the keyboard.
    //   wrong     the same card, having just said no.
    readonly property string calm: "calm"
    readonly property string password: "password"
    readonly property string wrong: "wrong"

    // =========================================================================
    // WHAT IS TRUE RIGHT NOW
    // =========================================================================

    // The one switch. LockLayer.qml binds the session lock to this, so setting
    // it is what actually covers the screens.
    property bool locked: false

    // Which of the three states above.
    property string phase: root.calm

    // What has been typed. THE box shows this; it does not own it. See the note
    // about typing early, above.
    property string answer: ""

    // The line under the password box. PAM's own words wherever PAM has any,
    // ours only where it does not.
    property string status: ""
    property bool statusIsError: false

    // True from pressing Enter until PAM answers. Everything on the card goes
    // quiet, because pressing Enter twice must not start two conversations.
    property bool busy: false

    // Wrong passwords in a row, and the wait that follows the third.
    property int misses: 0
    property int waitLeft: 0
    readonly property bool waiting: root.waitLeft > 0

    // Who is being asked. Filled in once, at start-up, by the same little
    // program the login screen uses — see the bottom of this file.
    property string userName: {
        const value = Quickshell.env("USER");
        return (value === null || value === undefined) ? "" : String(value);
    }
    property string realName: ""

    // The shape GreeterAvatar reads: { name, real, icon }. Reusing that
    // component is the point — the face on the lock screen and the face on the
    // login screen are the same face.
    readonly property var person: ({
        name: root.userName,
        real: root.realName.length > 0 ? root.realName : root.userName,
        icon: ""
    })

    // Set by the shell so the calm state can say how many notifications are
    // waiting. A COUNT AND NOTHING ELSE — never a title, never a body, never an
    // app name. See docs/lock-screen.md.
    property int notificationCount: 0
    property bool showNotificationCount: true

    // Which screen the mouse pointer is on, by name, so the card can be drawn
    // there rather than always on the first monitor. Empty until the pointer
    // moves; LockSurface falls back to the first screen until then.
    property string pointerScreen: ""

    function pointerOn(name: string): void {
        root.pointerScreen = name;
    }

    // Raised when the box should be emptied and given the keyboard again.
    signal answerWanted()

    // =========================================================================
    // WHAT ANYTHING OUTSIDE CALLS
    // =========================================================================

    // Lock the machine. Called by the Super+L key binding (through the IPC door
    // in LockLayer.qml), by the Aquarius menu's "Lock Screen" row, and by the
    // idle watcher after ten minutes of nobody touching anything.
    function lock(): void {
        if (root.locked)
            return;
        root.forget();
        root.locked = true;
        root.phase = root.calm;
        root.say(qsTr("Password"), false);
    }

    // Let go. Only ever called after PAM has said yes.
    function unlock(): void {
        root.forget();
        root.locked = false;
    }

    // Something happened — a key, a click. Bring the card up.
    function wake(): void {
        if (!root.locked || root.phase !== root.calm)
            return;
        root.phase = root.password;
        root.say(qsTr("Password"), false);
        root.answerWanted();
    }

    // Escape, or thirty seconds of nothing. Put the card away and DROP whatever
    // was typed — a half-typed password left sitting behind a fading card is a
    // password on a screen anybody can walk up to.
    function backToCalm(): void {
        if (!root.locked || root.busy)
            return;
        root.answer = "";
        root.pendingAnswer = "";
        root.hasPendingAnswer = false;
        root.phase = root.calm;
        root.say(qsTr("Password"), false);
    }

    // The box was typed into. Every screen's box reports here, so that the one
    // that has the keyboard and the one that is drawn do not have to be the
    // same one — which on a two-monitor machine they may well not be.
    function type(text: string): void {
        root.answer = text;
        root.wake();
    }

    // Enter was pressed.
    function submit(): void {
        if (!root.locked || root.busy || root.waiting)
            return;
        if (root.answer.length === 0)
            return;   // an empty Enter is not a wrong password; it is nothing.

        // Put the typed password aside and empty the box in the same breath.
        root.pendingAnswer = root.answer;
        root.hasPendingAnswer = true;
        root.answer = "";
        root.answerWanted();

        root.busy = true;
        root.say(qsTr("Checking…"), false);

        if (pam.active) {
            // A conversation is already open and waiting for an answer.
            root.deliver();
            return;
        }

        // ⚠️ start() returns FALSE rather than throwing when the rules file is
        // missing or unreadable. Saying so is the difference between a lock
        // screen that explains itself and a computer that appears to be dead.
        if (!pam.start()) {
            root.busy = false;
            root.pendingAnswer = "";
            root.hasPendingAnswer = false;
            root.say(qsTr("This computer cannot check passwords right now."), true);
            console.warn("aquarius-lock: PAM would not start. Is /etc/pam.d/"
                         + pam.config + " installed and readable?");
        }
    }

    // =========================================================================
    // THE CONVERSATION
    // =========================================================================
    // The password typed before PAM got round to asking for it. Same idea as
    // the login screen's, and cleared the instant it is used or the attempt
    // ends, so it is never left lying about in memory longer than one Enter.
    property string pendingAnswer: ""
    property bool hasPendingAnswer: false

    function deliver(): void {
        if (!root.hasPendingAnswer || !pam.responseRequired)
            return;
        const answer = root.pendingAnswer;
        root.pendingAnswer = "";
        root.hasPendingAnswer = false;
        pam.respond(answer);
    }

    function say(words: string, isProblem: bool): void {
        root.status = words;
        root.statusIsError = isProblem;
    }

    // Everything back to how it was when the screen locked.
    function forget(): void {
        root.answer = "";
        root.pendingAnswer = "";
        root.hasPendingAnswer = false;
        root.busy = false;
        root.misses = 0;
        root.waitLeft = 0;
        root.phase = root.calm;
        root.status = "";
        root.statusIsError = false;
        if (pam.active)
            pam.abort();
    }

    PamContext {
        id: pam

        // The rules the operating system installs for us. NOT "login" (the
        // default), which is the rules for a fresh login on a text console and
        // is the wrong question to be asking about somebody who is already
        // logged in and standing at the machine.
        config: "aquarius-lock"

        // Written out even though it is the default, because the default is
        // only the default until somebody reads this file and wonders.
        configDirectory: "/etc/pam.d"

        // `user` is deliberately left unset. PamContext then asks the system
        // who this process belongs to and uses that — which is exactly right,
        // and stronger than us passing a name in: this shell can only ever ask
        // PAM about the person whose session it is running in.

        // PAM said something. It only ever waits on us when it is asking a
        // question; anything it is merely telling us it handles by itself.
        onPamMessage: {
            if (!pam.responseRequired) {
                if (pam.message.length > 0)
                    root.say(pam.message, pam.messageIsError);
                return;
            }

            // A question whose answer is NOT secret — a code from a phone, say.
            // This screen has one box and it draws dots in it, so there is
            // nothing honest to do with a visible question yet. Say so rather
            // than showing somebody's code as bullets.
            if (pam.responseVisible) {
                root.busy = false;
                root.pendingAnswer = "";
                root.hasPendingAnswer = false;
                root.say(pam.message.length > 0
                         ? pam.message
                         : qsTr("This computer is asking for something the lock screen cannot show yet."),
                         true);
                pam.abort();
                return;
            }

            if (root.hasPendingAnswer) {
                root.deliver();
                return;
            }

            // PAM asked before anything was typed. Wait for Enter.
            root.busy = false;
            root.say(qsTr("Password"), false);
            root.answerWanted();
        }

        // The answer.
        onCompleted: result => {
            root.busy = false;
            root.pendingAnswer = "";
            root.hasPendingAnswer = false;

            if (result === PamResult.Success) {
                root.unlock();
                return;
            }

            root.misses = root.misses + 1;
            root.phase = root.wrong;
            root.answerWanted();

            if (result === PamResult.MaxTries) {
                // PAM itself has stopped answering. Ours is not the wait that
                // matters any more; say what happened.
                root.say(qsTr("This computer has stopped accepting tries for now."), true);
            } else if (result === PamResult.Error) {
                root.say(qsTr("Something went wrong while checking. Try again."), true);
            } else {
                root.say(qsTr("That password isn't right. Try again."), true);
            }

            // The third miss in a row buys a wait, counted down in the same
            // line. It is not a security measure — PAM has its own, and they
            // are better — it is a pause, so that somebody leaning on a
            // keyboard cannot hammer the box.
            if (root.misses >= 3) {
                root.misses = 0;
                root.waitLeft = Theme.lockWaitSeconds;
            }
        }

        // Something went wrong with the conversation itself rather than with
        // the password. A `completed(PamResult.Error)` follows, which is where
        // the screen is put right; this only writes it down.
        onError: problem => {
            console.warn("aquarius-lock: PAM error", PamError.toString(problem));
        }
    }

    // The countdown after three wrong passwords.
    Timer {
        running: root.waitLeft > 0
        interval: 1000
        repeat: true
        onTriggered: {
            root.waitLeft = root.waitLeft - 1;
            if (root.waitLeft > 0)
                root.say(qsTr("Wait %1 seconds and try again.").arg(root.waitLeft), true);
            else
                root.say(qsTr("Password"), false);
        }
        onRunningChanged: {
            if (running)
                root.say(qsTr("Wait %1 seconds and try again.").arg(root.waitLeft), true);
        }
    }

    // The card puts itself away if you wake the screen and then walk off, so
    // that a half-typed password does not sit there until somebody comes back.
    Timer {
        running: root.locked && root.phase !== root.calm && !root.busy
                 && root.answer.length === 0 && !root.waiting
        interval: Theme.lockCalmBackSeconds * 1000
        repeat: false
        onTriggered: root.backToCalm()
    }

    // =========================================================================
    // WHOSE NAME IS ON THE CARD
    // =========================================================================
    // The same little program the login screen reads, asked once, at start-up.
    // It prints every account on the machine; we keep the one that is us.
    //
    // If it is missing — on a developer's Mac, in the nested harness, on a
    // plain Fedora clone — nothing breaks: the card falls back to the login
    // name from the environment, which is always there. A lock screen must
    // never depend on a nicety.
    Process {
        id: reader

        running: true
        command: ["/usr/libexec/aquarius-greeter-info"]

        stdout: StdioCollector {
            id: sink

            onStreamFinished: root.absorb(sink.text)
        }
    }

    function absorb(text: string): void {
        let data = null;
        try {
            data = JSON.parse(text);
        } catch (problem) {
            data = null;
        }
        if (data === null || !Array.isArray(data.people))
            return;

        for (let i = 0; i < data.people.length; i++) {
            if (data.people[i].name === root.userName) {
                root.realName = String(data.people[i].real || "");
                return;
            }
        }
    }
}
