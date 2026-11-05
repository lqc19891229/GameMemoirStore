电脑工作台与屏幕应用场景

computer_desktop.tscn：游戏实际电脑桌面宿主，管理 3D 模式和 HUD。
workstation_3d.tscn：房间、相机、灯光、TableGroup、Equipment 和布局控制器的共享 3D 场景。
hardware/：显示器、机箱、键盘和鼠标的设备槽位与 GLB 模型。
ui/desktop_screen.tscn：显示器里的操作系统纹理与应用入口。
ui/layout_gizmo.tscn：布置模式操作手柄。
ui/app_window.tscn：购物、游戏平台和游玩共用的窗口壳。

初始家具位于 Workstation3D 的 Room/Furniture；其独立家具场景位于 scenes/room/ 分类目录。
房间摆放、碰撞、撤销和保存由 scripts/life/workstation_layout.gd 管理。
设备仅在专用桌面上安装或摆放；玩家家具材质以 GLB 默认外观为准，保留整件换色而非按部件材质配置。
显示器内系统由独立 DesktopViewport 渲染，3D 房间由主视口显示。
