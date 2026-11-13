"""Batch-import starter hardware GLBs from a colocated model_specs.json.

One preflight, one backup snapshot, one Godot GLB import, four validated hardware
resource updates. Any failure restores ALL changed source GLBs, TRES and TSCN.
"""
from __future__ import annotations

from datetime import datetime
from pathlib import Path
import json
import math
import shutil
import sys
import uuid

from publisher_core import PublishError, inspect_glb, _execute
from hardware_core import HardwareItem, validate_hardware, _unity_scale_scene

STARTER_IDS = {
    "monitor": "starter_monitor", "computer": "starter_pc",
    "keyboard": "starter_mouse", "mouse": "starter_mouse",
}
ROLES = ("monitor", "computer", "keyboard", "mouse")
BACKUP_FOLDER = Path.home() / ".gamememoir_furniture_publisher" / "backups"


def load_batch_specs(project: str, godot: str, specs_file: str) -> list[HardwareItem]:
    path = Path(specs_file).expanduser().resolve()
    if path.name != "model_specs.json" or not path.is_file():
        raise PublishError("请选择与四个 GLB 同目录的 model_specs.json")
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except (ValueError, UnicodeError) as exc:
        raise PublishError("model_specs.json 无法解析") from exc
    if not isinstance(data, dict) or data.get("schema_version") != 2:
        raise PublishError("规格文件版本错误，需要启航 2000 的 schema_version=2 文件")
    models = data.get("models")
    if not isinstance(models, list) or len(models) != 4:
        raise PublishError("批量导入要求显示器、机箱、键盘、鼠标各一个模型")
    found = {}
    for entry in models:
        if not isinstance(entry, dict):
            raise PublishError("模型条目应为对象")
        role = entry.get("role")
        item_id = entry.get("item_id")
        if role not in STARTER_IDS or item_id != STARTER_IDS[role] or role in found:
            raise PublishError("设备类型或现有库存 ID 不匹配，或者存在重复设备槽位")
        filename = entry.get("file", "")
        if (not isinstance(filename, str) or not filename.endswith(".glb")
                or Path(filename).name != filename or "/" in filename or "\\" in filename):
            raise PublishError("规格文件只允许同目录 GLB 文件名")
        dimensions = entry.get("expected_size_m")
        if (not isinstance(dimensions, list) or len(dimensions) != 3
                or any(not isinstance(v, (int, float)) or isinstance(v, bool)
                       or not math.isfinite(v) or v <= 0 for v in dimensions)):
            raise PublishError("模型 expected_size_m 必须包含有效的宽高深")
        actual = entry.get("actual_mesh_bounds_m")
        if not isinstance(actual, list) or len(actual) != 2 or any(
                not isinstance(v, list) or len(v) != 3 for v in actual):
            raise PublishError("必须提供网格实际包围盒 actual_mesh_bounds_m")
        try:
            extents = [float(actual[1][i]) - float(actual[0][i]) for i in range(3)]
            if any(not math.isfinite(v) or v <= 0 for v in extents):
                raise ValueError
        except (ValueError, TypeError, OverflowError) as exc:
            raise PublishError("网格实际包围盒必须是有限的有效尺寸") from exc
        if any(abs(extents[i] - float(dimensions[i])) > max(.025, float(dimensions[i]) * .12) for i in range(3)):
            raise PublishError("规格尺寸与网格包围盒差距过大：" + filename)
        screen_size = entry.get("screen_size_m", [0, 0])
        screen_position = entry.get("screen_position_m", [0, 0, 0])
        if role == "monitor" and ("screen_size_m" not in entry or "screen_position_m" not in entry):
            raise PublishError("显示器缺少屏幕 Quad 的尺寸和中心参数")
        if (not isinstance(screen_size, list) or len(screen_size) != 2
                or not isinstance(screen_position, list) or len(screen_position) != 3):
            raise PublishError("屏幕尺寸或中心坐标格式错误")
        numbers = dimensions + screen_size + screen_position
        if any(not isinstance(v, (int, float)) or isinstance(v, bool) or not math.isfinite(v) for v in numbers):
            raise PublishError("尺寸或屏幕参数必须为有限数值")
        item = HardwareItem(
            project=project, godot=godot, source=str(path.parent / filename),
            role=role, item_id=item_id, width=float(dimensions[0]),
            height=float(dimensions[1]), depth=float(dimensions[2]),
            screen_width=float(screen_size[0]), screen_height=float(screen_size[1]),
            screen_x=float(screen_position[0]), screen_y=float(screen_position[1]),
            screen_z=float(screen_position[2]),
        )
        validate_hardware(item)
        found[role] = item
    if set(found) != set(ROLES):
        raise PublishError("必须包含全部四个设备槽位")
    return [found[role] for role in ROLES]


