#!/usr/bin/env python3
"""Excel → Godot 4.6 resources. Python 3.10+, standard library only."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

HERE = Path(__file__).resolve().parent
NS = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
REL = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id'
ID_RE = re.compile(r'[a-z][a-z0-9_]*\Z')
MARKER = '.memoir_generated.json'
OWNER = 'GameMemoir.ExcelImporter.v1'


class ImportFailure(Exception):
    pass


def column_index(ref: str) -> int:
    match = re.match(r'([A-Z]+)', ref)
    if not match:
        raise ImportFailure(f'无效单元格坐标：{ref}')
    result = 0
    for char in match.group(1):
        result = result * 26 + ord(char) - 64
    return result - 1


def read_xlsx(path: Path, schema: dict) -> dict:
    """Read values without executing formulas; supports Excel shared/inline strings."""
    result = {}
    with zipfile.ZipFile(path) as archive:
        if sum(info.file_size for info in archive.infolist()) > 100_000_000:
            raise ImportFailure('工作簿解压后超过100MB，请拆分工作簿')
        shared = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            root = ET.fromstring(archive.read('xl/sharedStrings.xml'))
            shared = [''.join(t.text or '' for t in item.findall('.//s:t', NS)) for item in root]
        rels = ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))
        relation = {item.attrib['Id']: item.attrib['Target'] for item in rels}
        workbook = ET.fromstring(archive.read('xl/workbook.xml'))
        for sheet in workbook.findall('s:sheets/s:sheet', NS):
            name = sheet.attrib['name']
            if name not in schema['sheets']:
                continue
            target = relation[sheet.attrib[REL]]
            member = target.lstrip('/') if target.startswith('/') else 'xl/' + target
            member = str(PurePosixPath(member))
            xml = ET.fromstring(archive.read(member))
            rows = {}
            for row in xml.findall('s:sheetData/s:row', NS):
                rownum = int(row.attrib['r'])
                values = {}
                for cell in row.findall('s:c', NS):
                    index = column_index(cell.attrib['r'])
                    if cell.find('s:f', NS) is not None:
                        value = ('FORMULA',)
                    else:
                        typ = cell.attrib.get('t', 'n')
                        val = cell.find('s:v', NS)
                        text = val.text if val is not None else None
                        if typ == 's':
                            value = shared[int(text)] if text else ''
                        elif typ == 'inlineStr':
                            value = ''.join(t.text or '' for t in cell.findall('.//s:t', NS))
                        elif typ in ('str', 'd'):
                            value = text or ''
                        elif typ in ('e', 'b'):
                            value = ('INVALID', text)
                        elif not text:
                            value = ''
                        else:
                            value = float(text)
                    if value != '':
                        values[index] = value
                rows[rownum] = values
            # Find the header by its machine field names, preserving the user's layout.
            expected = [field['key'] for field in schema['sheets'][name]]
            aliases = schema.get('header_aliases', {})
            header_row = None
            keys = None
            for rownum, candidate in sorted(rows.items()):
                if rownum > 100:
                    break
                current = {col: aliases.get(str(value).split('\n')[-1].strip(), str(value).split('\n')[-1].strip()) for col, value in candidate.items()}
                if 'game_id' in current.values() and 'enabled' in current.values():
                    header_row, keys = rownum, current
                    break
            if header_row is None:
                raise ImportFailure(f'{name}：未找到包含game_id和enabled的表头（查找前100行）')
            if len(set(keys.values())) != len(keys):
                raise ImportFailure(f'{name}：列名重复')
            missing = set(expected) - set(keys.values())
            extra = set(keys.values()) - set(expected)
            if missing or extra:
                raise ImportFailure(f'{name}：列名不匹配，缺少 {sorted(missing)}，未知 {sorted(extra)}；CPU/GPU列名或cpu/gpu均可')
            result[name] = []
            for rownum, cells in sorted(rows.items()):
                if rownum <= header_row or not cells:
                    continue
                values = {key: cells.get(col, '') for col, key in keys.items()}
                # Ignore empty appended rows even if they contain an enabled default.
                if not any(value != '' for key, value in values.items() if key != 'enabled'):
                    continue
                result[name].append((rownum, values))
    missing = set(schema['sheets']) - set(result)
    if missing:
        raise ImportFailure(f'缺少工作表：{sorted(missing)}')
    return result


def as_int(value, label: str) -> int:
    if isinstance(value, bool) or isinstance(value, tuple):
        raise ImportFailure(f'{label}必须是整数值，不接受公式、错误或布尔值')
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise ImportFailure(f'{label}必须是整数') from None
    if not math.isfinite(number) or not number.is_integer() or abs(number) > 2_147_483_647:
        raise ImportFailure(f'{label}必须是32位范围内的整数')
    return int(number)


def parse_field(value, field):
    key, typ = field['key'], field['type']
    if value == '' or value is None:
        if field['required']:
            raise ImportFailure(f'{key}不能为空')
        value = field['default']
    if isinstance(value, tuple):
        raise ImportFailure(f'{key}不接受公式、错误或布尔值，请直接填值')
    if typ in ('int', 'month', 'month0'):
        value = as_int(value, key)
        if value < 0:
            raise ImportFailure(f'{key}不能为负数')
        if typ.startswith('month') and not (typ == 'month0' and value == 0):
            if not (100001 <= value <= 999912 and 1 <= value % 100 <= 12):
                raise ImportFailure(f'{key}应为YYYYMM整数，例如200309，不能使用Excel日期')
        if key == 'enabled' and value not in (0, 1):
            raise ImportFailure('enabled仅接受0或1')
        if key in ('discount_percent', 'positive_percent') and value > 100:
            raise ImportFailure(f'{key}应在0到100之间，25表示25个百分点')
        return value
    if not isinstance(value, str):
        raise ImportFailure(f'{key}必须是文本')
    value = value.strip()
    if field['required'] and not value:
        raise ImportFailure(f'{key}不能为空白文本')
    if '\x00' in value or any(ord(c) < 32 and c not in '\t\r\n' for c in value):
        raise ImportFailure(f'{key}含有不支持的控制字符')
    if typ in ('id', 'id0'):
        if not (typ == 'id0' and not value) and not ID_RE.fullmatch(value):
            raise ImportFailure(f'{key}必须以小写字母开头，仅包含小写字母、数字和下划线')
    if typ in ('list', 'paths'):
        values = [item.strip() for item in value.split(';') if item.strip()]
        if len(values) != len(set(values)):
            raise ImportFailure(f'{key}中出现重复项')
        if typ == 'paths':
            for item in values:
                check_path(item)
        return values
    if typ == 'path' and value:
        check_path(value)
    return value


def check_path(value):
    parts = value.removeprefix('res://').split('/')
    if not value.startswith('res://') or any(p in ('', '.', '..') for p in parts) or '\\' in value or any(c in value for c in ('\n','\r','\t',';')):
        raise ImportFailure(f'资源路径无效：{value}，请使用res://且不要包含上级目录')


def validate(raw, schema, project=None, skip_assets=False):
    errors = []
    games = []
    known_ids = set()
    name = '游戏资料'
    for rownum, row in raw[name]:
        location = f'{name} 第{rownum}行'
        try:
            enabled = as_int(row.get('enabled', ''), 'enabled')
            if enabled not in (0, 1):
                raise ImportFailure('enabled仅接受0或1')
            game_id = parse_field(row.get('game_id', ''), {'key':'game_id','type':'id','required':True})
            if game_id in known_ids:
                raise ImportFailure(f'重复game_id：{game_id}')
            known_ids.add(game_id)
            if not enabled:
                continue
            game = {field['key']: parse_field(row.get(field['key'], ''), field) for field in schema['sheets'][name]}
            game['_location'] = location
            if game['announce_ym'] and game['announce_ym'] > game['store_release_ym']:
                raise ImportFailure('预告月份不能晚于上架月份')
            if game['delist_ym'] and game['delist_ym'] <= game['store_release_ym']:
                raise ImportFailure('下架月份必须晚于上架月份')
            if project and not skip_assets and game['capsule']:
                local = (project / game['capsule'][6:]).resolve()
                if not local.is_relative_to(project.resolve()) or not local.is_file():
                    raise ImportFailure(f'封面文件不存在或不在项目内：{game["capsule"]}')
            games.append(game)
        except ImportFailure as exc:
            errors.append(f'{location}：{exc}')
    if not games:
        errors.append('没有可导出的游戏，请至少启用一条完整的游戏资料')
    if errors:
        raise ImportFailure('\n'.join(errors))
    return {'游戏资料':games}, []


def quote(value):
    return json.dumps(value, ensure_ascii=False)


def packed(values):
    return 'PackedStringArray(' + ', '.join(quote(v) for v in values) + ')'


def resource_game(game, base_uri):
    ext = [('Script', base_uri + '/types/game_definition.gd', '1_game')]
    if game['capsule']:
        ext.append(('Texture2D', game['capsule'], '2_capsule'))
    lines = [f'[gd_resource type="Resource" script_class="GameDefinition" load_steps={len(ext)+1} format=3]', '']
    lines += [f'[ext_resource type="{typ}" path={quote(path)} id="{ident}"]' for typ, path, ident in ext]
    lines += ['', '[resource]', 'script = ExtResource("1_game")']
    for key in ('game_id','title','announce_ym','store_release_ym','delist_ym','base_price','developer','genres','cpu','gpu','series_id','description','capsule'):
        if key in ('game_id', 'series_id'):
            value = '&' + quote(game[key])
        elif key in ('announce_ym','store_release_ym','delist_ym','base_price'):
            value = str(game[key])
        elif key == 'genres':
            value = packed(game[key])
        elif key == 'capsule':
            value = 'ExtResource("2_capsule")' if game[key] else 'null'
        else:
            value = quote(game[key])
        lines.append(f'{key} = {value}')
    return '\n'.join(lines) + '\n'


def render_files(data, output_rel):
    uri = 'res://' + output_rel
    games = list(data['游戏资料'])  # Keep the spreadsheet's storefront order.
    files = {}
    for path in sorted((HERE / 'resource_types').glob('*.gd')):
        files['types/' + path.name] = path.read_bytes()
    if set(files) != {'types/game_definition.gd', 'types/game_catalog.gd'}:
        raise ImportFailure('resource_types目录应包含GameDefinition和GameCatalog两个脚本，请解压完整工具包')
    for game in games:
        files[f'games/{game["game_id"]}.tres'] = resource_game(game, uri).encode('utf-8')
    lines = [f'[gd_resource type="Resource" script_class="GameCatalog" load_steps={len(games)+3} format=3]', '', f'[ext_resource type="Script" path="{uri}/types/game_catalog.gd" id="1_catalog"]', f'[ext_resource type="Script" path="{uri}/types/game_definition.gd" id="2_game"]']
    for i, game in enumerate(games):
        lines.append(f'[ext_resource type="Resource" path="{uri}/games/{game["game_id"]}.tres" id="game_{i}"]')
    refs = ', '.join(f'ExtResource("game_{i}")' for i in range(len(games)))
    lines += ['', '[resource]', 'script = ExtResource("1_catalog")', f'games = Array[ExtResource("2_game")]([{refs}])', '']
    files['catalog.tres'] = '\n'.join(lines).encode('utf-8')
    return files


def sha(data):
    return hashlib.sha256(data).hexdigest()


def check_output(project, output_rel, files):
    output = project / output_rel
    if output.is_symlink() or not output.resolve().is_relative_to(project.resolve()):
        raise ImportFailure('输出目录不得通过链接指向项目外部')
    problems = []
    for relative, expected in files.items():
        path = output / relative
        if path.is_symlink() or not path.is_file() or path.read_bytes() != expected:
            problems.append(relative)
    if output.is_dir():
        for path in output.rglob('*'):
            relative = path.relative_to(output).as_posix()
            if not path.is_file() or relative == MARKER or relative in files:
                continue
            if relative.endswith('.gd.uid') and relative[:-4] in files:
                continue
            problems.append(relative + '（多余文件）')
    if problems:
        raise ImportFailure('生成资源与表格或模板不一致，请重新导入：\n' + '\n'.join(problems))


def write_output(project, output_rel, files):
    # This directory is exclusively generated. Reject untracked or edited files.
    output = project / output_rel
    output_parent = output.parent
    preserved_uids = {}
    if output.is_symlink() or not output.resolve().is_relative_to(project.resolve()):
        raise ImportFailure('输出目录不得通过链接指向项目外部')
    if output.exists():
        marker = output / MARKER
        try:
            previous = json.loads(marker.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            raise ImportFailure(f'输出目录已存在且不是本工具生成：{output}，请选择空目录') from None
        if previous.get('owner') != OWNER:
            raise ImportFailure('生成目录的所有权标记不匹配')
        tracked = previous.get('files', {})
        for path in output.rglob('*'):
            if path.is_symlink():
                raise ImportFailure(f'生成目录含链接，已停止：{path}')
            if not path.is_file() or path == marker:
                continue
            rel = path.relative_to(output).as_posix()
            # Preserve Godot script identities across spreadsheet regeneration.
            if rel.endswith('.gd.uid') and rel[:-4] in tracked:
                if rel[:-4] in files:
                    preserved_uids[rel] = path.read_bytes()
                if rel not in tracked:
                    continue
            if rel not in tracked or sha(path.read_bytes()) != tracked[rel]:
                raise ImportFailure(f'生成目录含手工新增或修改文件，已停止：{path}。请先移走该文件')
    output_parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.memoir_stage_', dir=output_parent))
    backup = None
    try:
        for rel, contents in files.items():
            target = stage / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(contents)
        for rel, contents in preserved_uids.items():
            (stage / rel).write_bytes(contents)
        marker = {'owner': OWNER, 'schema_version': 2, 'files': {p: sha(b) for p,b in sorted(files.items())}}
        (stage / MARKER).write_text(json.dumps(marker,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        if output.exists():
            backup = Path(tempfile.mkdtemp(prefix='.memoir_backup_', dir=output_parent))
            backup.rmdir()
            os.replace(output, backup)
        try:
            os.replace(stage, output)
        except OSError:
            if backup is not None:
                os.replace(backup, output)
                backup = None
            raise
        if backup is not None:
            shutil.rmtree(backup)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    return output


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('workbook', nargs='?', default=HERE / 'game_catalog.xlsx', type=Path, help='默认使用工具目录中的game_catalog.xlsx')
    parser.add_argument('--project', type=Path, help='Godot项目根目录，内含project.godot')
    parser.add_argument('--output-rel', default='generated/game_catalog', help='项目内专用生成目录')
    parser.add_argument('--validate-only', action='store_true', help='仅校验，不写文件')
    parser.add_argument('--check', action='store_true', help='检查已生成资源与表格一致，不写文件')
    parser.add_argument('--skip-asset-check', action='store_true', help='显式跳过图片存在性检查')
    args = parser.parse_args(argv)
    try:
        schema = json.loads((HERE / 'schema.json').read_text(encoding='utf-8'))
        if schema['version'] != 2:
            raise ImportFailure('不支持此schema版本')
        output_rel = args.output_rel
        if not output_rel or '\\' in output_rel or any(c in output_rel for c in ('"','\n','\r','\t')) or any(p in ('','..','.') for p in output_rel.split('/')) or PurePosixPath(output_rel).is_absolute():
            raise ImportFailure('--output-rel必须是项目内的相对目录且不能含上级目录')
        project = args.project.resolve() if args.project else None
        if args.check and args.validate_only:
            raise ImportFailure('--check与--validate-only不能同时使用')
        if project and not (project / 'project.godot').is_file():
            raise ImportFailure('--project应指向包含project.godot的目录')
        if not project and not args.validate_only:
            raise ImportFailure('导出时需要--project；也可使用--validate-only只检查表格')
        raw = read_xlsx(args.workbook, schema)
        data, warnings = validate(raw, schema, project, args.skip_asset_check)
        for warning in warnings:
            print('提示：' + warning)
        print(f'校验通过：{len(data["游戏资料"])}款游戏，13个游戏资源字段')
        if not project or args.skip_asset_check:
            print('提示：未检查图片文件是否存在')
        if not args.validate_only:
            files = render_files(data, output_rel)
            if args.check:
                check_output(project, output_rel, files)
                print('已生成资源与表格、模板一致')
            else:
                target = write_output(project, output_rel, files)
                print(f'已生成：{target}（{len(files)}个文件）')
        return 0
    except (ImportFailure, OSError, ValueError, KeyError, zipfile.BadZipFile, ET.ParseError) as exc:
        print(f'导入失败：{exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
