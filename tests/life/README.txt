# 生活系统、房间和家具回归测试

本目录主要覆盖 `scripts/life/`、`scripts/room/` 和家具资源工作流，测试脚本均以当前仓库实际文件名为准。

## 主要分组

- **游玩生活**：`test_life_flow.gd`、`test_item_system.gd`、`test_shop_room_flow.gd`。
- **3D 工作台**：`test_workstation_view.gd`、`test_workstation_layout.gd`、`test_workstation_collision.gd`、`test_workstation_lighting.gd`。
- **房间建造**：`test_room_blueprint.gd`、`test_room_partitions.gd`、`test_room_footprint.gd`、`test_room_grid_outline.gd`、`test_room_finishes.gd`、`test_room_zones.gd`、`test_room_regions.gd`。
- **家具交互**：`test_room_placement.gd`、`test_furniture_assists.gd`、`test_furniture_instances.gd`、`test_furniture_batch.gd`、`test_furniture_direct_interaction.gd`、`test_furniture_showcase.gd`。
- **家具工具**：`test_furniture_model_import.gd`、`test_furniture_catalog_registration.gd`、`test_furniture_resource_manager.gd`、`test_furniture_support_authoring.gd`。
- **家具模型**：`test_furniture_expansion.gd`、`test_furniture_pbr.gd`、`test_chair_gaming_uv.gd`。
- **其他表现和交互**：`test_room_visual_polish.gd`、`test_room_art_direction.gd`、`test_room_cinematic.gd`、`test_room_scene_actions_clicks.gd`。

`test_furniture_pbr.gd` 检查既有导入模型的 UV/贴图情况，并非已删除的 Furniture Material Library 的单部件材质编辑测试。

## 使用

```bash
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd -- --fresh
godot --headless --path . --script res://tests/life/test_furniture_model_import.gd -- --fresh
godot --headless --path . --script res://tests/life/test_workstation_layout.gd -- --fresh
```

需要真实图形窗口的用例不能仅凭 headless 检查。完整 CI 工作流位于 `../../.github/workflows/`，并可通过 `--fresh` 隔离正常存档。原家具材质槽测试已经移除，不应继续调用。
