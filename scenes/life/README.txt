3D 工作台与应用

computer_desktop.tscn：Control 外壳，组合 3D 视口、HUD 和实时桌面视口。
workstation_3d.tscn：真正的 3D 场景，包含灯光、相机、桌面、展示台和四件设备。空间布局在这里编辑。
hardware/：显示器、机箱、键盘、鼠标的独立 3D 场景；Models 下已保存默认 / 升级 GLB 实例。
desktop_screen.tscn：显示器内的系统、快捷方式、任务栏和通知。
app_window.tscn：应用窗口壳；browser.tscn：购物与库存；game_player.tscn：游玩与直播。

总览中点击设备检视，拖动旋转、滚轮缩放；点击屏幕操作电脑，Esc 返回。所有应用共用 GameSession。
