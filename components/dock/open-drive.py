#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Open an APFS-FUSE volume at its files, without exposing its wrapper folders."""
import json
from pathlib import Path
import subprocess
import sys


def open_path(mount_path):
    """Only APFS-FUSE wraps user files in root; ordinary drives stay unchanged."""
    mount = Path(mount_path)
    try:
        result = subprocess.run(
            ["findmnt", "--json", "--mountpoint", str(mount), "--output", "FSTYPE"],
            capture_output=True, text=True, check=True, timeout=5,
        )
        filesystems = json.loads(result.stdout).get("filesystems", [])
        if len(filesystems) == 1 and filesystems[0].get("fstype") == "fuse.apfs":
            contents = mount / "root"
            if contents.is_dir() and not contents.is_symlink():
                return str(contents)
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    return str(mount)


if __name__ == "__main__":
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_absolute():
        sys.exit("Expected one absolute drive mount path")
    sys.exit(subprocess.call(["xdg-open", open_path(sys.argv[1])]))
