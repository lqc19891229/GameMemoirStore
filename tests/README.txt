项目自动化检查

- Python：游戏资料导入校验（tests/test_catalog_importer.py）、GLB 模型质量及依赖检查（tests/test_showcase_models.py）。
- Godot Headless：客户端、商店、状态、时间线、设备和房间的无界面回归（根目录 tests/*.gd 与 tests/life/*.gd）。
- 图形界面：需要真实窗口交互、3D 拾取和鼠标点击的 Godot 测试；CI 在 Linux 上使用 Xvfb。
- fixtures/：旧版固定游戏数据和资源样本，不加入正式商店。

核心房间回归位于 tests/life/：
- test_room_blueprint.gd、test_room_partitions.gd、test_room_grid_outline.gd、test_room_finishes.gd：尺寸、墙体、自由轮廓和逐格装修。
- test_room_zones.gd：**历史文件名**，现测试无功能分区的自由装修、旧区域地板色迁移、撤销/重做与 JSON 存档。
- test_room_regions.gd：真实墙体/门洞的空间连通性及无区域设计存档槽位。
- test_room_wall_mounts.gd、test_room_wall_sconce.gd：挂画、内外墙壁灯、独立开关、亮度和色温。
- test_room_minimal_ui.gd、test_blueprint_ux.gd：自由装修入口与建造 UI。
- test_furniture_showcase.gd、test_furniture_direct_interaction.gd、test_furniture_batch.gd：购物预览和家具操作。

常用命令（在仓库根目录）：

    python -m unittest discover -s tests -p "test_catalog_importer.py" -v
    python -m unittest discover -s tests -p "test_showcase_models.py" -v
    godot --headless --path . --editor --import
    godot --headless --path . --script res://tests/life/test_room_zones.gd -- --fresh

完整自动化列表：.github/workflows/project-validation.yml；房间快速检查：.github/workflows/room-ui-smoke.yml。

建议使用 --fresh 和测试自有的 user:// 临时存档，避免污染普通玩家数据。*.gd.uid 应与测试脚本一起保留。
