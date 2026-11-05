"""Offline gaming-chair GLB PBR bake regression (never rewrites runtime assets)."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools/models/bake_chair_gaming_materials.py"
spec = importlib.util.spec_from_file_location("chair_bake", SCRIPT)
baker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baker)


class ChairBakeTest(unittest.TestCase):
    def test_polished_material_palette_and_roughness(self):
        # Offline parameters are authoritative for the generated GLB, not
        # transient runtime material overrides.
        expected = {
            "graphite": ("343b44", "plastic"),
            "steel": ("646b73", "metal"),
            "wheel_hub": ("444c55", "metal"),
            "leather_cream": ("ded5c7", "leather"),
            "leather_pearl": ("d0c9bd", "leather"),
            "edge_welt": ("666c72", "leather"),
        }
        for part, (hex_color, family) in expected.items():
            preset, color = baker.PARTS[part]
            self.assertEqual(color, hex_color)
            self.assertEqual(preset.split("/")[0], family)
        self.assertGreaterEqual(baker.PRESETS["leather"][1], 0.8)
        self.assertGreaterEqual(baker.PRESETS["plastic"][1], 0.8)
        self.assertGreater(baker.PRESETS["rubber"][1], baker.PRESETS["metal"][1])
        self.assertLess(baker.PRESETS["metal"][0], 1.0)

    def test_bake_is_self_contained_and_preserves_geometry(self):
        self.assertTrue(baker.SOURCE.is_file())
        source, binary = baker.parse(baker.SOURCE.read_bytes())
        for family in ("leather", "fabric", "metal"):
            maps = baker.maps(family)
            self.assertEqual(set(maps), {"albedo", "roughness", "normal"})
            for payload in maps.values():
                self.assertTrue(payload.startswith(b"\x89PNG\r\n\x1a\n"))
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / "chair_finished.glb"
            info = baker.bake(baker.SOURCE, out)
            self.assertEqual(info["parts"], 12)
            self.assertGreaterEqual(info["embedded_textures"], 9)
            baked, baked_binary = baker.parse(out.read_bytes())
            self.assertEqual(source["nodes"], baked["nodes"])
            self.assertEqual(source["accessors"], baked["accessors"])
            self.assertEqual(source["buffers"][0]["byteLength"], len(binary))
            already_baked = all(
                any(material.get("name") == name for material in source.get("materials", []))
                for name in baker.PARTS
            )
            if already_baked:
                self.assertEqual(baked_binary, binary)
                self.assertEqual(out.read_bytes(), baker.SOURCE.read_bytes())
            else:
                self.assertGreater(len(baked_binary), len(binary))
            self.assertGreaterEqual(len(baked.get("images", [])), 9)
            for name in baker.PARTS:
                node = next(n for n in baked["nodes"] if n.get("name") == name)
                for primitive in baked["meshes"][node["mesh"]]["primitives"]:
                    self.assertIn("material", primitive)
                    material = baked["materials"][primitive["material"]]
                    self.assertIn("pbrMetallicRoughness", material)
                    if baker.PARTS[name][0].split("/")[0] in baker.PATTERNS:
                        self.assertIn("normalTexture", material)
                    self.assertIn("TEXCOORD_0", primitive["attributes"])


if __name__ == "__main__":
    unittest.main()
