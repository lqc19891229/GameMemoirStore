# Godot 编辑器与资源维护指南

本项目使用 **Godot 4.6 / GL Compatibility**。固定模型与 UI 由 `.glb`、`.tscn` 和资源文件维护；运行时负责数据、玩家交互和可选整件换色，不为每件家具额外生成默认 PBR 材质。

## 常用入口

| 内容 | 打开位置 |
|---|---|
| 游戏主场景 | `scenes/main/game_root.tscn` |
| 工作台与房间 | `scenes/computer/computer_desktop.tscn`、`scenes/computer/workstation_3d.tscn` |
| 房间本体、地板和墙体 | `scenes/room/room.tscn`、`scenes/room/modern_room_shell.tscn` |
| 家具 GLB | `assets/models/room/{tables,seating,storage,lighting,decor}/` |
| 家具独立场景 | `scenes/room/{tables,seating,storage,lighting,decor}/` |
| 家具管理 | Godot 底部「家具资源」「家具导入」「家具注册」 |
| 硬件 GLB | `assets/models/hardware/` |
| 设备槽位 | `scenes/computer/hardware/` |
| 商品目录 | `data/items/_catalog.tres` |
| 3D 布置逻辑 | `scripts/life/workstation_layout.gd` |
| 游戏平台、浏览器、游玩 UI | `scenes/apps/platform/`、`scenes/apps/browser/`、`scenes/apps/game/` |

## 完整 GLB 家具制作与注册

1. 在建模工具中完成几何、分组、UV、法线、默认 PBR 贴图和材质；**直接打开导出的 GLB 应能看到最终默认外观**。
2. 以分类路径存放 GLB，保留相关纹理和 `.import` 设置。不要覆盖不相关的已注册家具资产。
3. 让 Godot 导入新模型，打开底部「家具导入」，扫描资源并生成对应分类下的独立家具 `.tscn`。
4. 检查模型尺寸、`bounds`、`PickArea/Hit`、地面原点、朝向和承载面。
5. 进入「家具注册」，人工审核后登记商品 ID、分类、价格和家具场景；在「家具资源」中再次检查。
6. 启动游戏验证商店缩略图、购买、实例摆放、存档与原始材质。

完整导入细节见 `addons/furniture_manager/README.md`。不要把 GLB 当作已经自动上架的商品，商品定义以 `data/items/_catalog.tres` 为准。

## 材质策略

- **默认外观**：在 GLB 中直接完成（Base Color、Metallic/Roughness、Normal 贴图等）。
- **保留功能**：原有整件家具换色 `furniture_colors`、设备 RGB 灯效、摆放预览的半透明覆盖。
- **已移除**：Furniture Material Library 插件、共享家具 `.tres` 材质库、按网格表面选材质/调整 UV、`MaterialProfile` 和 `furniture_materials` 运行时覆盖。
- `chair_gaming.glb` 的 UV/法线已经修复，但仍需将更丰富的纹理真正制作进 GLB 后才算精修完成。

`tools/models/bake_chair_gaming_materials.py` 仍依赖已经删除的材质库，当前不能直接使用。参阅 `tools/models/README.md`。

## 房间与设备

`Workstation3D` 包含 Room、TableGroup、设备实例、相机及布置逻辑。桌面设备跟随桌子变换；家具按地面/支撑面许可和碰撞规则摆放。房间编辑支持墙体、开口、功能区、吸附、拖动、撤销与应用/取消，详情见 `docs/WORKSTATION_LAYOUT.md`。

模型的尺寸、原点或节点结构变化后，应同步检查物品目录场景引用、`bounds`、选择碰撞及相应测试。不要在操作系统文件管理器里随意移动已注册资源，而不更新 `res://` 引用。

## 离线模型生成（历史资产）

```bash
blender --background --threads 1 --factory-startup --python tools/models/build_hardware.py
python tools/models/build_room.py
```

这些脚本只覆盖特定历史资产，不会维护分类目录下所有家具。直接重跑可能覆盖已有模型，请先备份并检查输出路径。

## 验证

```bash
godot --headless --path . --editor --import
python tools/project_audit.py
godot --headless --path . --script res://tests/test_editor_scenes.gd -- --fresh
godot --headless --path . --script res://tests/life/test_furniture_model_import.gd -- --fresh
godot --headless --path . --script res://tests/life/test_workstation_layout.gd -- --fresh
godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd -- --fresh
```

图形 UI 点击测试需要图形显示环境。全部自动化流程请查看 `.github/workflows/`。
