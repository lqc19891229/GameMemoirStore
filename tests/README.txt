测试入口与验证规范

Python：
- test_catalog_importer.py：游戏 Excel 导入、清单、资源和防覆盖规则。
- test_showcase_models.py：设备/房间 GLB 内容和生成结构。
- 其他测试请以 tests/ 下实际文件为准。

Godot Headless（tests/ 与 tests/life/）：
- test_catalog_resources.gd、test_catalog_integration.gd、test_client.gd、test_store.gd：游戏数据、商城与状态。
- test_editor_scenes.gd：主场景、应用与编辑器节点。
- life/test_workstation_view.gd、life/test_workstation_layout.gd、life/test_workstation_collision.gd：工作台、输入、摆放、碰撞和存档。
- life/test_furniture_model_import.gd、life/test_furniture_catalog_registration.gd、life/test_furniture_resource_manager.gd：家具导入、注册、资源管理。
- life/test_furniture_expansion.gd、life/test_chair_gaming_uv.gd：模型边界、家具资源及游戏椅 UV。
- life/test_room_blueprint.gd、life/test_room_partitions.gd、life/test_room_footprint.gd 等：房间建造。
- life/test_workstation_lighting.gd：设备灯效（与已移除的家具材质库无关）。

图形测试：test_client_windows.gd 和 life/ 下的鼠标/界面点击测试需要图形环境；CI 使用 Xvfb。

运行示例（仓库根目录）：
    godot --headless --path . --editor --import
    python -m unittest discover -s tests -p "test_catalog_importer.py" -v
    godot --headless --path . --script res://tests/life/test_workstation_layout.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd -- --fresh

--fresh 用于隔离正常玩家存档。完整执行列表见 .github/workflows/project-validation.yml 和 room-ui-smoke.yml。

此前专用的家具材质槽测试已随材质系统移除，不要继续按旧文档调用。
fixtures/：测试用目录及样本，不作为正式商品。*.gd.uid：脚本稳定资源标识。
