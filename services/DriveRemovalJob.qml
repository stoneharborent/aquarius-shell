// SPDX-License-Identifier: Apache-2.0
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    signal revealRequested()
    property string mountPath: ""
    property string mountLabel: ""
    property string identity: ""
    property string status: "ready"
    readonly property bool busy: status === "running"
    readonly property bool retryable: status === "failed"
    readonly property string message: status === "running"
        ? qsTr("Ejecting… Keep the drive connected.")
        : status === "success"
        ? qsTr("This item has been ejected. Eject any other items shown for this drive before unplugging it.")
        : status === "unavailable"
        ? qsTr("This item is no longer available. Check the drive in Files before trying again.")
        : qsTr("Could not eject. Close files and apps using this drive, keep it connected, then try again.")

    function start() {
        if (busy || (status !== "ready" && !retryable)) return;
        status = "running";
        process.running = true;
    }

    property Process process: Process {
        // An argv array preserves spaces and punctuation in both the helper's
        // install path and the mount path. There is no shell to interpret them.
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("unmount-volume.py").toString().substring(7)), root.mountPath, root.identity]
        stdout: StdioCollector { id: output }
        stderr: StdioCollector {}
        onExited: function(exitCode, exitStatus) {
            if (!root.busy) return;
            try {
                const result = JSON.parse(output.text);
                if (exitCode !== 0 || exitStatus !== 0
                        || ["success", "failed", "unavailable"].indexOf(result.status) < 0
                        || typeof result.identity !== "string"
                        || (root.identity !== "" && result.identity !== root.identity)) throw new Error("Invalid result");
                root.identity = result.identity;
                root.status = result.identity === "" ? "unavailable" : result.status;
            } catch (error) {
                root.status = root.identity === "" ? "unavailable" : "failed";
            }
        }
        // A missing Python executable fails before exited can be delivered.
        onRunningChanged: {
            if (!running && root.busy) settle.restart();
        }
    }
    property Timer settle: Timer {
        interval: 250
        onTriggered: { if (root.busy && !process.running) root.status = root.identity === "" ? "unavailable" : "failed"; }
    }
}
