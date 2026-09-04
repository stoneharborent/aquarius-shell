// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
// =============================================================================
// GreeterState — everything the login screen knows, and the talk with greetd
// =============================================================================
// WHAT A LOGIN SCREEN ACTUALLY IS, IN PLAIN ENGLISH
//
// A login screen does not check your password. It is not allowed to: a program
// that could check passwords could also be tricked into saying yes. What it
// does is HOLD A CONVERSATION with a small trusted program that can, and then
// ask that program to start your desktop.
//
// That trusted program is **greetd**. The conversation is short and it always
// goes the same way:
//
//   we say      "royce would like to log in"          createSession("royce")
//   it asks     "Password:"                           authMessage(...)
//   we answer   the password                          respond("...")
//   it says     either "no" ...                       authFailure("...")
//               ... or "ready when you are"           readyToLaunch()
//   we say      "start the Aquarius Desktop, then"    launch([...], [...], true)
//
// and at that last step greetd starts the desktop and this program exits.
//
// Everything above is done for us by Quickshell's Greetd service, which speaks
// greetd's protocol over a socket. We only have to answer at the right moments,
// which is what the Connections block at the bottom of this file does.
//
// -----------------------------------------------------------------------------
// WHY THIS IS A SINGLETON AND NOT AN OBJECT SOMEBODY OWNS
// -----------------------------------------------------------------------------
// The login screen draws one full-screen window per monitor. There is only ever
// one question being asked, so there is only ever one of this. See greeter/qmldir.
//
// -----------------------------------------------------------------------------
// THE ONE THING THAT IS EASY TO GET WRONG
// -----------------------------------------------------------------------------
// A person types their password and presses Enter BEFORE greetd has been asked
// anything at all — because the box is right there and that is how every login
// screen has ever worked. So the first Enter does two things at once: it starts
// the conversation, and it puts the typed password aside to answer with the
// moment greetd asks for it. `pendingAnswer` below is that put-aside password,
// and it is cleared the instant it is used or the attempt fails.
// =============================================================================
pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

