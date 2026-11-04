#!/usr/bin/env python3
"""Plan or perform a reversible-in-process furniture folder migration.

Run from repository root:
    python tools/migrate_furniture_folders.py
    python tools/migrate_furniture_folders.py --apply

Review and commit the resulting Git diff. Requires a clean Git worktree to apply.
Never touches .godot caches, user saves, or item IDs.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL_ROOT = ROOT / "assets/models/room"
LEGACY_MODELS = MODEL_ROOT / "catalog"
SCENE_ROOT = ROOT / "scenes/room"
CATALOG = ROOT / "data/items/_catalog.tres"
GROUPS = ("tables", "seating", "storage", "lighting", "decor")
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".md", ".txt", ".yml", ".yaml", ".import", ".gdshader", ".material"}


def classify(name: str) -> str:
    """Conservative fallback for unregistered assets."""
    stem = name.lower()
    if any(t in stem for t in ("desk", "table")):
        return "tables"
    if any(t in stem for t in ("chair", "sofa", "stool", "bench", "cushion", "podium")):
        return "seating"
    if any(t in stem for t in ("shelf", "bookcase", "cabinet", "console", "crate")):
        return "storage"
    if any(t in stem for t in ("lamp", "light", "sconce")):
        return "lighting"
    return "decor"


def catalog_groups() -> dict[str, str]:
    """Read real catalog_group for known furniture scenes, not guessed role IDs."""
    text = CATALOG.read_text(encoding="utf-8")
    scenes = dict(re.findall(
        r'\[ext_resource[^\n]*type="PackedScene"[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"',
        text,
    ))
    by_id = {resource_id: path for path, resource_id in scenes.items()}
    result: dict[str, str] = {}
    for block in re.split(r'(?=\[sub_resource )', text):
        if 'category = "furniture"' not in block:
            continue
        group = re.search(r'^catalog_group = "([^"]+)"', block, re.M)
        linked = re.search(r'^furniture_scene = ExtResource\("([^"]+)"\)', block, re.M)
        if linked:
            path = by_id.get(linked.group(1))
            if path:
                desired = group.group(1) if group and group.group(1) in GROUPS else classify(Path(path).stem)
                result[path] = desired
    return result


def res_path(file: Path) -> str:
    return "res://" + file.relative_to(ROOT).as_posix()


def build_plan() -> dict[Path, Path]:
    mappings: dict[Path, Path] = {}
    known = catalog_groups()
    scene_groups: dict[str, str] = {}
    for scene in SCENE_ROOT.glob("*.tscn"):
        path = res_path(scene)
        contents = scene.read_text(encoding="utf-8")
        # Keep room shells, blueprint and game scenes where they already are.
        if path not in known and "room_furniture.gd" not in contents:
            continue
        group = known.get(path, classify(scene.stem))
        scene_groups[scene.stem] = group
        mappings[scene] = SCENE_ROOT / group / scene.name

    if LEGACY_MODELS.exists():
        for model in LEGACY_MODELS.rglob("*"):
            if not model.is_file() or model.suffix.lower() not in (".glb", ".gltf"):
                continue
            group = scene_groups.get(model.stem, classify(model.stem))
            mappings[model] = MODEL_ROOT / group / model.name

    # Preserve Godot UIDs and tracked import settings beside moved resources.
    for old, new in list(mappings.items()):
        for sidecar in (old.with_name(old.name + ".uid"), old.with_name(old.name + ".import")):
            if sidecar.exists():
                mappings[sidecar] = new.with_name(new.name + sidecar.name[len(old.name):])
    return mappings


def check_plan(moves: dict[Path, Path]) -> None:
    destinations = list(moves.values())
    if len(set(destinations)) != len(destinations):
        raise RuntimeError("Two source files map to the same destination")
    for old, new in moves.items():
        if new.exists() and old != new:
            raise RuntimeError(f"Destination already exists: {new}")
        if not old.is_file() or not old.resolve().is_relative_to(ROOT):
            raise RuntimeError(f"Invalid source: {old}")
        if not new.resolve().is_relative_to(ROOT):
            raise RuntimeError(f"Invalid target: {new}")


def text_updates(moves: dict[Path, Path]) -> dict[Path, bytes]:
    translations = {res_path(old): res_path(new) for old, new in moves.items()
                    if old.suffix.lower() in (".tscn", ".glb", ".gltf")}
    changes: dict[Path, bytes] = {}
    for file in ROOT.rglob("*"):
        if not file.is_file() or file.suffix.lower() not in TEXT_SUFFIXES:
            continue
        if any(part in (".git", ".godot", "__pycache__") for part in file.relative_to(ROOT).parts):
            continue
        try:
            original = file.read_bytes()
            decoded = original.decode("utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        revised = decoded
        # Exact, absolute Godot resource references only.
        for before, after in sorted(translations.items(), key=lambda x: -len(x[0])):
            revised = revised.replace(before, after)
        if revised != decoded:
            changes[file] = revised.encode("utf-8")
    return changes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Move resources and rewrite references")
    args = parser.parse_args()
    moves = build_plan()
    check_plan(moves)
    edits = text_updates(moves)
    print(f"Plan: {len(moves)} resource/sidecar moves; {len(edits)} text files with path updates")
    for old, new in sorted(moves.items()):
        print(f"  {old.relative_to(ROOT)} -> {new.relative_to(ROOT)}")
    if not args.apply:
        print("Dry run only. Review the plan, then rerun with --apply.")
        return
    status = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, check=True,
                            capture_output=True, text=True)
    if status.stdout.strip():
        raise RuntimeError("Git worktree must be clean before migration")
    original_bytes = {file: file.read_bytes() for file in edits}
    completed: list[tuple[Path, Path]] = []
    try:
        for old, new in moves.items():
            new.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(old), str(new))
            completed.append((old, new))
        for old_file, replacement in edits.items():
            target = moves.get(old_file, old_file)
            target.write_bytes(replacement)
    except Exception:
        for old_file, data in original_bytes.items():
            target = moves.get(old_file, old_file)
            if target.exists():
                target.write_bytes(data)
        for old, new in reversed(completed):
            old.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(new), str(old))
        raise
    print("Migration applied. Reimport in Godot, run project CI and inspect git diff.")


if __name__ == "__main__":
    main()
