// SPDX-License-Identifier: Apache-2.0
import QtQuick
import QtQuick.Controls
import Quickshell
import "../../services"
import "../../theme"

// Separate from the drive delegate: successful unmount often removes that
// delegate before the command exits. Closing a window never cancels a job.
Scope {
    component ActionButton: Button {
        id: button
        font.family: Theme.fontBody
        font.pixelSize: Theme.fsBody
        padding: Theme.logoMenuPaddingV
        contentItem: Text {
            text: button.text
            font: button.font
            color: button.enabled ? Theme.ink : Theme.inkMute
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: Theme.radiusSm
            color: button.down ? Theme.pressWash : button.hovered ? Theme.hoverWash : Theme.surface
            border.width: Theme.hairline
            border.color: button.activeFocus ? Theme.ink : Theme.lineStrong
        }
    }
    Variants {
        model: DriveRemoval.jobs
        delegate: FloatingWindow {
            id: window
            required property var modelData
            title: qsTr("Eject %1").arg(modelData.mountLabel)
            visible: true
            implicitWidth: Theme.logoMenuMinWidth * 2
            implicitHeight: content.implicitHeight + Theme.logoMenuPaddingV * 2
            color: Theme.surface
            // Do not change a Variants model inside its native visibility
            // callback. A close during work only hides progress; completion
            // brings the result back. Finished windows can be dismissed safely.
            onVisibleChanged: {
                if (!visible) Qt.callLater(() => {
                    if (!window.visible && window.modelData && !window.modelData.busy)
                        DriveRemoval.dismiss(window.modelData);
                });
            }
            Connections {
                target: window.modelData
                function onRevealRequested() { window.visible = true; }
                function onStatusChanged() { window.visible = true; }
            }
            Column {
                id: content
                x: Theme.logoMenuRowPaddingH
                y: Theme.logoMenuPaddingV
                width: parent.width - Theme.logoMenuRowPaddingH * 2
                spacing: Theme.dockGap
                Text {
                    width: parent.width
                    text: window.modelData.mountLabel
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Theme.ink
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsBody
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: window.modelData.message
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Theme.ink
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.fsBody
                    Accessible.name: text
                }
                Row {
                    spacing: Theme.dockGap
                    ActionButton {
                        visible: window.modelData.retryable
                        text: qsTr("Retry")
                        onClicked: window.modelData.start()
                    }
                    ActionButton {
                        enabled: !window.modelData.busy
                        text: qsTr("Done")
                        onClicked: DriveRemoval.dismiss(window.modelData)
                    }
                }
            }
        }
    }
}