def preview_batch(project: str, godot: str, specs_file: str) -> str:
    items = load_batch_specs(project, godot, specs_file)
    lines = ["启航 2000 基础款 · 批量替换预检（4/4）",
             "规格文件：" + str(Path(specs_file).expanduser().resolve())]
    for item in items:
        glb = inspect_glb(item.source_path)
        lines.append(f"{item.role}: {item.source_path.name} → {item.model_relative} / {item.item_id}"
                     f"\n  尺寸 {item.bounds} m，mesh {glb['mesh_count']}，SHA256 {glb['sha256'][:16]}…")
    lines.append("只更新原有基础款外观和尺寸；备份全部 4 GLB、4 TRES、4 TSCN；失败全部回滚。")
    return "\n".join(lines)


def publish_batch(project: str, godot: str, specs_file: str, log=print) -> dict:
    items = load_batch_specs(project, godot, specs_file)
    root = items[0].root
    pathset = set()
    for item in items:
        pathset.update((item.model_relative, item.resource_relative, item.scene_relative))
        if item.source_path == (root / item.model_relative).resolve():
            raise PublishError("请从外部模型文件夹导入，不能直接覆盖自身")
    originals = {relative: (root / relative).read_bytes() for relative in pathset}
    backup = BACKUP_FOLDER / ("hardware_batch_" + datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
    backup.mkdir(parents=True, exist_ok=False)
    for relative, data in originals.items():
        output = backup / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(data)
    log("整批备份：" + str(backup))
    token = uuid.uuid4().hex[:16]
    script = root / "tools" / f"_hardware_publish_{token}.gd"
    manifest = root / "tools" / f"_hardware_publish_{token}.json"
    executable = str(Path(godot).expanduser()) if Path(godot).expanduser().is_file() else godot
    bundle_root = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    success = False
    try:
        for item in items:
            scene = originals[item.scene_relative].decode("utf-8-sig")
            (root / item.scene_relative).write_text(
                _unity_scale_scene(scene, item.mapping[1]), encoding="utf-8")
            shutil.copyfile(item.source_path, root / item.model_relative)
            if inspect_glb(root / item.model_relative)["sha256"] != inspect_glb(item.source_path)["sha256"]:
                raise PublishError("GLB 拷贝校验失败：" + item.source_path.name)
        script.write_text((bundle_root / "hardware_bridge.gd").read_text(encoding="utf-8"), encoding="utf-8")
        log("阶段 1/2：一次性导入全部四个 GLB")
        _execute([executable, "--headless", "--path", str(root), "--editor", "--import"], root, log, 300)
        log("阶段 2/2：更新四个现有设备配置并逐一回读验证")
        for item in items:
            manifest.write_text(json.dumps({
                "resource_path": "res://" + item.resource_relative.as_posix(),
                "model_path": "res://" + item.model_relative.as_posix(),
                "bounds": item.bounds, "screen_size": item.screen_size,
                "screen_position": item.screen_position, "role": item.role,
            }), encoding="utf-8")
            output = _execute([executable, "--headless", "--path", str(root), "--script",
                               "res://tools/" + script.name, "--", "res://tools/" + manifest.name],
                              root, log, 180)
            receipts = [line.split("HARDWARE_PUBLISH_RESULT=", 1)[1]
                        for line in output.splitlines() if "HARDWARE_PUBLISH_RESULT=" in line]
            if not receipts:
                raise PublishError("Godot 未返回成功回执：" + item.role)
            try:
                result = json.loads(receipts[-1])
            except ValueError as exc:
                raise PublishError("设备回执解析失败：" + item.role) from exc
            if not result.get("ok") or result.get("model") != "res://" + item.model_relative.as_posix():
                raise PublishError("设备注册失败：" + item.role + " " + str(result.get("error", "")))
            log("已验证 " + item.role)
        success = True
        return {"count": len(items), "backup": str(backup), "models": [str(root / i.model_relative) for i in items]}
    finally:
        for path in (script, manifest, script.with_suffix(".gd.uid")):
            path.unlink(missing_ok=True)
        if not success:
            for relative, data in originals.items():
                (root / relative).write_bytes(data)
            log("整批导入失败：四套原 GLB / TRES / TSCN 全部恢复。请重新运行 Godot 资源导入刷新缓存。")
