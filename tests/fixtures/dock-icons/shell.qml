import QtQuick
import QtQuick.Window
import Quickshell


// One private offscreen window. Captures contain the actual rendered component.
Window {
    id: root
    width: 120
    height: 120
    visible: true
    color: "transparent"
    property int step: -1
    property int attempts: 0
    property bool capturing: false
    property var cases: [
        ["square", "square.svg", 64],
        ["padded", "padded.svg", 64],
        ["wide", "wide.svg", 64],
        ["transparent", "transparent.svg", 64],
        ["missing", "missing.svg", 64],
        ["changed", "padded.svg", 64],
        ["resized", "padded.svg", 88]
    ]
    Item {
        id: capture
        width: 120
        height: 120
        DockAppIcon {
            id: icon
            anchors.centerIn: parent
            width: 64
            height: width
        }
    }
    function advance() {
        step++;
        if (step >= cases.length) {
            console.warn("DOCK_ICON_RENDER_PASS");
            Qt.quit();
            return;
        }
        const item = cases[step];
        attempts = 0;
        icon.width = item[2];
        icon.source = Qt.resolvedUrl(item[1]);
        capturing = false;
    }
    Timer {
        interval: 150
        repeat: true
        running: true
        onTriggered: {
            if (root.capturing || root.step < 0)
                return;
            root.attempts++;
            if (root.attempts > 40) {
                console.error("Timed out rendering " + root.cases[root.step][0]);
                Qt.exit(1);
                return;
            }
            if (root.attempts < 3 || !(icon.normalized || icon.analysisFailed || icon.error))
                return;
            const name = root.cases[root.step][0];
            const expectError = name === "transparent" || name === "missing";
            if (icon.error !== expectError || icon.ready === expectError) {
                console.error("Incorrect fallback state for " + name);
                Qt.exit(1);
                return;
            }
            root.capturing = true;
            capture.grabToImage(function(result) {
                const name = root.cases[root.step][0];
                if (!result.saveToFile(Quickshell.env("AQ_ICON_TEST_OUTPUT") + "/" + name + ".png")) {
                    console.error("Could not save " + name);
                    Qt.exit(1);
                    return;
                }
                console.warn("Captured " + name);
                root.advance();
            });
        }
    }
    Component.onCompleted: advance()
}
