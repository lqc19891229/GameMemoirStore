生活系统、房间与工作台回归索引

## 核心玩法与设备
test_life_flow.gd：共享钱包、应用窗口、直播/攻略、设备安装及旧数据迁移。
test_workstation_view.gd / test_workstation_layout.gd / test_workstation_collision.gd：3D 视角、设备拾取、布置手柄、连续碰撞、撤销、取消和存档。
test_workstation_lighting.gd：电脑硬件 RGB、OmniLight3D 与风扇效果。
test_item_system.gd / test_shop_room_flow.gd：库存 UID、购物、房间摆放和玩家存档。

## 自由房间结构与装修
test_room_blueprint.gd：房间尺寸、门窗与外壳修改。
test_room_partitions.gd：内墙和门洞，阻挡及旧存档清洗。
test_room_footprint.gd / test_room_grid_outline.gd：L 型／自由轮廓、移除地板、连通性与支撑。
test_room_finishes.gd：逐格地板材质、内外墙颜色及自定义门窗。
test_room_zones.gd：**沿用历史文件名，已改测自由装修**。验证不再出现游戏／工作／休息功能区或区域灯光、旧功能区地板色迁移、界面入口移除、撤销和 JSON 读档。
test_room_regions.gd：**实体空间**连通性（墙体阻断、门洞连通），不再把实体房间映射成用途分区；验证旧分区装修方案不再保存。
test_blueprint_ux.gd：建造网格、快捷工具、门窗拖动与操作反馈。
test_room_build_feedback.gd / test_room_smart_build.gd：画墙、外墙开口和安全阻挡。

## 家具、陈列和灯光
test_room_placement.gd / test_room_minimal_ui.gd：家具摆放预览和房间编辑器。
test_room_surface_mounts.gd / test_room_wall_mounts.gd：桌面、书架、内外墙挂载。
test_room_wall_sconce.gd：壁灯商品、物理挂载、独立开关、三级亮度、三档色温、撤销和存档。
test_furniture_catalog.gd / test_furniture_expansion.gd / test_furniture_showcase.gd：商品分类、家具场景、缩略图与购物。
test_furniture_direct_interaction.gd / test_furniture_assists.gd / test_furniture_batch.gd：直接拖拽、吸附、对齐、复制及批量操作。
test_room_visual_polish.gd / test_room_art_direction.gd / test_room_p44_ambience.gd：材质、天气、房间环境表现（不等于按用途切换的灯光预设）。

运行指定回归：

    godot --headless --path . --editor --import
    godot --headless --path . --script res://tests/life/test_room_zones.gd -- --fresh

完整列表和执行顺序见 .github/workflows/project-validation.yml、.github/workflows/room-ui-smoke.yml。涉及鼠标点击的 GUI 检查在 Xvfb 下执行。
测试采用独立临时存档和 --fresh，不应改写玩家正常进度。*.gd.uid 是 Godot 稳定资源标识。
