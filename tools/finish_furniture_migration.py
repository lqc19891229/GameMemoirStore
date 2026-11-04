#!/usr/bin/env python3
"""Finish a committed furniture-folder move by rewriting exact res:// references.

This is intentionally idempotent and never edits binary models or saved games.
It derives renamed paths from Git's main tree, including moved scene, model,
texture, and import sidecar resources. Run after moving the files.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GROUPS = {"tables", "seating", "storage", "lighting", "decor"}
EXTENSIONS = {".gd", ".tscn", ".tres", ".import", ".py", ".json",
              ".md", ".yml", ".yaml", ".txt", ".cfg", ".godot", ".gdshader", ".bat"}

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

def references() -> dict[str, str]:
    baseline = set(git("ls-tree", "-r", "--name-only", "main").splitlines())
    current = set(git("ls-files").splitlines())
    mapping = {}
    for new in sorted(current - baseline):
        parts = new.split("/")
        if len(parts) < 4 or parts[2] not in GROUPS:
            continue
        old = ""
        if parts[:2] == ["scenes", "room"]:
            old = "scenes/room/" + parts[-1]
        elif parts[:3] == ["assets", "models", "room"] and len(parts) >= 5:
            old = "assets/models/room/catalog/" + parts[-1]
            if old not in baseline:
                old = "assets/models/room/" + parts[-1]
        if old in baseline and old not in current and not old.endswith(".import"):
            mapping["res://" + old] = "res://" + new
    return mapping

def main() -> None:
    mapping = references()
    if len(mapping) < 50:
        raise RuntimeError(f"Expected many moved resources; found {len(mapping)}. Refusing partial rewrite.")
    updates = []
    for name in git("ls-files").splitlines():
        file = ROOT / name
        if not file.is_file() or file.suffix.lower() not in EXTENSIONS:
            continue
        try:
            original = file.read_text(encoding="utf-8")
        except (UnicodeError, OSError):
            continue
        revised = original
        for old, new in sorted(mapping.items(), key=lambda x: -len(x[0])):
            revised = revised.replace(old, new)
        if revised != original:
            file.write_text(revised, encoding="utf-8")
            updates.append(name)
    print(f"Rewrote {len(updates)} tracked text files for {len(mapping)} migrated resource paths")
    for name in updates:
        print("  ", name)
    # No legacy literal reference to a moved asset may remain in a text file.
    for name in git("ls-files").splitlines():
        file = ROOT / name
        if not file.is_file() or file.suffix.lower() not in EXTENSIONS:
            continue
        try:
            txt = file.read_text(encoding="utf-8")
        except (UnicodeError, OSError):
            continue
        old_hits = [old for old in mapping if old in txt]
        if old_hits:
            raise RuntimeError(f"Stale asset references in {name}: {old_hits[:5]}")
    print("All exact legacy furniture references replaced.")

if __name__ == "__main__":
    main()