Singleton {
    id: root

    // =========================================================================
    // WHO AND WHAT
    // =========================================================================
    // Filled in once at start-up by the small program below. Until then both
    // are empty and the card says it is still looking.
    property var people: []
    property var desktops: []
    property bool loaded: false

    property int personIndex: 0
    property int desktopIndex: 0

    readonly property var person: root.people.length > 0
        && root.personIndex >= 0
        && root.personIndex < root.people.length
        ? root.people[root.personIndex]
        : null

    readonly property var desktop: root.desktops.length > 0
        && root.desktopIndex >= 0
        && root.desktopIndex < root.desktops.length
        ? root.desktops[root.desktopIndex]
        : null

    // =========================================================================
    // WHAT THE CARD IS SAYING RIGHT NOW
    // =========================================================================
    // One line under the password box. It is greetd's own words wherever
    // greetd has any — "Password:", "Sorry, try again" — because inventing our
    // own text for someone else's authentication system is how a login screen
    // ends up lying about why it said no. Ours only fills the gaps.
    property string status: ""
    property bool statusIsError: false

    // True while greetd is starting a desktop. Everything on the card goes
    // quiet and unclickable, because pressing Enter twice must not start two
    // sessions.
    property bool launching: false

    // Should the box show what is being typed? greetd says so per question:
    // a password is secret, a one-time code from an authenticator app is not.
    property bool echoAnswer: false

    // The password typed before greetd asked for it. See the note at the top.
    property string pendingAnswer: ""
    property bool hasPendingAnswer: false

    // Raised when the box should be emptied and given the keyboard again —
    // after a wrong password, or when greetd asks a second question.
    signal answerWanted()

    // =========================================================================
    // WHAT THE CARD CALLS
    // =========================================================================

    // Enter was pressed with `answer` in the box.
    function signIn(answer: string): void {
        if (root.launching)
            return;
        if (root.person === null) {
            root.say(qsTr("There is nobody to log in as on this computer."), true);
            return;
        }

        root.status = "";
        root.statusIsError = false;

        if (Greetd.state === GreetdState.Inactive) {
            root.pendingAnswer = answer;
            root.hasPendingAnswer = true;
            Greetd.createSession(root.person.name);
        } else if (Greetd.state === GreetdState.Authenticating) {
            Greetd.respond(answer);
        }
        // Any other state means greetd is already busy launching. Doing nothing
        // is right: the desktop is on its way.
    }

    // Escape was pressed, or the chosen person changed. Abandon the attempt and
    // put everything back to how it was when the screen appeared.
    function startOver(): void {
        if (root.launching)
            return;
        root.pendingAnswer = "";
        root.hasPendingAnswer = false;
        root.echoAnswer = false;
        root.status = "";
        root.statusIsError = false;
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        root.answerWanted();
    }

    // Move through the people and the desktops. `step` is +1 or -1 and both
    // wrap, so holding an arrow key cannot get stuck at an end.
    function choosePerson(step: int): void {
        if (root.launching || root.people.length < 2)
            return;
        const count = root.people.length;
        root.personIndex = ((root.personIndex + step) % count + count) % count;
        // A password half-typed for one person must never be sent as another
        // person's. Changing who is logging in starts the attempt over.
        root.startOver();
    }

    function chooseDesktop(step: int): void {
        if (root.launching || root.desktops.length < 2)
            return;
        const count = root.desktops.length;
        root.desktopIndex = ((root.desktopIndex + step) % count + count) % count;
    }

    // =========================================================================
    // THE LAST STEP
    // =========================================================================
    // greetd has said yes. Tell it what to start.
    //
    // ⚠️ THE COMMAND IS A LIST OF WORDS, NOT A LINE OF SHELL. greetd runs it
    // directly — there is no shell to split it up — which is why the splitting
    // happens in aquarius-greeter-info, where quotes can be handled properly.
    //
    // The three XDG_ variables are how a desktop finds out which desktop it is.
    // Leaving XDG_CURRENT_DESKTOP out is the classic cause of "screen recording
    // does nothing": the portal reads it to decide whose rules to follow, and
    // an empty answer means nobody's.
    function launchDesktop(): void {
        if (root.desktop === null) {
            root.say(qsTr("There is no desktop on this computer to start."), true);
            return;
        }
        root.launching = true;
        root.say(qsTr("Starting %1…").arg(root.desktop.name), false);
        Greetd.launch(root.desktop.exec, root.sessionEnvironment(), true);
    }

    // No return type written on purpose: this hands back a plain JavaScript
    // array of strings, and QML's type annotations have no spelling for that
    // which every Qt version agrees on.
    function sessionEnvironment() {
        const environment = [
            "XDG_SESSION_TYPE=wayland",
            "XDG_SESSION_DESKTOP=" + root.desktop.id
        ];
        const names = root.desktop.desktopNames || "";
        if (names.length > 0)
            environment.push("XDG_CURRENT_DESKTOP=" + names);
        return environment;
    }

    function say(words: string, isProblem: bool): void {
        root.status = words;
        root.statusIsError = isProblem;
    }

    // =========================================================================
    // ANSWERING GREETD AT THE RIGHT MOMENTS
    // =========================================================================
    Connections {
        target: Greetd

        // greetd is asking something. Four kinds of question arrive down this
        // one signal and they are told apart by the two flags:
        //
        //   responseRequired = false   it is telling you something, not asking.
        //                              greetd still expects an empty answer
        //                              before it will go on, and a login screen
        //                              that does not send one simply stops.
        //   echoResponse = false       the answer is secret. A password.
        //   echoResponse = true        the answer is not. A code from a phone,
        //                              or a username on a machine set up to ask
        //                              for one.
        function onAuthMessage(message: string, error: bool,
                               responseRequired: bool, echoResponse: bool): void {
            root.say(message, error);

            if (!responseRequired) {
                Greetd.respond("");
                return;
            }

            root.echoAnswer = echoResponse;

            // The password typed before the question was asked. Only ever used
            // for a SECRET question — offering it up for a visible one would
            // put somebody's password on screen.
            if (root.hasPendingAnswer && !echoResponse) {
                const answer = root.pendingAnswer;
                root.pendingAnswer = "";
                root.hasPendingAnswer = false;
                Greetd.respond(answer);
                return;
            }

            root.answerWanted();
        }

        // No. greetd's own words if it gave any — "Sorry, try again" usually.
        function onAuthFailure(message: string): void {
            root.say(message.length > 0 ? message
                                        : qsTr("That did not work. Try again."), true);
            root.pendingAnswer = "";
            root.hasPendingAnswer = false;
            root.echoAnswer = false;
            // The attempt is over as far as greetd is concerned, but it is
            // still holding the session open. Cancelling puts it back to
            // Inactive so the next Enter starts a fresh conversation instead of
            // being ignored.
            Greetd.cancelSession();
            root.answerWanted();
        }

        // Yes.
        function onReadyToLaunch(): void {
            root.launchDesktop();
        }

        // Something went wrong with the conversation itself — the socket, the
        // protocol — rather than with the password. Rare, and worth saying out
        // loud rather than leaving the screen looking inert.
        function onError(message: string): void {
            root.say(message, true);
            root.launching = false;
        }
    }

    // =========================================================================
    // WHO CAN LOG IN, AND INTO WHAT
    // =========================================================================
    // One small program, run once, printing one line of JSON. Its own header
    // explains why this is not done in QML. If it is missing or unreadable the
    // card says so plainly instead of drawing an empty list, because an empty
    // login screen looks broken and a login screen that says what is wrong can
    // be fixed.
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

        if (data === null) {
            root.loaded = true;
            root.say(qsTr("Could not read the list of accounts on this computer."), true);
            console.warn("aquarius-greeter: /usr/libexec/aquarius-greeter-info printed nothing readable");
            return;
        }

        root.people = data.people || [];
        root.desktops = data.desktops || [];
        root.loaded = true;

        if (root.people.length === 0)
            root.say(qsTr("There is nobody to log in as on this computer."), true);
        else if (root.desktops.length === 0)
            root.say(qsTr("There is no desktop on this computer to start."), true);
        else
            root.answerWanted();
    }
}
