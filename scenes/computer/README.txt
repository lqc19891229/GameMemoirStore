电脑工作台

computer_desktop.tscn：Node3D 根场景，直接编辑并运行 3D 工作台。
workstation_3d.tscn：相机、灯光、桌子和设备位置的复用源场景。
hardware/：显示器、机箱、键盘、鼠标；Models 下保存默认与升级 GLB 实例。
ui/desktop_screen.tscn：显示器中的系统、快捷方式、任务栏和通知。
ui/app_window.tscn：电脑内各应用共用的窗口壳。

HUD 使用 CanvasLayer；DesktopViewport 仅生成显示器实时纹理。
总览直接拖动旋转、滚轮缩放，单击设备检视，单击屏幕操作；Esc 返回并保留视角。
商城、购物网页和游玩界面位于 scenes/apps/，跨应用按钮位于 scenes/shared/。
