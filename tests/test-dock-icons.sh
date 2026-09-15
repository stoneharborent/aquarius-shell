#!/usr/bin/env bash
# Render synthetic icons without touching the desktop or installed app artwork.
set -euo pipefail
aq_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aq_work="$(mktemp -d)"
trap 'rm -rf "$aq_work"' EXIT
mkdir -m 700 "$aq_work/runtime"
mkdir "$aq_work/config"
cp "$aq_repo"/tests/fixtures/dock-icons/* "$aq_work/config/"
cp "$aq_repo/components/dock/DockAppIcon.qml" "$aq_work/config/"
if ! env -u WAYLAND_DISPLAY -u DISPLAY XDG_RUNTIME_DIR="$aq_work/runtime" QT_QPA_PLATFORM=offscreen \
    QT_QUICK_BACKEND=software AQ_ICON_TEST_OUTPUT="$aq_work" \
    timeout 30 qs --no-color -p "$aq_work/config/shell.qml" \
    >"$aq_work/render.log" 2>&1; then
    cat "$aq_work/render.log"
    exit 1
fi
if ! grep -q DOCK_ICON_RENDER_PASS "$aq_work/render.log"; then
    cat "$aq_work/render.log"
    exit 1
fi
python3 - "$aq_work" <<'PY'
"""Read Qt's PNG output using only Python's standard library."""
from pathlib import Path
import struct
import sys
import zlib


def bounds(name):
    raw = (Path(sys.argv[1]) / (name + '.png')).read_bytes()
    assert raw[:8] == b'\x89PNG\r\n\x1a\n'
    pos, compressed = 8, bytearray()
    while pos < len(raw):
        length = int.from_bytes(raw[pos:pos + 4], 'big')
        kind, payload = raw[pos + 4:pos + 8], raw[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            width, height, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', payload)
            assert (depth, color, interlace) == (8, 6, 0), 'Expected Qt RGBA PNG'
        elif kind == b'IDAT':
            compressed.extend(payload)
        pos += length + 12
    pixels = zlib.decompress(compressed)
    stride, prior, points = width * 4, bytearray(width * 4), []
    for y in range(height):
        start = y * (stride + 1)
        mode = pixels[start]
        row = bytearray(pixels[start + 1:start + 1 + stride])
        for x in range(stride):
            left, above = row[x - 4] if x >= 4 else 0, prior[x]
            corner = prior[x - 4] if x >= 4 else 0
            if mode == 0:
                add = 0
            elif mode == 1:
                add = left
            elif mode == 2:
                add = above
            elif mode == 3:
                add = (left + above) // 2
            else:
                assert mode == 4
                estimate = left + above - corner
                distances = [abs(estimate - value) for value in (left, above, corner)]
                add = (left, above, corner)[distances.index(min(distances))]
            row[x] = (row[x] + add) & 255
        points.extend((x, y) for x in range(width) if row[x * 4 + 3] > 32)
        prior = row
    if not points:
        return None
    xs, ys = zip(*points)
    result = (min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)
    print(name, result)
    return result


square, padded, wide = (bounds(name) for name in ('square', 'padded', 'wide'))
assert square[2:] == (64, 64), square
assert all(abs(a - b) <= 2 for a, b in zip(square, padded)), (square, padded)
assert abs(wide[2] / wide[3] - 2) < 0.12, wide
assert abs(wide[2] - 64) <= 2, wide
assert bounds('transparent') is None, 'Transparent icon leaked previous artwork'
assert bounds('missing') is None, 'Missing icon leaked previous artwork'
assert bounds('changed') == padded, 'Source change retained a previous icon'
resized = bounds('resized')
assert abs(resized[2] - 88) <= 2 and abs(resized[3] - 88) <= 2, resized
assert abs(resized[0] + resized[2] / 2 - 60) <= 1, resized
print('PASS: padded artwork, aspect ratio, empty/error fallback, source changes and resize')
PY
