import json
import struct
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from publisher_core import Item, PublishError, inspect_glb, preview, publish
from hardware_core import HardwareItem, _unity_scale_scene, preview_hardware, publish_hardware, _activate_published_device


def make_glb(mesh=True, external=False):
    obj = {"asset":{"version":"2.0"}, "nodes":[{"mesh":0}],
           "meshes":[{"primitives":[{"attributes":{"POSITION":0}}]}] if mesh else [],
           "buffers":[{"byteLength":0}], "accessors":[], "images":[]}
    if external: obj["images"] = [{"uri":"./other.png"}]
    raw = json.dumps(obj).encode("utf-8")
    raw += b" " * (-len(raw) % 4)
    return b"glTF" + struct.pack("<II",2,28+len(raw)) + struct.pack("<I4s", len(raw), b"JSON") + raw + struct.pack("<I4s", 0, b"BIN\x00")


class CoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root/"project.godot").write_text("config_version=5")
        for path in ["addons/furniture_manager/furniture_importer.gd", "addons/furniture_manager/furniture_catalog_registrar.gd", "data/items/_catalog.tres"]:
            dst = self.root/path
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text('[resource]\n', encoding="utf-8")
        (self.root/"tools").mkdir()
        (self.root/"godot.exe").write_bytes(b"mock")
        (self.root/"incoming.glb").write_bytes(make_glb())
        self.item = Item(project=str(self.root), godot=str(self.root/"godot.exe"), source=str(self.root/"incoming.glb"), item_id="new_chair", name="新椅子", group="seating", type="office_chair", price=250)

    def test_valid_preview(self):
        report = preview(self.item)
        self.assertIn("new_chair.glb", report)
        self.assertIn("250 点", report)
        self.assertEqual(inspect_glb(self.root/"incoming.glb")["mesh_count"], 1)

    def test_external_dependency_rejected(self):
        (self.root/"incoming.glb").write_bytes(make_glb(external=True))
        with self.assertRaisesRegex(PublishError, "外部依赖"):
            preview(self.item)

    def test_catalog_duplicate_id_rejected(self):
        (self.root/"data/items/_catalog.tres").write_text('item_id = "new_chair"\n')
        with self.assertRaisesRegex(PublishError, "已在目录"):
            preview(self.item)

    def test_overwrite_rejected(self):
        path = self.root/self.item.model_relative
        path.parent.mkdir(parents=True)
        path.write_bytes(b"DO NOT CHANGE")
        with self.assertRaisesRegex(PublishError,"不覆盖"):
            preview(self.item)
        self.assertEqual(path.read_bytes(), b"DO NOT CHANGE")

    def test_support_surfaces_and_invalid_price(self):
        self.item.support_surfaces = '[{"id":"top","x":0,"y":0.75,"z":0,"width":1.2,"depth":0.5}]'
        self.assertIn("承载面：1 个", preview(self.item))
        self.item.support_surfaces = '[{"id":"top","x":0,"y":0.75,"z":0,"width":-2,"depth":0.5}]'
        with self.assertRaises(PublishError): preview(self.item)
        self.item.support_surfaces = '[]'
        self.item.price = 0
        with self.assertRaises(PublishError): preview(self.item)

    def test_missing_godot_receipt_does_not_report_success(self):
        with patch('publisher_core._execute', return_value='Godot started but returned no result'):
            with self.assertRaisesRegex(PublishError, '明确的登记结果'):
                publish(self.item, log=lambda x: None)
        self.assertFalse(list((self.root/"tools").glob("_furniture_publish*")))

    def test_publish_uses_existing_godot_api_and_requires_success_receipt(self):
        commands = []
        original = (self.root/"data/items/_catalog.tres").read_bytes()
        def mock_run(cmd, cwd, log, timeout):
            commands.append(cmd)
            if "--import" in cmd:
                return ""
            manifest_file = self.root/"tools"/Path(cmd[-1]).name
            self.assertTrue(manifest_file.exists())
            manifest = json.loads(manifest_file.read_text())
            self.assertEqual(manifest["fields"]["item_id"], "new_chair")
            scene = self.root/self.item.scene_relative
            scene.write_text("valid scene", encoding="utf-8")
            catalog = self.root/"data/items/_catalog.tres"
            catalog.write_text(catalog.read_text()+'item_id = "new_chair"\n')
            return 'FURNITURE_PUBLISH_RESULT={"ok":true,"item_id":"new_chair"}'
        with patch('publisher_core._execute', side_effect=mock_run):
            r=publish(self.item, log=lambda x: None)
        self.assertEqual(len(commands), 2)
        self.assertTrue((self.root/self.item.model_relative).is_file())
        self.assertTrue((self.root/self.item.scene_relative).is_file())
        self.assertTrue(Path(r["backup"]).read_bytes() == original)
        self.assertFalse(list((self.root/"tools").glob("_furniture_publish*")))



class HardwareTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "project.godot").write_text("config_version=5")
        (self.root / "tools" / "FurniturePublisher").mkdir(parents=True)
        (self.root / "tools" / "FurniturePublisher" / "hardware_bridge.gd").write_text("extends SceneTree")
        (self.root / "data" / "hardware").mkdir(parents=True)
        (self.root / "data" / "hardware" / "_catalog.tres").write_text("[resource]")
        (self.root / "scripts" / "life").mkdir(parents=True)
        (self.root / "scripts" / "life" / "device_model.gd").write_text("extends Resource")
        (self.root / "scenes" / "computer" / "hardware").mkdir(parents=True)
        (self.root / "assets" / "models" / "hardware").mkdir(parents=True)
        (self.root / "godot.exe").write_bytes(b"mock")
        (self.root / "incoming.glb").write_bytes(make_glb())
        self.model = self.root / "assets" / "models" / "hardware" / "monitor_crt.glb"
        self.model.write_bytes(make_glb())
        self.config = self.root / "data" / "hardware" / "monitor_crt.tres"
        self.config.write_text('[ext_resource type="PackedScene" path="res://assets/models/hardware/monitor_crt.glb" id="2"]\n', encoding="utf-8")
        self.scene = self.root / "scenes" / "computer" / "hardware" / "monitor.tscn"
        self.scene.write_text('[ext_resource type="PackedScene" path="res://assets/models/hardware/monitor_crt.glb" id="3"]\n'
                              '[node name="Monitor" type="Node3D"]\nvisible = false\n'\n                              '[node name="DefaultModel" parent="Models" instance=ExtResource("3")]\n'
                              'scale = Vector3(0.45, 0.45, 0.45)\n', encoding="utf-8")
        self.item = HardwareItem(project=str(self.root), godot=str(self.root/"godot.exe"),
                                 source=str(self.root/"incoming.glb"), role="monitor", item_id="starter_monitor",
                                 width=0.36, height=0.35, depth=0.32,
                                 screen_width=0.29, screen_height=0.22, screen_y=0.22, screen_z=0.155)

    def test_preview_and_only_selected_model_scale(self):
        self.assertIn("starter_monitor", preview_hardware(self.item))
        updated = _unity_scale_scene(self.scene.read_text(), "DefaultModel")
        self.assertIn("scale = Vector3(1, 1, 1)", updated)
        self.assertEqual(updated.count("scale = Vector3"), 1)

    def test_invalid_screen_and_unregistered_id(self):
        self.item.screen_width = 2.0
        with self.assertRaisesRegex(PublishError, "屏幕"):
            preview_hardware(self.item)
        self.item.screen_width = 0.29
        self.item.item_id = "invented_monitor"
        with self.assertRaisesRegex(PublishError, "暂不允许自动新增"):
            preview_hardware(self.item)

    def test_failure_restores_original_model_scene_and_configuration(self):
        originals = [f.read_bytes() for f in (self.model, self.scene, self.config)]
        with patch("hardware_core._execute", side_effect=PublishError("test import failure")):
            with self.assertRaises(PublishError):
                publish_hardware(self.item, log=lambda _: None)
        self.assertEqual(originals, [f.read_bytes() for f in (self.model, self.scene, self.config)])
        self.assertFalse(list((self.root / "tools").glob("_hardware_publish_*")))

    def test_success_requires_godot_receipt(self):
        with patch("hardware_core._execute", return_value="Godot without receipt"):
            with self.assertRaisesRegex(PublishError, "未返回设备"):
                publish_hardware(self.item, log=lambda _: None)

    def test_godot_receipt_and_backup(self):
        original = self.model.read_bytes()
        def fake_execute(cmd, cwd, log, timeout):
            if "--import" in cmd:
                return ""
            manifest = json.loads((self.root / "tools" / Path(cmd[-1]).name).read_text())
            self.assertEqual(manifest["bounds"], [0.36, 0.35, 0.32])
            self.assertEqual(manifest["role"], "monitor")
            self.config.write_text("updated by Godot", encoding="utf-8")
            return 'HARDWARE_PUBLISH_RESULT={"ok":true,"model":"res://assets/models/hardware/monitor_crt.glb"}'
        with patch("hardware_core._execute", side_effect=fake_execute):
            result = publish_hardware(self.item, log=lambda _: None)
        self.assertEqual(self.model.read_bytes(), (self.root / "incoming.glb").read_bytes())
        self.assertIn("Vector3(1, 1, 1)", self.scene.read_text())
        self.assertEqual((Path(result["backup"]) / "assets/models/hardware/monitor_crt.glb").read_bytes(), original)




class RetiredHardwareActivationTests(unittest.TestCase):
    def test_reveal_root_and_preserve_nested_upgrade_visibility(self):
        scene = ('[node name="Monitor" type="Node3D"]\n'
                 'visible = false\n'
                 'script = ExtResource("1")\n'
                 '[node name="UpgradeModel" parent="Models" instance=ExtResource("4")]\n'
                 'visible = false\n')
        result = _activate_published_device(scene, "monitor")
        self.assertIn('[node name="Monitor" type="Node3D"]\nvisible = true', result)
        self.assertIn('[node name="UpgradeModel" parent="Models" instance=ExtResource("4")]\nvisible = false', result)
        self.assertEqual(result, _activate_published_device(result, "monitor"))

    def test_reject_unknown_or_changed_scene_root(self):
        with self.assertRaises(PublishError):
            _activate_published_device('[node name="Something" type="Node3D"]', "mouse")



if __name__ == "__main__": unittest.main()
