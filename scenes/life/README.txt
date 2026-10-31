3D 工作台与应用

computer_desktop.tscn：Node3D 根场景，直接在这里编辑 3D 工作台；HUD 使用 CanvasLayer，DesktopViewport 仅渲染显示器系统纹理。
workstation_3d.tscn：真正的 3D 场景，包含灯光、相机、桌面、展示台和四件设备。作为 ComputerDesktop 中的可编辑实例复用。
hardware/：显示器、机箱、键盘、鼠标的独立 3D 场景；Models 下已保存默认 / 升级 GLB 实例。
desktop_screen.tscn：显示器内的系统、快捷方式、任务栏和通知。
app_window.tscn：应用窗口壳；browser.tscn：购物与库存；game_player.tscn：游玩与直播。

总览直接左键 / 右键拖动旋转、滚轮缩放；单击设备检视，单击屏幕操作电脑，Esc 返回并保留视角。“重置视角”恢复默认镜头。所有应用共用 GameSession。
