电脑桌面与房间主场景

computer_desktop.tscn：Node3D 主场景，组合 3D 工作台、房间、HUD 与建造/装修入口。
workstation_3d.tscn：相机、灯光、Room、TableGroup、设备和 LayoutEditor 的复用源场景。
hardware/：机箱、显示器、键盘和鼠标等设备槽位与型号模型。
ui/desktop_screen.tscn：显示器内的系统界面、快捷方式、任务栏和通知。
ui/layout_gizmo.tscn：家具布置时的选择框、移动和旋转手柄。
ui/app_window.tscn：游戏平台、购物网页及游玩应用的窗口容器。

Workstation3D 包含 Room、TableGroup、Camera、LayoutEditor 等。Room/Shell 负责户型外壳，Room/Furniture 负责可购买家具和装饰。
房间建筑可以自由编辑尺寸、墙体、门窗和地板；编辑器不再提供游戏区、工作区、休息区、区域灯光或区域装修方案。房间内的灯具按单件开关、亮度、色温控制。
房间视觉表现：scripts/room/；操作、碰撞、历史记录和持久化：scripts/life/workstation_layout.gd。

HUD 属于 CanvasLayer；DesktopViewport 生成显示器内的系统纹理。总览可拖动旋转和滚轮缩放，点击屏幕进入电脑应用，Esc 返回并保留运行活动。
