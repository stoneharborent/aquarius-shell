#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Eject a drive from the dock: unmount it, then power it off so it can be unplugged.

WHAT "EJECT" MEANS HERE, IN PLAIN LANGUAGE
    Unmount  closes the drive's files. The drive itself stays switched on and
             udisks2 still knows about it, so Files keeps showing it with a
             "mount" icon and one click brings it back. That is what the dock's
             Unmount item does, and it does it straight from QML with
             `gio mount -u -f` — this script is not involved.
    Eject    is unmount AND THEN power the drive off, which is what makes it
             safe to pull the cable out. Two steps, in that order, which is the
             whole reason this is a script and not one more `execDetached` line:
             QML can start a command, but it cannot wait for one to finish.

THE TWO KINDS OF DRIVE (the same split `aq drive eject` makes, on purpose)
    a Mac drive (APFS)  was opened by apfs-fuse, a program running as you, so it
                        is closed with fusermount3 — the standard command for
                        exactly that. There is no udisks2 drive behind it to
                        power off, so for these Eject IS unmount and the script
                        stops there. (The dock knows this too: an APFS tile is
                        offered only Eject, never Unmount, because offering both
                        would be offering the same thing twice.)
    everything else     was mounted by udisks2, so it is closed through GVfs
                        (`gio mount -u -f`) and then powered off with
                        `udisksctl power-off -b <device>`.

WHY THE PARTITION DEVICE IS GOOD ENOUGH FOR power-off
    The mount table gives us a PARTITION (/dev/sdb1), and powering off is
    something a whole DRIVE does (/dev/sdb). udisksctl closes that gap itself:
    its power-off command looks the block device up and calls
    `udisks_client_get_drive_for_block()` on it, which walks from the partition
    to the drive it lives on (udisks, tools/udisksctl.c). So handing it the
    partition is correct and there is nothing to work out here.

NO PASSWORD
    ../os-image/system_files/usr/share/polkit-1/rules.d/49-aquarius-udisks.rules
    grants power-off-drive (along with mount and unmount) to the person sitting
    at the machine, for REMOVABLE drives only. An internal disk would still ask,
    which is the intended answer — and the dock only ever lists drives mounted
    under /run/media/<you> anyway.

Run by hand:  eject-drive.py "/run/media/royce/FIELD SSD"
"""
import subprocess
import sys
from pathlib import Path

# How long any one command is given before we stop waiting for it. A drive that
# is still being written to can make an unmount take a moment; twenty seconds is
# long enough for a busy healthy drive and short enough that nothing waits for
# ever on a broken one.
TIMEOUT = 20


def mount_entry(mount_path):
    """Return (fstype, source device) for a mount point, or ("", "")."""
    try:
        result = subprocess.run(
            ["findmnt", "--noheadings", "--output", "FSTYPE,SOURCE",
             "--mountpoint", str(mount_path)],
            capture_output=True, text=True, check=True, timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return "", ""

    # findmnt can print more than one line if something is mounted on top of
    # the drive; the first line is the drive itself.
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            return parts[0], parts[1]
        if len(parts) == 1:
            return parts[0], ""
    return "", ""


def run(command):
    """True if the command ran and said it worked."""
    try:
        return subprocess.call(command, timeout=TIMEOUT) == 0
    except (OSError, subprocess.SubprocessError):
        return False


def eject(mount_path):
    fstype, source = mount_entry(mount_path)

    # A Mac drive, or any other FUSE mount: close it the way it was opened.
    # `-z` is the second try — it detaches the mount now and finishes tidying up
    # when the last program lets go, which is better than leaving it open.
    if fstype.startswith("fuse"):
        closed = run(["fusermount3", "-u", str(mount_path)]) \
            or run(["fusermount3", "-u", "-z", str(mount_path)])
        if closed:
            try:
                Path(mount_path).rmdir()
            except OSError:
                pass
        return 0 if closed else 1

    # Everything else: GVfs closes it, then udisks2 powers the drive down.
    if not run(["gio", "mount", "-u", "-f", str(mount_path)]):
        return 1

    if not source:
        # Unmounted, but we never learned which device it was, so there is
        # nothing to power off. The files are safe; the drive is still awake.
        return 0

    return 0 if run(["udisksctl", "power-off", "-b", source]) else 1


if __name__ == "__main__":
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_absolute():
        sys.exit("Expected one absolute drive mount path")
    sys.exit(eject(sys.argv[1]))
