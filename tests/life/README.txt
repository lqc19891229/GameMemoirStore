生活系统检查

test_life_flow.gd：验证共享钱包、窗口寿命、直播与攻略收入、设备安装、历史家具数据及存档迁移。
运行：godot --headless --path . --script res://tests/life/test_life_flow.gd -- --fresh
测试使用独立临时存档，不修改正常玩家进度。
*.gd.uid：Godot 脚本稳定标识。

test_workstation_view.gd：通过实际输入事件检查原生 3D 主视口、总览旋转缩放与重置、点击 / 拖动区分、设备单击保持总览、真实 3D 射线拾取、屏幕镜头切换、设备安装、屏幕 UV 输入、任务栏与弹窗；覆盖两款显示器和四种窗口尺寸。

test_audit_regressions.gd：检查独立网页预览、变换后的屏幕投影、显示器背面输入、当前目录截图预览，以及异常存档数值。

test_workstation_layout.gd：布置模式的真实鼠标输入、手柄、吸附、桌沿、碰撞、应用/取消、设备跟随、存档恢复和编辑中退出。
