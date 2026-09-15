// SPDX-FileCopyrightText: 2026 Stone Harbor Entertainment
// SPDX-License-Identifier: Apache-2.0
import QtQuick

// Size the artwork, including icons whose files contain transparent margins.
// Vendor files stay untouched. A bounded enlargement preserves unusual marks.
Item {
    id: root
    property url source
    property real implicitSize: 48
    readonly property bool ready: original.status === Image.Ready && !emptyArtwork
    readonly property bool error: original.status === Image.Error || emptyArtwork
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    property bool emptyArtwork: false
    property bool normalized: false
    property bool analysisFailed: false
    onSourceChanged: {
        normalized = false;
        emptyArtwork = false;
        analysisFailed = false;
        artwork.loadSource();
    }

    Image {
        id: original
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(192, 192)
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: root.ready && (!root.normalized || root.analysisFailed)
        onStatusChanged: {
            root.normalized = false;
            root.emptyArtwork = false;
            root.analysisFailed = false;
            artwork.loadSource();
        }
    }

    Canvas {
        id: artwork
        // Scan a fixed, detailed image once per source, never on hover frames.
        width: 192
        height: 192
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 192
        opacity: root.normalized && !root.analysisFailed ? 1 : 0
        renderTarget: Canvas.Image
        property url loadedSource
        function loadSource() {
            if (loadedSource !== root.source && loadedSource.toString() !== "")
                unloadImage(loadedSource);
            loadedSource = root.source;
            if (available && root.source.toString() !== "")
                loadImage(root.source, Qt.size(192, 192));
            requestPaint();
        }
        onAvailableChanged: loadSource()
        onImageLoaded: requestPaint()
        onPaint: {
            if (!available)
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, 192, 192);
            if (!root.ready || root.analysisFailed || !isImageLoaded(root.source))
                return;
            try {
                const ratio = original.implicitWidth / original.implicitHeight;
                if (!isFinite(ratio) || ratio <= 0)
                    throw new Error("Icon dimensions unavailable");
                const w = ratio >= 1 ? 192 : 192 * ratio;
                const h = ratio >= 1 ? 192 / ratio : 192;
                const x = (192 - w) / 2;
                const y = (192 - h) / 2;
                ctx.drawImage(root.source, x, y, w, h);
                const pixels = ctx.getImageData(0, 0, 192, 192).data;
                let left = 192, top = 192, right = -1, bottom = -1;
                for (let py = 0; py < 192; ++py) {
                    for (let px = 0; px < 192; ++px) {
                        if (pixels[(py * 192 + px) * 4 + 3] > 8) {
                            left = Math.min(left, px);
                            right = Math.max(right, px);
                            top = Math.min(top, py);
                            bottom = Math.max(bottom, py);
                        }
                    }
                }
                if (right < left) {
                    root.emptyArtwork = true;
                    throw new Error("Icon has no visible artwork");
                }
                // Keep a pixel around the sampled silhouette for antialiasing.
                left = Math.max(0, left - 1);
                top = Math.max(0, top - 1);
                right = Math.min(191, right + 1);
                bottom = Math.min(191, bottom + 1);
                const zoom = Math.min(1.6, 192 / Math.max(right - left + 1, bottom - top + 1));
                const centerX = (left + right + 1) / 2;
                const centerY = (top + bottom + 1) / 2;
                ctx.clearRect(0, 0, 192, 192);
                ctx.drawImage(root.source, 96 + (x - centerX) * zoom,
                              96 + (y - centerY) * zoom, w * zoom, h * zoom);
                root.normalized = true;
            } catch (e) {
                // An unsupported image provider still gets the ordinary icon.
                root.analysisFailed = true;
                root.normalized = false;
            }
        }
    }
}
