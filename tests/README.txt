自动化检查目录

Python：
- test_catalog_importer.py：Excel 读取、字段校验、素材解析、资源生成、清单一致性和文件保护。

Godot Headless：
- test_catalog_resources.gd：当前游戏资源字段、图片加载和时间线。
- test_catalog_integration.gd：资源接入商品页、展示图切换和交易流程。
- test_client.gd：游戏平台导航、搜索、购买、游戏库和存档。
- test_store.gd：交易规则、时间线和存档流程。
- test_editor_scenes.gd：场景预加载、编辑器节点、静态布局和设备位置保留。
- life/test_life_flow.gd：桌面到购买、安装、游玩、直播、攻略和存档恢复。
- life/test_workstation_view.gd：原生 3D 视角、设备拾取、屏幕输入和窗口操作。
- life/test_workstation_layout.gd：布置手柄、吸附、碰撞、应用、取消和存档恢复。
- life/test_workstation_collision.gd：模型边界、快速拖动防穿透、旋转碰撞和旧布局恢复。
- life/test_pixel_room.gd：房间模型、家具复制、外观、墙体遮挡和存档往返。
- life/test_audit_regressions.gd：独立预览、屏幕投影、显示器背面输入和异常存档。

图形环境：
- test_client_windows.gd：原生窗口、右键菜单和窗口交互，需要桌面显示环境；Linux CI 使用 Xvfb。

fixtures/：固定测试样本，不加入正式商店。*.gd.uid 是 Godot 脚本稳定标识。

运行 Python 测试：
    python -m unittest discover -s tests -p "test_catalog_importer.py" -v

Godot 测试通常使用 --fresh，避免读取或写入正常玩家存档。完整命令见根目录 README.md；GitHub Actions 会运行 Headless 回归和 Xvfb 图形测试。