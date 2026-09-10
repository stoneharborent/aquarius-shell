#!/usr/bin/env bash
# Prepare a disposable config root: imports resolve exactly as in the image.
# Use a private DBus session and offscreen Qt; no live shell/desktop is touched.
set -eu
repo="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d /tmp/aquarius-drive-test.XXXXXX)"
trap 'rm -rf "$work"' EXIT
cp -r "$repo/services" "$repo/theme" "$repo/components" "$repo/lock" "$repo/greeter" "$work/"
cp "$repo/tests/drive-removal-runtime.qml.in" "$work/shell.qml"
mkdir -p "$work/run" "$work/cache" "$work/config"
chmod 700 "$work/run"
export XDG_RUNTIME_DIR="$work/run" XDG_CACHE_HOME="$work/cache" XDG_CONFIG_HOME="$work/config"
unset WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software PYTHONDONTWRITEBYTECODE=1
# The entire shell is a test harness. Every removal subprocess is a Python fake.
dbus-run-session -- timeout 20 qs --no-color -p "$work" > "$work/result.log" 2>&1 || { cat "$work/result.log"; exit 1; }
cat "$work/result.log"
grep -q 'DRIVE TEST PASSED' "$work/result.log"
if grep -E 'TypeError|ReferenceError|Cannot assign|Unable to assign|is not a type|FAIL' "$work/result.log"; then exit 1; fi
