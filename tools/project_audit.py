#!/usr/bin/env python3
"""Check Godot resource paths, import sidecars, UIDs and unused asset candidates."""
from __future__ import annotations
import argparse
from collections import defaultdict
import glob
import hashlib
import json
from pathlib import Path
import re
import struct

SOURCE_SUFFIXES = {'.gd', '.tscn', '.tres', '.godot'}
REFERENCE = re.compile(r'''["'](res://[^"'\r\n]+)["']''')
UID = re.compile(r'uid://[a-z0-9]+')
IGNORED = {'.git', '.godot', '__pycache__'}


def audit(project: Path) -> dict:
    files = sorted(p for p in project.rglob('*') if p.is_file() and not IGNORED.intersection(p.relative_to(project).parts))
    problems, dynamic = [], []
    incoming = defaultdict(set)
    uids = defaultdict(list)
    for file in files:
        relative = file.relative_to(project).as_posix()
        if file.suffix in SOURCE_SUFFIXES:
            text = file.read_text(encoding='utf-8')
            for match in REFERENCE.finditer(text):
                uri = match.group(1)
                if '%' in uri or '{' in uri:
                    pattern = re.sub(r'%[0-9.]*[sdf]|\{[^}]*\}', '*', uri[6:])
                    matches = glob.glob(str(project / pattern))
                    dynamic.append({'source': relative, 'pattern': uri, 'matches': len(matches)})
                    for path in matches: incoming[Path(path).relative_to(project).as_posix()].add(relative)
                    # Scripts may format a suffix after the quoted expression.
                    if not matches and Path(pattern).suffix: problems.append(f'{relative}: unresolved dynamic path {uri}')
                elif not (project / uri[6:]).exists():
                    problems.append(f'{relative}: missing {uri}')
                else:
                    incoming[uri[6:]].add(relative)
        if file.suffix == '.uid':
            if not file.with_suffix('').is_file(): problems.append(f'{relative}: orphan script UID')
            uids[file.read_text().strip()].append(relative)
        if file.suffix == '.gd' and not file.with_suffix('.gd.uid').is_file():
            problems.append(f'{relative}: missing script UID')
        if file.suffix == '.import':
            if not file.with_suffix('').is_file(): problems.append(f'{relative}: orphan import settings')
            text = file.read_text()
            source = re.search(r'source_file="res://([^"\n]+)"', text)
            if not source or project / source.group(1) != file.with_suffix(''):
                problems.append(f'{relative}: import source mismatch')
            uid = re.search(r'^uid="(uid://[a-z0-9]+)"', text, re.M)
            if uid: uids[uid.group(1)].append(relative)
        if file.suffix == '.glb':
            data = file.read_bytes()
            if len(data) < 20 or struct.unpack('<4sII',data[:12]) != (b'glTF',2,len(data)):
                problems.append(f'{relative}: invalid GLB header')
                continue
            size, kind = struct.unpack('<II',data[12:20])
            if kind != 0x4E4F534A:
                problems.append(f'{relative}: missing GLB JSON chunk')
                continue
            model = json.loads(data[20:20+size])
            for entry in model.get('buffers',[]) + model.get('images',[]):
                if entry.get('uri','') and not entry['uri'].startswith('data:'):
                    problems.append(f'{relative}: unexpected external model dependency {entry["uri"]}')
    for uid, paths in uids.items():
        if not UID.fullmatch(uid): problems.append(f'invalid UID: {paths}')
        if len(paths) > 1: problems.append(f'duplicate UID {uid}: {paths}')
    candidates = [p.relative_to(project).as_posix() for p in files if (p.suffix == '.tscn' or ('assets' in p.relative_to(project).parts and p.suffix in {'.png','.glb','.ttf'})) and not incoming[p.relative_to(project).as_posix()]]
    hashes = defaultdict(list)
    for file in files:
        if file.is_relative_to(project/'assets') and file.suffix in {'.png','.glb','.ttf'}:
            hashes[hashlib.sha256(file.read_bytes()).hexdigest()].append(file.relative_to(project).as_posix())
    return {'files': len(files), 'scenes': sum(p.suffix == '.tscn' for p in files), 'problems': problems, 'unreferenced_candidates': candidates, 'duplicate_assets': [v for v in hashes.values() if len(v)>1], 'dynamic_paths': dynamic}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    args=parser.parse_args()
    result=audit(args.project.resolve())
    print(json.dumps(result,ensure_ascii=False,indent=2))
    # Unreferenced paths are candidates for review; source art and fixture use may be intentional.
    return 1 if result['problems'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
