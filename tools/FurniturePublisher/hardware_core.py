"""Safely replace an existing GameMemoirStore hardware appearance with a finished GLB.

Hardware is not a furniture SKU. Existing equipment IDs are retained so saves,
equipment slots and computer screen interaction continue to work.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable
import json
import math
import re
import shutil
import sys
import uuid

from publisher_core import PublishError, inspect_glb, _execute

# (device role, existing inventory ID) -> (GLB basename, resource basename, model node).
HARDWARE = {
    ("monitor", "starter_monitor"): ("monitor_crt", "DefaultModel"),
    ("monitor", "lcd_monitor"): ("monitor_lcd", "UpgradeModel"),
    ("computer", "starter_pc"): ("case_beige", "DefaultModel"),
    ("computer", "workstation"): ("case_charcoal", "UpgradeModel"),
    ("keyboard", "starter_mouse"): ("keyboard_beige", "DefaultModel"),
    ("keyboard", "precise_mouse"): ("keyboard_charcoal", "UpgradeModel"),
    ("mouse", "starter_mouse"): ("mouse_beige", "DefaultModel"),
    ("mouse", "precise_mouse"): ("mouse_charcoal", "UpgradeModel"),
}
LABELS = {
    "monitor": "显示器", "computer": "机箱",
    "keyboard": "键盘", "mouse": "鼠标",
}
Log = Callable[[str], None]


@dataclass
class HardwareItem:
    project: str
    godot: str
    source: str
    role: str
    item_id: str
    width: float
    height: float
    depth: float
    screen_width: float = 0
    screen_height: float = 0
    screen_x: float = 0
    screen_y: float = 0
    screen_z: float = 0

    @property
    def root(self) -> Path:
        return Path(self.project).expanduser().resolve()

    @property
    def source_path(self) -> Path:
        return Path(self.source).expanduser().resolve()

    @property
    def mapping(self) -> tuple[str, str]:
        try:
            return HARDWARE[(self.role, self.item_id)]
        except KeyError as exc:
            raise PublishError("未找到该设备角色与库存 ID 的已有型号；暂不允许自动新增商品") from exc

    @property
    def model_relative(self) -> Path:
        return Path("assets/models/hardware") / (self.mapping[0] + ".glb")

    @property
    def resource_relative(self) -> Path:
        return Path("data/hardware") / (self.mapping[0] + ".tres")

    @property
    def scene_relative(self) -> Path:
        return Path("scenes/computer/hardware") / (self.role + ".tscn")

    @property
    def bounds(self) -> list[float]:
        return [self.width, self.height, self.depth]

    @property
    def screen_size(self) -> list[float]:
        return [self.screen_width, self.screen_height]

    @property
    def screen_position(self) -> list[float]:
        return [self.screen_x, self.screen_y, self.screen_z]


def _finite(value: float, low: float, high: float) -> bool:
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value) and low <= value <= high


def validate_hardware(item: HardwareItem) -> dict:
    if not (item.root / "project.godot").is_file():
        raise PublishError("请选择 GameMemoirStore 项目根目录")
    basename, node = item.mapping
    for path in (item.resource_relative, item.scene_relative, "data/hardware/_catalog.tres",
                 "scripts/life/device_model.gd", "tools/FurniturePublisher/hardware_bridge.gd"):
        if not (item.root / path).is_file():
            raise PublishError(f"缺少硬件发布必需文件：{path}")
    executable = Path(item.godot).expanduser()
    if not executable.is_file() and shutil.which(item.godot) is None:
        raise PublishError("找不到 Godot 4.6 可执行文件")
    for value in item.bounds:
        if not _finite(value, 0.015, 3.0):
            raise PublishError("设备宽高深必须为 0.015～3 米的有限数值")
    if item.role == "monitor":
        if not _finite(item.screen_width, 0.01, item.width) or not _finite(item.screen_height, 0.01, item.height):
            raise PublishError("显示器屏幕宽高必须大于零且不超出设备尺寸")
        if not all(_finite(v, -3, 3) for v in item.screen_position):
            raise PublishError("显示器屏幕中心坐标不合法")
        if abs(item.screen_x) + item.screen_width / 2 > item.width / 2 + 0.001:
            raise PublishError("显示器屏幕横向超出外壳")
        if item.screen_y - item.screen_height / 2 < -0.001 or item.screen_y + item.screen_height / 2 > item.height + 0.001:
            raise PublishError("显示器屏幕纵向超出外壳")
        if abs(item.screen_z) > item.depth / 2 + 0.001:
            raise PublishError("显示器屏幕深度中心超出外壳")
    elif any(abs(v) > 0.000001 for v in item.screen_size + item.screen_position):
        raise PublishError("只有显示器可以填写屏幕参数")
    config = (item.root / item.resource_relative).read_text(encoding="utf-8-sig")
    model_ref = f'res://assets/models/hardware/{basename}.glb'
    if f'path="{model_ref}"' not in config:
        raise PublishError("现有硬件资源与目标模型不匹配")
    scene = (item.root / item.scene_relative).read_text(encoding="utf-8-sig")
    try:
        _find_scene_node(scene, node, parent="Models", require_instance=True)
    except PublishError as exc:
        raise PublishError(f"硬件场景结构不兼容：{exc}") from exc
    if f'path="{model_ref}"' not in scene:
        raise PublishError("硬件场景缺少对应型号的 Model 实例")
    return inspect_glb(item.source_path)


def _find_scene_node(scene: str, name: str, *, parent: str | None = None,
                     require_instance: bool = False) -> tuple[int, int, int]:
    """Find a Godot text scene node regardless of attribute order/unique_id.

    Godot 4.7 can add unique_id, re-order attributes or use CRLF when saving
    scene files; neither should break publishing an already-registered model.
    """
    headers = list(re.finditer(r'(?m)^\[node\s+([^\r\n]*)\]\r?$', scene))
    found = []
    for i, header in enumerate(headers):
        attrs = header.group(1)
        if re.search(r'(?<!\w)name="' + re.escape(name) + r'"(?=\s|$)', attrs) is None:
            continue
        if parent is not None and re.search(r'(?<!\w)parent="' + re.escape(parent) + r'"(?=\s|$)', attrs) is None:
            continue
        if require_instance and not re.search(r'(?<!\w)instance=ExtResource\("[^"]+"\)', attrs):
            continue
        end = headers[i + 1].start() if i + 1 < len(headers) else len(scene)
        found.append((header.start(), header.end(), end))
    if len(found) != 1:
        raise PublishError(f"需要唯一的 {name} 节点，实际匹配 {len(found)} 个")
    return found[0]


def _unity_scale_scene(scene: str, node: str) -> str:
    """Reset one existing hardware model instance to real-world scale.

    Only the scale field in its own node section is touched; other transform,
    UID, visibility and upgrade model declarations remain unchanged.
    """
    _, header_end, end = _find_scene_node(scene, node, parent="Models", require_instance=True)
    newline = "\r\n" if "\r\n" in scene else "\n"
    block = scene[header_end:end]
    scale = re.compile(r'(?m)^scale[ \t]*=[ \t]*Vector3\([^\r\n]*\)[ \t]*\r?$')
    hits = list(scale.finditer(block))
    if len(hits) > 1:
        raise PublishError(f"{node} 存在多个 scale 字段，无法安全替换")
    if hits:
        block = scale.sub(lambda match: "scale = Vector3(1, 1, 1)" + ("\r" if match.group(0).endswith("\r") else ""), block, count=1)
    else:
        block = newline + "scale = Vector3(1, 1, 1)" + block
    return scene[:header_end] + block + scene[end:]


def _activate_published_device(scene: str, role: str) -> str:
    """Unhide the device root after the replacement GLB passes Godot validation."""
    name = {"monitor": "Monitor", "computer": "Computer",
            "keyboard": "Keyboard", "mouse": "Mouse"}.get(role)
    if name is None:
        raise PublishError("未知硬件槽位")
    _, header_end, end = _find_scene_node(scene, name)
    header_start = scene.rfind("[node ", 0, header_end)
    header = scene[header_start:header_end]
    if not re.search(r'(?<!\w)type="Node3D"(?=\s|\])', header):
        raise PublishError(f"{name} 场景根节点不是 Node3D")
    newline = "\r\n" if "\r\n" in scene else "\n"
    block = scene[header_end:end]
    visibility = re.compile(r'(?m)^visible[ \t]*=[ \t]*(?:true|false)[ \t]*\r?$')
    hits = list(visibility.finditer(block))
    if len(hits) > 1:
        raise PublishError(f"{name} 存在多个 visible 属性，无法安全修改")
    if hits:
        block = visibility.sub(lambda match: "visible = true" + ("\r" if match.group(0).endswith("\r") else ""), block, count=1)
    else:
        block = newline + "visible = true" + block
    return scene[:header_end] + block + scene[end:]


def preview_hardware(item: HardwareItem) -> str:
    glb = validate_hardware(item)
    extra = f"\n屏幕大小：{item.screen_width} × {item.screen_height} m；中心：{item.screen_position}" if item.role == "monitor" else ""
    return (f"设备：{LABELS[item.role]} / {item.item_id}（替换已有外观）\n"
            f"目标模型：{item.root / item.model_relative}\n"
            f"目标配置：{item.root / item.resource_relative}\n"
            f"设备场景：{item.root / item.scene_relative}\n"
            f"新尺寸（X/Y/Z）：{item.bounds} m{extra}\n"
            f"网格：{glb['mesh_count']}  材质：{glb['material_count']}  内嵌图像：{glb['image_count']}\n"
            f"原始 SHA256：{glb['sha256']}\n"
            "将备份旧 GLB、设备配置和场景；导入成功后覆盖现有型号，不变更商品 ID/玩家存档。")


def publish_hardware(item: HardwareItem, log: Log = print) -> dict:
    glb = validate_hardware(item)
    root = item.root
    paths = [item.model_relative, item.resource_relative, item.scene_relative]
    originals = {relative: (root / relative).read_bytes() for relative in paths}
    if (root / item.model_relative).resolve() == item.source_path:
        raise PublishError("不能直接选择项目内的同名目标 GLB，请从外部成品文件导入")
    backup = (Path.home() / ".gamememoir_furniture_publisher" / "backups" /
              ("hardware_" + datetime.now().strftime("%Y%m%d-%H%M%S-%f") +
               "_" + item.mapping[0]))
    backup.mkdir(parents=True, exist_ok=False)
    for relative, contents in originals.items():
        dest = backup / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(contents)
    log("已备份旧模型、配置和场景至：" + str(backup))
    scene_relative = item.scene_relative
    script = root / "tools" / f"_hardware_publish_{uuid.uuid4().hex[:16]}.gd"
    manifest = script.with_suffix(".json")
    godot = str(Path(item.godot).expanduser()) if Path(item.godot).expanduser().is_file() else item.godot
    success = False
    try:
        scene = originals[scene_relative].decode("utf-8-sig")
        (root / scene_relative).write_text(_unity_scale_scene(scene, item.mapping[1]), encoding="utf-8")
        shutil.copyfile(item.source_path, root / item.model_relative)
        if inspect_glb(root / item.model_relative)["sha256"] != glb["sha256"]:
            raise PublishError("模型复制后的 SHA256 校验失败")
        template_root = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
        script.write_text((template_root / "hardware_bridge.gd").read_text(encoding="utf-8"), encoding="utf-8")
        manifest.write_text(json.dumps({
            "resource_path": "res://" + item.resource_relative.as_posix(),
            "model_path": "res://" + item.model_relative.as_posix(),
            "bounds": item.bounds, "screen_size": item.screen_size,
            "screen_position": item.screen_position, "role": item.role,
        }), encoding="utf-8")
        log("步骤 1/2：重新导入 GLB")
        _execute([godot, "--headless", "--path", str(root), "--editor", "--import"], root, log, 240)
        log("步骤 2/2：更新设备资源并由 Godot 验证")
        output = _execute([godot, "--headless", "--path", str(root), "--script",
                           "res://tools/" + script.name, "--", "res://tools/" + manifest.name], root, log, 180)
        receipts = [line.split("HARDWARE_PUBLISH_RESULT=", 1)[1]
                    for line in output.splitlines() if "HARDWARE_PUBLISH_RESULT=" in line]
        if not receipts:
            raise PublishError("Godot 未返回设备注册校验结果")
        try:
            receipt = json.loads(receipts[-1])
        except ValueError as exc:
            raise PublishError("设备校验结果格式错误") from exc
        if not receipt.get("ok") or receipt.get("model") != "res://" + item.model_relative.as_posix():
            raise PublishError("设备资源校验失败：" + str(receipt.get("error", "结果不匹配")))
        scene_file = root / item.scene_relative
        scene_file.write_text(_activate_published_device(scene_file.read_text(encoding="utf-8-sig"), item.role), encoding="utf-8")
        success = True
        log("新设备模型已启用；请在 Godot 里检查屏幕画面、碰撞与设备位置。")
        return {"model": str(root / item.model_relative),
                "resource": str(root / item.resource_relative),
                "scene": str(root / item.scene_relative), "backup": str(backup)}
    finally:
        for p in (script, manifest, script.with_suffix(".gd.uid")):
            p.unlink(missing_ok=True)
        if not success:
            for relative, contents in originals.items():
                (root / relative).write_bytes(contents)
            log("发布失败：已恢复旧 GLB、配置和场景文件；Godot 导入缓存可能需要再次导入。")
