#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Unmount one exact volume without forcing or detaching a busy filesystem.

The shell owns the progress UI. This helper returns only a small result, never
command output. A retry carries the original mount identity so a replacement
volume mounted at the same folder cannot be unmounted by an old Retry button.
"""
import json
import os
import re
import subprocess
import sys


def unescape(value):
    return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), value)


def mounts():
    with open('/proc/self/mountinfo', encoding='utf-8') as stream:
        result = {}
        for line in stream:
            fields = line.split()
            split = fields.index('-')
            path = unescape(fields[4])
            result[path] = {
                'identity': ':'.join((fields[0], fields[2], fields[3], fields[split + 2])),
                'type': fields[split + 1],
            }
        return result


def unmount(path, expected='', read_mounts=mounts, run=subprocess.run, remove_empty=os.rmdir):
    if not os.path.isabs(path) or os.path.normpath(path) != path:
        return {'status': 'unavailable', 'identity': expected}
    original = read_mounts().get(path)
    if original is None or (expected and original['identity'] != expected):
        return {'status': 'unavailable', 'identity': expected}
    identity = original['identity']
    fstype = original['type']
    command = (['fusermount3', '-u', '--', path]
               if fstype == 'fuse' or fstype.startswith('fuse.')
               else ['gio', 'mount', '-u', '--', path])
    try:
        # No timeout: killing a client does not prove the service stopped its
        # request. Keep the UI in progress until this command actually finishes.
        result = run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     check=False)
    except OSError:
        return {'status': 'failed', 'identity': identity}
    try:
        remaining = read_mounts().get(path)
    except (OSError, ValueError):
        return {'status': 'failed', 'identity': identity}
    if result.returncode == 0 and remaining is None:
        # FUSE leaves its empty mount folder behind; the dock watches those
        # folders. Never recurse, and a busy/nonempty folder is left alone.
        try:
            remove_empty(path)
        except OSError:
            pass
        return {'status': 'success', 'identity': identity}
    if remaining is not None and remaining['identity'] != identity:
        return {'status': 'unavailable', 'identity': identity}
    return {'status': 'failed', 'identity': identity}


if __name__ == '__main__':
    try:
        result = unmount(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else '')
    except (OSError, ValueError, IndexError):
        result = {'status': 'failed', 'identity': sys.argv[2] if len(sys.argv) > 2 else ''}
    print(json.dumps(result))
