#!/usr/bin/env python3
"""Check that one Mac/Windows switch reaches fresh and previously repaired GTK."""
import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import unittest

loader = importlib.machinery.SourceFileLoader(
    "aq_theme", str(Path(__file__).resolve().parents[1] / "session/labwc/generate-theme"))
spec = importlib.util.spec_from_loader(loader.name, loader)
theme = importlib.util.module_from_spec(spec)
loader.exec_module(theme)


class ButtonLayoutTests(unittest.TestCase):
    def test_fresh_and_repeated_switches(self):
        with tempfile.TemporaryDirectory() as root:
            for folder in ("gtk-3.0", "gtk-4.0"):
                for mode in ("mac", "windows", "mac"):
                    theme.sync_gtk_button_layout(root, folder, mode)
                    text = (Path(root) / folder / "settings.ini").read_text()
                    self.assertEqual(text, "[Settings]\ngtk-decoration-layout="
                                     + theme.GTK_DECORATION_LAYOUTS[mode] + "\n")

    def test_custom_settings_and_sections_survive(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root) / "gtk-4.0"
            folder.mkdir()
            path = folder / "settings.ini"
            before = ("# User settings\n[Settings]\ngtk-font-name=Inter 10\n"
                      "gtk-decoration-layout=:close\ngtk-icon-theme-name=Personal\n"
                      "[Other]\ngtk-decoration-layout=unrelated\n")
            path.write_text(before)
            theme.sync_gtk_button_layout(root, "gtk-4.0", "mac")
            self.assertEqual(path.read_text(), before.replace(
                "gtk-decoration-layout=:close", "gtk-decoration-layout=close,minimize,maximize:"))

    def test_missing_key_and_no_final_newline(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root) / "gtk-3.0"
            folder.mkdir()
            path = folder / "settings.ini"
            path.write_text("[Settings]")
            theme.sync_gtk_button_layout(root, "gtk-3.0", "windows")
            self.assertEqual(path.read_text(),
                             "[Settings]\ngtk-decoration-layout=:minimize,maximize,close\n")

    def test_original_breeze_copy_and_repaired_switch(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root) / "gtk-4.0"
            folder.mkdir()
            path = folder / "settings.ini"
            before = "[Settings]\ngtk-icon-theme-name=breeze\ngtk-decoration-layout=:close\n"
            path.write_text(before)
            theme.sync_gtk_button_layout(root, "gtk-4.0", "mac")
            theme.neutralise_gtk_settings(root, "gtk-4.0", "ice", "mac", "Aquarius-Ice")
            theme.sync_gtk_button_layout(root, "gtk-4.0", "windows")
            self.assertIn("gtk-decoration-layout=:minimize,maximize,close", path.read_text())
            self.assertEqual(Path(str(path) + theme.RESCUE_SUFFIX).read_text(), before)


if __name__ == "__main__":
    unittest.main()
