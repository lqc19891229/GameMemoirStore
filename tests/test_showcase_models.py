#!/usr/bin/env python3
"""Validate generated showcase GLBs, bounds, emissive materials and embedded dependencies."""
from __future__ import annotations

import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/models"

EXPECTED = {
    "hardware/case_beige.glb": ((-.236, 0.0, -.476), (.236, 1.0, .476)),
    "hardware/case_charcoal.glb": ((-.236, 0.0, -.476), (.236, 1.0, .476)),
    "hardware/monitor_crt.glb": ((-.801, 0.0, -.356), (.801, 1.366, .356)),
    "hardware/monitor_lcd.glb": ((-.801, 0.0, -.221), (.801, 1.351, .221)),
    "hardware/keyboard_beige.glb": ((-.626, 0.0, -.241), (.626, .101, .241)),
    "hardware/keyboard_charcoal.glb": ((-.626, 0.0, -.241), (.626, .101, .241)),
    "hardware/mouse_beige.glb": ((-.096, 0.0, -.156), (.096, .131, .156)),
    "hardware/mouse_charcoal.glb": ((-.096, 0.0, -.156), (.096, .131, .156)),
    "hardware/desk.glb": ((-2.401, 0.0, -1.151), (2.401, .801, 1.151)),
    "room/chair.glb": ((-.511, 0.0, -.421), (.511, 1.501, .421)),
}


def read_glb(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError(f"{path}: truncated GLB")
    magic, version, length = struct.unpack("<4sII", data[:12])
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError(f"{path}: invalid GLB header")
    offset = 12
    while offset + 8 <= len(data):
        chunk_length, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        chunk = data[offset + 8:offset + 8 + chunk_length]
        offset += 8 + chunk_length
        if chunk_type == 0x4E4F534A:
            return json.loads(chunk.decode("utf-8").rstrip(" \t\r\n\0"))
    raise ValueError(f"{path}: JSON chunk not found")


def bounds(doc: dict) -> tuple[list[float], list[float]]:
    mins, maxs = [], []
    for mesh in doc.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            accessor_index = primitive.get("attributes", {}).get("POSITION")
            if accessor_index is None:
                continue
            accessor = doc["accessors"][accessor_index]
            if "min" in accessor and "max" in accessor:
                mins.append(accessor["min"])
                maxs.append(accessor["max"])
    if not mins:
        raise ValueError("GLB has no POSITION bounds")
    return (
        [min(row[i] for row in mins) for i in range(3)],
        [max(row[i] for row in maxs) for i in range(3)],
    )


class ShowcaseModelTests(unittest.TestCase):
    def test_all_showcase_assets_exist_and_fit_existing_bounds(self):
        for relative, (expected_min, expected_max) in EXPECTED.items():
            with self.subTest(asset=relative):
                path = ASSETS / relative
                self.assertTrue(path.is_file(), f"missing {path}")
                doc = read_glb(path)
                actual_min, actual_max = bounds(doc)
                for axis in range(3):
                    self.assertGreaterEqual(actual_min[axis] + .002, expected_min[axis], f"{relative} min axis {axis}")
                    self.assertLessEqual(actual_max[axis] - .002, expected_max[axis], f"{relative} max axis {axis}")

    def test_premium_models_have_emissive_materials(self):
        for relative in [
            "hardware/case_charcoal.glb",
            "hardware/keyboard_charcoal.glb",
            "hardware/mouse_charcoal.glb",
        ]:
            with self.subTest(asset=relative):
                doc = read_glb(ASSETS / relative)
                emissive = [mat.get("emissiveFactor", [0, 0, 0]) for mat in doc.get("materials", [])]
                self.assertTrue(any(max(value) > .01 for value in emissive), f"{relative} has no emissive material")

    def test_glbs_have_no_external_dependencies(self):
        for relative in EXPECTED:
            with self.subTest(asset=relative):
                doc = read_glb(ASSETS / relative)
                for item in doc.get("buffers", []) + doc.get("images", []):
                    uri = item.get("uri", "")
                    self.assertFalse(uri and not uri.startswith("data:"), f"{relative} has external dependency: {uri}")


if __name__ == "__main__":
    unittest.main()
