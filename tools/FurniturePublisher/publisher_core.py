"""No-dependency GLB furniture publisher for GameMemoirStore.

The Python layer never writes Godot resource text. It invokes the project's
existing Godot importer and registrar through a short-lived GDScript bridge.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Callable
import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys
import uuid
from datetime import datetime

GROUPS = {"tables": "桌类", "seating": "座椅", "storage": "储物", "lighting": "灯具", "decor": "装饰"}
TYPES = {
    "computer_desk": "电脑桌", "side_table": "边桌", "coffee_table": "茶几", "writing_desk": "写字桌",
    "lounge_chair": "休闲椅", "bench": "长凳", "office_chair": "电脑椅", "sofa": "沙发",
    "stool": "矮凳", "cushion": "坐垫", "bookcase": "书架", "shelf": "置物架",
    "cabinet": "展示柜", "floor_lamp": "落地灯", "desk_lamp": "台灯",
    "ambient_light": "氛围灯", "rug": "地毯", "plant": "绿植", "poster": "海报",
    "ornament": "摆件", "misc": "其他",
}
GROUP_TYPES = {
    "tables": ("computer_desk", "side_table", "coffee_table", "writing_desk", "misc"),
    "seating": ("office_chair", "lounge_chair", "bench", "sofa", "stool", "cushion", "misc"),
    "storage": ("bookcase", "shelf", "cabinet", "misc"),
    "lighting": ("floor_lamp", "desk_lamp", "ambient_light", "misc"),
    "decor": ("rug", "plant", "poster", "ornament", "misc"),
}
ROLE = re.compile(r"^[a-z][a-z0-9_]*$")
Log = Callable[[str], None]


class PublishError(Exception):
    pass


@dataclass
class Item:
    project: str
    godot: str
    source: str
    item_id: str
    name: str
    group: str
    type: str
    price: int
    description: str = ""
    allow_surface_mount: bool = False
    support_surfaces: str = "[]"

    @property
    def project_root(self) -> Path:
        return Path(self.project).expanduser().resolve()

    @property
    def source_path(self) -> Path:
        return Path(self.source).expanduser().resolve()

    @property
    def model_relative(self) -> Path:
        return Path("assets/models/room") / self.group / (self.item_id + ".glb")

    @property
    def scene_relative(self) -> Path:
        return Path("scenes/room") / self.group / (self.item_id + ".tscn")

    @property
    def model_res(self) -> str:
        return "res://" + self.model_relative.as_posix()

    @property
    def scene_res(self) -> str:
        return "res://" + self.scene_relative.as_posix()

    def surfaces(self) -> list[dict]:
        try:
            raw = json.loads(self.support_surfaces or "[]")
        except (ValueError, TypeError) as exc:
            raise PublishError("承载面必须是合法 JSON 数组") from exc
        if not isinstance(raw, list) or len(raw) > 32:
            raise PublishError("承载面必须是最多 32 条的 JSON 数组")
        ids: set[str] = set()
        result = []
        for x in raw:
            if not isinstance(x, dict) or not ROLE.fullmatch(str(x.get("id", ""))):
                raise PublishError("承载面 ID 必须使用小写字母、数字和下划线")
            if x["id"] in ids:
                raise PublishError("承载面 ID 不能重复")
            ids.add(x["id"])
            for k in ("x", "y", "z", "width", "depth"):
                if not isinstance(x.get(k), (int, float)) or isinstance(x[k], bool):
                    raise PublishError(f"承载面 {x['id']} 的 {k} 必须为数值")
                if not -1000 < x[k] < 1000:
                    raise PublishError("承载面坐标超过安全范围")
            if x["width"] <= 0 or x["depth"] <= 0:
                raise PublishError("承载面宽深必须大于零")
            result.append({k: x[k] for k in ("id", "x", "y", "z", "width", "depth")})
        return result


def inspect_glb(path: Path) -> dict:
    if not path.is_file() or path.suffix.lower() != ".glb":
        raise PublishError("请选择存在的 .glb 成品模型")
    data = path.read_bytes()
    if len(data) < 28 or data[:4] != b"glTF":
        raise PublishError("不是有效 GLB 文件")
    version, declared = struct.unpack_from("<II", data, 4)
    if version != 2 or declared != len(data):
        raise PublishError("GLB 不是 glTF 2.0 或文件长度不正确")
    json_len, kind = struct.unpack_from("<I4s", data, 12)
    if kind != b"JSON" or 20 + json_len > len(data):
        raise PublishError("GLB 缺少正确的 JSON chunk")
    try:
        meta = json.loads(data[20:20 + json_len].decode("utf-8"))
    except (ValueError, UnicodeError) as exc:
        raise PublishError("GLB 内部 JSON 读取失败") from exc
    if not meta.get("meshes") or not meta.get("nodes"):
        raise PublishError("GLB 不包含可用的 mesh / node")
    for record in meta.get("buffers", []) + meta.get("images", []):
        uri = record.get("uri", "")
        if uri and not uri.startswith("data:"):
            raise PublishError("GLB 包含外部依赖 URI，请先在 Blender 中打包贴图")
    for mesh in meta["meshes"]:
        for primitive in mesh.get("primitives", []):
            if "POSITION" not in primitive.get("attributes", {}):
                raise PublishError("GLB 存在缺少顶点 POSITION 的网格")
    return {
        "mesh_count": len(meta["meshes"]), "material_count": len(meta.get("materials", [])),
        "image_count": len(meta.get("images", [])), "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def validate(item: Item) -> tuple[dict, list[dict]]:
    root = item.project_root
    if not (root / "project.godot").is_file():
        raise PublishError("项目目录缺少 project.godot")
    for path in ["addons/furniture_manager/furniture_importer.gd", "addons/furniture_manager/furniture_catalog_registrar.gd", "data/items/_catalog.tres"]:
        if not (root / path).is_file():
            raise PublishError(f"项目版本缺少必需文件：{path}")
    if not ROLE.fullmatch(item.item_id) or "__instance__" in item.item_id:
        raise PublishError("商品 ID 必须为小写字母开头，只含小写字母、数字、下划线，不能包含 __instance__")
    if not item.name.strip():
        raise PublishError("请输入商品中文名称")
    if item.group not in GROUPS or item.type not in GROUP_TYPES[item.group]:
        raise PublishError("家具类别或二级类型无效")
    if not isinstance(item.price, int) or not 0 < item.price <= 10_000_000:
        raise PublishError("上架商品价格必须为 1～10000000 点")
    if (root / item.model_relative).exists() or (root / item.scene_relative).exists():
        raise PublishError("已有同名 GLB 或家具场景，程序只允许新增，不覆盖已有资产")
    # Existing catalog is authoritative. Preliminary check; Godot registrar
    # performs final duplicate-ID/role validation immediately before writing.
    catalog = (root / "data/items/_catalog.tres").read_text(encoding="utf-8-sig")
    if re.search(r'^item_id\s*=\s*"' + re.escape(item.item_id) + r'"\s*$', catalog, re.M):
        raise PublishError("该商品 ID 已在目录中注册")
    if re.search(r'^subcategory\s*=\s*"' + re.escape(item.item_id) + r'"\s*$', catalog, re.M):
        raise PublishError("该摆放角色已在目录中注册")
    glb = inspect_glb(item.source_path)
    surfaces = item.surfaces()
    executable = Path(item.godot).expanduser()
    if not executable.is_file() and shutil.which(item.godot) is None:
        raise PublishError("找不到 Godot 可执行文件；请选择 Godot 4.6 程序")
    return glb, surfaces


def preview(item: Item) -> str:
    glb, anchors = validate(item)
    return (
        f"商品：{item.name} / {item.item_id}\n"
        f"分类：{GROUPS[item.group]} / {TYPES[item.type]}\n售价：{item.price} 点\n"
        f"GLB：{item.source_path} ({glb['bytes']:,} bytes)\n"
        f"网格：{glb['mesh_count']}  材质：{glb['material_count']}  内嵌图像：{glb['image_count']}\n"
        f"复制到：{item.project_root / item.model_relative}\n"
        f"生成：{item.project_root / item.scene_relative}\n"
        f"注册：{item.project_root / 'data/items/_catalog.tres'}\n"
        f"承载面：{len(anchors)} 个；可被承载：{'是' if item.allow_surface_mount else '否'}\n"
        f"原始 GLB SHA256：{glb['sha256']}\n\n"
        "将运行 Godot 导入与场景/注册校验。注册失败可能保留新建模型/场景供排查，但不会覆盖已存在资产。"
    )


def _execute(cmd: list[str], cwd: Path, log: Log, timeout: int) -> str:
    log("执行：" + " ".join(cmd))
    try:
        result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        raise PublishError(f"Godot 执行超时（{timeout} 秒）") from exc
    for line in (result.stdout + "\n" + result.stderr).splitlines():
        if line.strip():
            log(line)
    if result.returncode != 0:
        raise PublishError(f"Godot 步骤失败（退出码 {result.returncode}），请查看日志")
    return result.stdout


def publish(item: Item, log: Log = print) -> dict:
    glb, anchors = validate(item)
    root = item.project_root
    model_path = root / item.model_relative
    scene_path = root / item.scene_relative
    catalog = root / "data/items/_catalog.tres"
    # Store a recovery snapshot OUTSIDE the project, not as a second catalog.
    backup_dir = Path.home() / ".gamememoir_furniture_publisher" / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup_file = backup_dir / f"catalog_{stamp}_{item.item_id}.tres"
    shutil.copy2(catalog, backup_file)
    log(f"目录备份：{backup_file}")
    model_path.parent.mkdir(parents=True, exist_ok=True)
    scene_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(item.source_path, model_path)
    if inspect_glb(model_path)["sha256"] != glb["sha256"]:
        raise PublishError("GLB 拷贝校验失败")
    token = uuid.uuid4().hex[:16]
    bridge_path = root / "tools" / f"_furniture_publish_{token}.gd"
    manifest_path = root / "tools" / f"_furniture_publish_{token}.json"
    manifest = {
        "model_path": item.model_res, "scene_path": item.scene_res,
        "fields": {"item_id": item.item_id, "name": item.name.strip(), "role": item.item_id,
                   "group": item.group, "type": item.type, "price": item.price,
                   "description": item.description.strip(), "allow_surface_mount": item.allow_surface_mount},
        "support_surfaces": anchors,
    }
    bundle_root = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    bridge_path.write_text((bundle_root / "bridge.gd").read_text(encoding="utf-8"), encoding="utf-8")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
    godot = str(Path(item.godot).expanduser()) if Path(item.godot).expanduser().is_file() else item.godot
    try:
        log("阶段 1/3：Godot 导入 GLB")
        _execute([godot, "--headless", "--path", str(root), "--editor", "--import"], root, log, 240)
        log("阶段 2/3：生成家具场景并注册商品")
        output = _execute([godot, "--headless", "--path", str(root), "--script", "res://tools/" + bridge_path.name,
                  "--", "res://tools/" + manifest_path.name], root, log, 180)
        markers = [line.split("FURNITURE_PUBLISH_RESULT=", 1)[-1] for line in output.splitlines()
                   if "FURNITURE_PUBLISH_RESULT=" in line]
        if not markers:
            raise PublishError("Godot 脚本没有返回明确的登记结果，不能认定发布成功")
        try:
            registered = json.loads(markers[-1])
        except ValueError as exc:
            raise PublishError("Godot 登记返回了无法解析的结果") from exc
        if not registered.get("ok") or registered.get("item_id") != item.item_id:
            raise PublishError("Godot 家具注册失败：" + str(registered.get("error", "结果不匹配")))
        log("阶段 3/3：核实商品和场景文件")
        if not scene_path.is_file():
            raise PublishError("Godot 未生成场景")
        catalog_text = catalog.read_text(encoding="utf-8-sig")
        if not re.search(r'^item_id\s*=\s*"' + re.escape(item.item_id) + r'"\s*$', catalog_text, re.M):
            raise PublishError("目录未找到新商品，请检查 Godot 注册日志")
        log("成功：家具已生成、注册并在游戏中可售（购买操作需通过游戏人工检查）")
        return {"item_id": item.item_id, "model": str(model_path), "scene": str(scene_path),
                "catalog": str(catalog), "backup": str(backup_file)}
    finally:
        for path in [bridge_path, manifest_path, bridge_path.with_suffix(".gd.uid")]:
            try:
                path.unlink(missing_ok=True)
            except OSError:
                log(f"临时文件未清理：{path}")
