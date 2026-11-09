# 游戏回忆录（GameMemoirStore）

基于 **Godot 4.6（GL Compatibility）** 的单机游戏收藏与生活模拟项目。玩家通过购买、安装、游玩和收藏游戏获得成长与收入，同时升级电脑设备、购买家具并设计个人游戏房间。

> 当前为持续开发中的游戏原型，部分功能和美术资源仍在完善。本文以仓库现有代码、场景和资源为准，不代表所有规划功能已经完成。

## 核心玩法

| 子系统 | 当前实现 | 后续重点 |
|---|---|---|
| 游戏生活 | 游戏商城、购买/安装、游戏库、游玩挑战、成就、直播、攻略与成长属性 | 充实游戏内容、成长反馈与长期目标 |
| 房间建造 | 户型、墙体门窗、区域装修、家具购买/复制/布置、碰撞、吸附、撤销及保存 | 更多高质量家具与场景体验 |
| 电脑设备 | 机箱、显示器、键盘、鼠标模型更换，工作台布置及电脑内应用 | 硬件兼容性、装机和性能模拟 |

游戏循环：**收藏游戏 → 游玩与挑战 → 获得成长和收入 → 升级电脑 → 布置游戏空间**。

## 启动项目

1. 安装 **Godot 4.6**，用编辑器打开仓库根目录的 `project.godot`。
2. 首次打开时等待 GLB、PNG 和其他资源导入完成。
3. 运行主场景 `scenes/main/game_root.tscn`（或按 F5）。
4. 若家具管理工具未显示，检查 **项目 → 项目设置 → 插件 → Furniture Manager**。编辑器底部应有「家具资源」「家具导入」「家具注册」。

渲染器由 `project.godot` 配置为 GL Compatibility。Python、Pillow 和 Blender 只在离线导入、制作或测试相关资源时需要；游戏运行不调用这些制作脚本。

## 目录导航

| 路径 | 作用 | 说明 |
|---|---|---|
| `scenes/` | 游戏主入口、工作台、房间与应用窗口 | [场景入口](scenes/README.txt) |
| `scripts/` | 共享状态、玩法、UI、房间交互 | [脚本职责](scripts/README.txt) |
| `data/` | 游戏、物品、设备定义与生成目录 | [数据目录](data/README.txt) |
| `assets/` | 模型、贴图、字体和界面资源 | [素材目录](assets/README.txt) |
| `addons/furniture_manager/` | 家具编辑器工具 | [导入与注册](addons/furniture_manager/README.md) |
| `tools/` | 离线资产制作、数据导入与资源审计 | [工具目录](tools/README.txt) |
| `tools/FurniturePublisher/` | 外部 Windows 家具发布器（Python/Tkinter） | [外部家具发布器](tools/FurniturePublisher/README.md) |
| `tests/` | Python、Godot 与图形界面回归测试 | [测试目录](tests/README.txt) |
| `docs/` | 美术、建造、架构及专题记录 | [专题索引](docs/README.md) |

架构总览：[CLIENT_STRUCTURE.md](CLIENT_STRUCTURE.md)；编辑操作：[EDITOR_WORKFLOW.md](EDITOR_WORKFLOW.md)。

## 真实尺寸规则

房间与家具统一使用 **1 Godot 单位 = 1 米**；当前默认房间是 **8 × 6 米**，墙体高度约 **3.2 米**。新版家具严格按外包围实测，首个候选为 **160 × 75 × 75 厘米电竞桌**。详见 [房间与家具真实尺度规范](docs/REAL_SCALE_FURNITURE.md)。旧家具逐件重制，不一次性修改正式商品或用户存档。

## 家具资源工作流（GLB 为成品）

1. 在 Blender 或其他 DCC 工具中完成模型、部件分组、UV、法线和默认 PBR 材质。
2. 导出 **自带默认材质和贴图的 GLB**，放进 `assets/models/room/{tables,seating,storage,lighting,decor}/` 对应分类。
3. 在编辑器「家具导入」生成 `scenes/room/<分类>/<名称>.tscn`，检查尺寸、原点、朝向和碰撞。
4. 在「家具注册」人工审核后注册到 `data/items/_catalog.tres`，再到「家具资源」核查。
5. 游戏运行时直接使用 GLB 的原始材质；**此前独立的 Furniture Material Library、按部件材质覆盖和 UV 编辑功能已移除**。原有整件家具换色和摆放预览效果仍保留。

目前 `chair_gaming.glb` 已完成正式 PBR GLB 接入和对应自动化验证；其他部分旧家具仍需按新标准逐步制作。新增家具也可使用 **外部家具发布器** 输入完成的 GLB 和商品信息，自动生成场景并注册商品（首次使用仍需检查 Godot 版本和视觉效果）。**完整的可重复操作和验收步骤**见 [家具制作标准工作流](docs/FURNITURE_PRODUCTION_WORKFLOW.md)，模型技术细节见 [模型制作指南](tools/models/README.md)。

## 数据与保存

- `data/games/` 为游戏目录生成资源，修改源数据后通过 `tools/catalog/import_games.py` 生成。
- `data/items/_catalog.tres` 是家具、商品和设备的统一物品目录；每件购买物品使用独立库存 UID。
- 玩家存档位于 Godot 的 `user://memoir_store_v01.json`，不是仓库中的资源文件。运行测试推荐使用 `--fresh`，避免使用正常存档。
- 历史存档里的 `furniture_materials` 字段不再使用；`furniture_colors`（整件换色）仍保留。

## 常用验证命令

```bash
godot --headless --path . --editor --import
python tools/project_audit.py
python tools/catalog/import_games.py --project . --check
python -m unittest discover -s tests -p "test_catalog_importer.py" -v
godot --headless --path . --script res://tests/life/test_furniture_model_import.gd -- --fresh
godot --headless --path . --script res://tests/life/test_workstation_layout.gd -- --fresh
godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd -- --fresh
```

完整 CI 步骤见 `.github/workflows/project-validation.yml` 和 `.github/workflows/room-ui-smoke.yml`；图形界面测试需要显示环境。**测试执行通过后才能视为验证完成，文档更新不代表 CI 已通过。**
