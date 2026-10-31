#!/usr/bin/env python3
"""Check Godot resource paths, import sidecars, UIDs, GLB structure and unused candidates."""
from __future__ import annotations

import argparse
from collections import defaultdict
import glob
import hashlib
import json
from pathlib import Path
import re
import struct

SOURCE_SUFFIXES = {".gd", ".tscn", ".tres", ".godot"}
ASSET_SUFFIXES = {".png", ".glb", ".ttf", ".gdshader"}
REFERENCE = re.compile(r'''["'](res://[^"'\r\n]+)["']''')
UID = re.compile(r"uid://[a-z0-9]+")
CLASS_NAME = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
IGNORED = {".git", ".godot", "__pycache__", ".venv", "venv"}


def audit(project: Path) -> dict:
    files = sorted(
        p for p in project.rglob("*")
        if p.is_file() and not IGNORED.intersection(p.relative_to(project).parts)
    )
    problems: list[str] = []
    dynamic: list[dict] = []
    incoming: dict[str, set[str]] = defaultdict(set)
    uids: dict[str, list[str]] = defaultdict(list)
    source_texts: dict[str, str] = {}

    for file in files:
        relative = file.relative_to(project).as_posix()

        if file.suffix in SOURCE_SUFFIXES:
            content = file.read_text(encoding="utf-8")
            source_texts[relative] = content
            for match in REFERENCE.finditer(content):
                uri = match.group(1)
                if "%" in uri or "{" in uri:
                    pattern = re.sub(r"%[0-9.]*[sdf]|\{[^}]*\}", "*", uri[6:])
                    matches = glob.glob(str(project / pattern))
                    dynamic.append({
                        "source": relative,
                        "pattern": uri,
                        "matches": len(matches),
                    })
                    for path in matches:
                        incoming[Path(path).relative_to(project).as_posix()].add(relative)
                    # Scripts may format a suffix after the quoted expression.
                    if not matches and Path(pattern).suffix:
                        problems.append(f"{relative}: unresolved dynamic path {uri}")
                elif not (project / uri[6:]).exists():
                    problems.append(f"{relative}: missing {uri}")
                else:
                    incoming[uri[6:]].add(relative)

        if file.suffix == ".uid":
            if not file.with_suffix("").is_file():
                problems.append(f"{relative}: orphan script UID")
            uids[file.read_text(encoding="utf-8").strip()].append(relative)

        if file.suffix == ".gd" and not file.with_suffix(".gd.uid").is_file():
            problems.append(f"{relative}: missing script UID")

        if file.suffix == ".import":
            if not file.with_suffix("").is_file():
                problems.append(f"{relative}: orphan import settings")
            content = file.read_text(encoding="utf-8")
            source = re.search(r'source_file="res://([^"\n]+)"', content)
            if not source or project / source.group(1) != file.with_suffix(""):
                problems.append(f"{relative}: import source mismatch")
            uid = re.search(r'^uid="(uid://[a-z0-9]+)"', content, re.MULTILINE)
            if uid:
                uids[uid.group(1)].append(relative)

        if file.suffix == ".glb":
            data = file.read_bytes()
            if len(data) < 20 or struct.unpack("<4sII", data[:12]) != (b"glTF", 2, len(data)):
                problems.append(f"{relative}: invalid GLB header")
                continue
            size, kind = struct.unpack("<II", data[12:20])
            if kind != 0x4E4F534A or 20 + size > len(data):
                problems.append(f"{relative}: missing or invalid GLB JSON chunk")
                continue
            try:
                model = json.loads(data[20:20 + size])
            except (UnicodeDecodeError, json.JSONDecodeError):
                problems.append(f"{relative}: invalid GLB JSON")
                continue
            for entry in model.get("buffers", []) + model.get("images", []):
                uri = entry.get("uri", "")
                if uri and not uri.startswith("data:"):
                    problems.append(f"{relative}: unexpected external model dependency {uri}")

    # Resolve global class_name references as well as explicit res:// script paths.
    class_names: dict[str, list[str]] = defaultdict(list)
    for relative, content in source_texts.items():
        if relative.endswith(".gd"):
            match = CLASS_NAME.search(content)
            if match:
                class_names[match.group(1)].append(relative)

    for name, paths in class_names.items():
        if len(paths) > 1:
            problems.append(f"duplicate class_name {name}: {paths}")
        for path in paths:
            for source, content in source_texts.items():
                if source != path and re.search(rf"\b{re.escape(name)}\b", content):
                    incoming[path].add(source)

    for uid, paths in uids.items():
        if not UID.fullmatch(uid):
            problems.append(f"invalid UID: {paths}")
        if len(paths) > 1:
            problems.append(f"duplicate UID {uid}: {paths}")

    candidates: list[str] = []
    for file in files:
        relative = file.relative_to(project).as_posix()
        if incoming[relative]:
            continue
        if file.suffix in {".tscn", ".tres"}:
            candidates.append(relative)
        elif file.suffix == ".gd" and not relative.startswith("tests/"):
            candidates.append(relative)
        elif file.is_relative_to(project / "assets") and file.suffix in ASSET_SUFFIXES:
            candidates.append(relative)

    hashes: dict[str, list[str]] = defaultdict(list)
    for file in files:
        if file.is_relative_to(project / "assets") and file.suffix in {".png", ".glb", ".ttf"}:
            hashes[hashlib.sha256(file.read_bytes()).hexdigest()].append(
                file.relative_to(project).as_posix()
            )

    return {
        "files": len(files),
        "scenes": sum(p.suffix == ".tscn" for p in files),
        "problems": problems,
        "unreferenced_candidates": candidates,
        "duplicate_assets": [paths for paths in hashes.values() if len(paths) > 1],
        "dynamic_paths": dynamic,
        "global_classes": {name: paths for name, paths in class_names.items()},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    result = audit(args.project.resolve())
    print(json.dumps(result, ensure_ascii=False, indent=2))
    # Candidates are for manual review only; never delete project files automatically.
    return 1 if result["problems"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
