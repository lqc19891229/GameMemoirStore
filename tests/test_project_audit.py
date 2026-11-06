"""Regression checks for editor plugin references in resource audit."""
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from project_audit import audit


class GodotPluginAuditTests(unittest.TestCase):
    def test_plugin_cfg_relative_entry_is_not_unused(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            addon = root / "addons" / "example"
            addon.mkdir(parents=True)
            (addon / "plugin.gd").write_text("@tool\nextends EditorPlugin\n", encoding="utf-8")
            (addon / "plugin.gd.uid").write_text("uid://abc123", encoding="utf-8")
            cfg = addon / "plugin.cfg"
            cfg.write_text('[plugin]\nscript="plugin.gd"\n', encoding="utf-8")
            result = audit(root)
            self.assertEqual(result["problems"], [])
            self.assertNotIn("addons/example/plugin.gd", result["unreferenced_candidates"])
            cfg.write_text('[plugin]\nscript="absent.gd"\n', encoding="utf-8")
            result = audit(root)
            self.assertTrue(any("missing plugin script absent.gd" in p for p in result["problems"]))


if __name__ == "__main__":
    unittest.main()
