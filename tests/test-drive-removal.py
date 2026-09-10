#!/usr/bin/env python3
"""Only fake mount tables and fake commands; never touch a mounted drive."""
import importlib.util
from pathlib import Path
import subprocess
import unittest

spec = importlib.util.spec_from_file_location('unmount', Path(__file__).resolve().parents[1] / 'services/unmount-volume.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class RemovalTests(unittest.TestCase):
    path = '/run/media/royce/Field $(touch NEVER) "SSD"'

    def perform(self, kind='exfat', code=0, remains=False, expected='', replacement=False):
        old = {'identity': '101:8:1:source', 'type': kind}
        new = dict(old, identity='102:8:1:replacement') if replacement else old
        tables = iter([{self.path: old}, {self.path: new} if remains else {}])
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            return subprocess.CompletedProcess(command, code)
        return helper.unmount(self.path, expected, lambda: next(tables), run, lambda path: None), calls

    def test_normal_volume_argv_and_verified_success(self):
        result, calls = self.perform()
        self.assertEqual(result['status'], 'success')
        self.assertEqual(calls, [['gio', 'mount', '-u', '--', self.path]])

    def test_fuse_uses_normal_unmount_only(self):
        for kind in ['fuse.apfs', 'fuse.apfs-fuse', 'fuse']:
            result, calls = self.perform(kind=kind, code=1, remains=True)
            self.assertEqual(result['status'], 'failed')
            self.assertEqual(calls, [['fusermount3', '-u', '--', self.path]])

    def test_busy_then_retry(self):
        first, _ = self.perform(code=1, remains=True)
        second, _ = self.perform(expected=first['identity'])
        self.assertEqual(second['status'], 'success')

    def test_success_exit_with_mount_remaining_is_failure(self):
        self.assertEqual(self.perform(remains=True)[0]['status'], 'failed')

    def test_failure_exit_with_mount_gone_is_not_success(self):
        self.assertEqual(self.perform(code=1)[0]['status'], 'failed')

    def test_replacement_at_completion_is_not_success(self):
        self.assertEqual(self.perform(remains=True, replacement=True)[0]['status'], 'unavailable')

    def test_stale_retry_does_not_run(self):
        result, calls = self.perform(expected='old-volume')
        self.assertEqual(result['status'], 'unavailable')
        self.assertEqual(calls, [])

    def test_missing_mount_does_not_run(self):
        def forbidden(*args, **kwargs):
            self.fail('must not run a command')
        result = helper.unmount(self.path, '', lambda: {}, forbidden)
        self.assertEqual(result['status'], 'unavailable')

    def test_missing_command_returns_failure(self):
        def missing(*args, **kwargs):
            raise FileNotFoundError()
        result = helper.unmount(self.path, '', lambda: {self.path: {'identity': '1', 'type': 'exfat'}}, missing)
        self.assertEqual(result, {'status': 'failed', 'identity': '1'})

    def test_readback_failure_keeps_identity(self):
        count = 0
        def read():
            nonlocal count
            count += 1
            if count > 1:
                raise OSError('unreadable mount table')
            return {self.path: {'identity': 'original', 'type': 'exfat'}}
        result = helper.unmount(self.path, '', read,
                                lambda *args, **kwargs: subprocess.CompletedProcess([], 0))
        self.assertEqual(result, {'status': 'failed', 'identity': 'original'})

    def test_mountinfo_escapes(self):
        self.assertEqual(helper.unescape(r'Field\040SSD\134name\011tab'), 'Field SSD\\name\ttab')


if __name__ == '__main__':
    unittest.main()
