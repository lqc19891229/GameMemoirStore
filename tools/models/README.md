# 模型制作与导出

本目录包含硬件模型源文件、Blender 导出脚本和房间 GLB 生成工具。**游戏运行只加载仓库中已提交的 GLB、Godot 原生场景与材质，不会运行建模脚本。**

## 硬件模型

`hardware.blend` 是硬件的可编辑 Blender 源文件；`build_hardware.py` 为硬件和早期电竞椅导出模型：

```bash
blender --background --threads 1 --factory-startup --python tools/models/build_hardware.py
```

电脑机箱、显示器、键盘、鼠标及桌面 GLB 输出到 `assets/models/hardware/`；电竞椅输出到 `assets/models/room/chair.glb`。重新运行生成器前应保存人工调整的模型与源文件，避免覆盖。

## 房间家具与装饰

`build_room.py` 用于离线生成初期房间 GLB，后续家具与装饰继续遵守相同坐标与包围盒约定：

```bash
python tools/models/build_room.py
```

房间资产不限于早期椅子、书架、灯具、地毯和绿植；当前 `assets/models/room/` 已包含更多家具、置物和装饰模型。对应场景在 `scenes/room/`，通过 `data/items/_catalog.tres` 关联商城商品。

**并非所有装饰都依赖 GLB**：例如 `scenes/room/wall_sconce.tscn` 使用 Godot 内建网格和真正的 `OmniLight3D`。壁灯挂到内墙或外墙后，可逐件控制电源、三级亮度和三档色温；不要将它视为按照游戏/工作/休息功能区自动配置的灯光。

## 质量与碰撞

- 坐标统一为米、Y 向上，家具底部中心为原点。
- 模型几何应落在对应 `room_furniture.bounds` 内，光照、材质和碰撞范围需要对应真实形状。
- 设备模型更换需要同时检查 `data/hardware/_catalog.tres` 的 `bounds` 和显示器校准。
- `docs/MODEL_QUALITY_STANDARD.md`：统一模型质量要求。
- `docs/FURNITURE_GLB_ASSETS.md`：房间 GLB 模型资源说明。
- `docs/ROOM_SIX_IMPROVEMENTS.md`：房间自由装修原则。

`*.glb.import` 与 GLB 一同提交；`.gdignore` 防止 Godot 把工具源文件当作游戏资源导入。
