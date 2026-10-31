生活系统检查

test_life_flow.gd：验证共享钱包、窗口寿命、直播与攻略收入、设备安装、历史家具数据及存档迁移。
运行：godot --headless --path . --script res://tests/life/test_life_flow.gd -- --fresh
测试使用独立临时存档，不修改正常玩家进度。
*.gd.uid：Godot 脚本稳定标识。

test_workstation_view.gd：通过实际输入事件检查设备展示与屏幕放大、Esc 和弹窗、设备安装与存档、屏幕点击映射、机箱区域不触发应用、任务栏和内嵌弹窗；覆盖两款显示器与 1280×800、960×600 两种尺寸。
