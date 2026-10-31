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


def multiply(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def local_matrix(node: dict) -> list[list[float]]:
    if "matrix" in node:
        values = node["matrix"]
        return [[values[c * 4 + r] for c in range(4)] for r in range(4)]
    tx, ty, tz = node.get("translation", [0, 0, 0])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    rotation = [
        [1 - 2 * (y*y + z*z), 2 * (x*y - z*w), 2 * (x*z + y*w)],
        [2 * (x*y + z*w), 1 - 2 * (x*x + z*z), 2 * (y*z - x*w)],
        [2 * (x*z - y*w), 2 * (y*z + x*w), 1 - 2 * (x*x + y*y)],
    ]
    result = [[0.0] * 4 for _ in range(4)]
    for row in range(3):
        result[row][0] = rotation[row][0] * sx
        result[row][1] = rotation[row][1] * sy
        result[row][2] = rotation[row][2] * sz
    result[0][3], result[1][3], result[2][3] = tx, ty, tz
    result[3][3] = 1.0
    return result


def bounds(doc: dict) -> tuple[list[float], list[float]]:
    minima = [float("inf")] * 3
    maxima = [float("-inf")] * 3
    accessors = doc.get("accessors", [])
    nodes = doc.get("nodes", [])

    def visit(index: int, parent: list[list[float]]) -> None:
        node = nodes[index]
        world = multiply(parent, local_matrix(node))
        mesh_index = node.get("mesh")
        if mesh_index is not None:
            for primitive in doc["meshes"][mesh_index].get("primitives", []):
                position_index = primitive.get("attributes", {}).get("POSITION")
                if position_index is None:
                    continue
                accessor = accessors[position_index]
                if "min" not in accessor or "max" not in accessor:
                    continue
                for x in [accessor["min"][0], accessor["max"][0]]:
                    for y in [accessor["min"][1], accessor["max"][1]]:
                        for z in [accessor["min"][2], accessor["max"][2]]:
                            point = [x, y, z, 1.0]
                            transformed = [
                                sum(world[row][col] * point[col] for col in range(4))
                                for row in range(3)
                            ]
                            for axis in range(3):
                                minima[axis] = min(minima[axis], transformed[axis])
                                maxima[axis] = max(maxima[axis], transformed[axis])
        for child in node.get("children", []):
            visit(child, world)

    scene_index = doc.get("scene", 0)
    roots = doc.get("scenes", [{}])[scene_index].get("nodes", [])
    identity = [[1.0 if row == col else 0.0 for col in range(4)] for row in range(4)]
    for root in roots:
        visit(root, identity)
    if any(value == float("inf") for value in minima):
        raise ValueError("GLB has no POSITION bounds")
    return minima, maxima


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
