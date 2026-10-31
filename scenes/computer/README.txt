电脑与像素房间主场景

computer_desktop.tscn：Node3D 根场景，直接编辑和运行 3D 工作台、房间与 HUD。
workstation_3d.tscn：相机、灯光、Room、TableGroup、设备和 LayoutEditor 的复用源场景。
hardware/：显示器、机箱、键盘和鼠标设备槽位；Models 下保存默认和升级 GLB 实例。
ui/desktop_screen.tscn：显示器中的系统、快捷方式、任务栏和通知。
ui/layout_gizmo.tscn：布置模式的选择框、移动轴和旋转手柄。
ui/app_window.tscn：游戏平台、购物网页和游玩界面共用的窗口壳。

Workstation3D 包含 Room、TableGroup、KeyLight、Camera、LayoutEditor 和 PixelPass。Room/Furniture 保存五件初始家具；Room/Shell 保存房间外壳。房间外观和遮挡逻辑位于 scripts/room/，布置与碰撞逻辑位于 scripts/life/workstation_layout.gd。

HUD 位于 CanvasLayer；DesktopViewport 只负责生成显示器内 1280 × 800 的系统纹理。总览拖动旋转、滚轮缩放，点击显示器屏幕进入系统；Esc 返回并保留视角和活动。