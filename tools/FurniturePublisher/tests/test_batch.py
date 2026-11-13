"""Batch hardware publisher: spec discovery, safety, and all-or-nothing rollback."""
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from batch_hardware import load_batch_specs, preview_batch, publish_batch
from publisher_core import PublishError


class BatchPublisherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "project"
        self.folder = Path(self.temp.name) / "incoming"
        self.folder.mkdir()
        repo = Path(__file__).resolve().parents[3]
        source_spec = repo / "tools/FurniturePublisher/examples/qihang_2000/model_specs.json"
        self.spec = json.loads(source_spec.read_text(encoding="utf-8"))
        self.spec_path = self.folder / "model_specs.json"
        self.spec_path.write_text(json.dumps(self.spec), encoding="utf-8")
        (self.root / "project.godot").parent.mkdir(parents=True, exist_ok=True)
        (self.root / "project.godot").write_text("config_version=5", encoding="utf-8")
        (self.root / "godot").write_text("mock")
        for path in [
            "tools/FurniturePublisher/hardware_bridge.gd",
            "scripts/life/device_model.gd", "data/hardware/_catalog.tres",
        ]:
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("fixture", encoding="utf-8")
        mappings = {
            "monitor": ("monitor_crt", "starter_monitor"),
            "computer": ("case_beige", "starter_pc"),
            "keyboard": ("keyboard_beige", "starter_mouse"),
            "mouse": ("mouse_beige", "starter_mouse"),
        }
        for entry in self.spec["models"]:
            role = entry["role"]
            basename, _ = mappings[role]
            # Use existing valid model data; spec geometry is checked against its authored design.
            model = repo / "assets/models/hardware" / (basename + ".glb")
            shutil.copyfile(model, self.folder / entry["file"])
            dst = self.root / "assets/models/hardware" / (basename + ".glb")
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(model, dst)
            resource = self.root / "data/hardware" / (basename + ".tres")
            resource.write_text('[ext_resource type="PackedScene" path="res://assets/models/hardware/' + basename + '.glb" id="2"]\n', encoding="utf-8")
            scene = self.root / "scenes/computer/hardware" / (role + ".tscn")
            scene.parent.mkdir(parents=True, exist_ok=True)
            node = "DefaultModel"
            scene.write_text('[ext_resource type="PackedScene" path="res://assets/models/hardware/' + basename +
                             '.glb" id="3"]\n[node name="' + role[0].upper() + role[1:] + '" type="Node3D"]\nvisible = false\n[node name="' + node +
                             '" parent="Models" instance=ExtResource("3")]\nscale = Vector3(.4, .4, .4)\n',
                             encoding="utf-8")

    def _items(self):
        return load_batch_specs(str(self.root), str(self.root / "godot"), str(self.spec_path))

    def test_four_models_autodiscovered_and_ordered(self):
        items = self._items()
        self.assertEqual([i.role for i in items], ["monitor", "computer", "keyboard", "mouse"])
        self.assertEqual([i.item_id for i in items], ["starter_monitor", "starter_pc", "starter_mouse", "starter_mouse"])
        self.assertIn("4/4", preview_batch(str(self.root), str(self.root / "godot"), str(self.spec_path)))

    def test_reject_duplicate_role_and_directory_traversal(self):
        self.spec["models"][1]["role"] = "monitor"
        self.spec_path.write_text(json.dumps(self.spec))
        with self.assertRaises(PublishError): self._items()
        self.spec["models"][1]["role"] = "computer"
        self.spec["models"][1]["file"] = "../evil.glb"
        self.spec_path.write_text(json.dumps(self.spec))
        with self.assertRaises(PublishError): self._items()

    def test_reject_invalid_size_and_missing_screen(self):
        self.spec["models"][0].pop("screen_position_m")
        self.spec_path.write_text(json.dumps(self.spec))
        with self.assertRaises(PublishError): self._items()
        self.spec["models"][0]["screen_position_m"] = [0, .211, .155]
        self.spec["models"][1]["expected_size_m"] = [.19, .42, 5.0]
        self.spec_path.write_text(json.dumps(self.spec))
        with self.assertRaises(PublishError): self._items()

    def test_batch_failure_restores_every_file_and_cleans_temp(self):
        items = self._items()
        changed = set()
        for item in items:
            changed.update([item.model_relative, item.resource_relative, item.scene_relative])
        old = {p: (self.root / p).read_bytes() for p in changed}
        calls = 0
        def fake_execute(cmd, cwd, log, timeout):
            nonlocal calls
            calls += 1
            if calls == 3: raise PublishError("second hardware configuration failed")
            if "--import" in cmd: return ""
            manifest = json.loads((self.root / "tools" / Path(cmd[-1]).name).read_text())
            (self.root / manifest["resource_path"].removeprefix("res://")).write_text("modified")
            return 'HARDWARE_PUBLISH_RESULT=' + json.dumps({"ok":True, "model":manifest["model_path"]})
        with patch("batch_hardware._execute", side_effect=fake_execute):
            with self.assertRaisesRegex(PublishError, "second hardware"):
                publish_batch(str(self.root), str(self.root / "godot"), str(self.spec_path), log=lambda _: None)
        self.assertEqual(old, {p: (self.root / p).read_bytes() for p in changed})
        self.assertFalse(list((self.root / "tools").glob("_hardware_publish_*.json")))

    def test_batch_success_uses_one_import_and_four_receipts(self):
        commands = []
        def fake_execute(cmd, cwd, log, timeout):
            commands.append(cmd)
            if "--import" in cmd: return ""
            manifest = json.loads((self.root / "tools" / Path(cmd[-1]).name).read_text())
            return 'HARDWARE_PUBLISH_RESULT=' + json.dumps({"ok":True, "model":manifest["model_path"]})
        with patch("batch_hardware._execute", side_effect=fake_execute):
            result = publish_batch(str(self.root), str(self.root / "godot"), str(self.spec_path), log=lambda _: None)
        self.assertEqual(result["count"], 4)
        self.assertEqual(len([c for c in commands if "--import" in c]), 1)
        self.assertEqual(len(commands), 5)
        self.assertTrue((Path(result["backup"]) / "data/hardware/monitor_crt.tres").is_file())


if __name__ == "__main__":
    unittest.main()
