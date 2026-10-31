# 编辑像素 3D 房间、电脑设备与应用界面

固定场景和模型保存在资源文件中。运行时负责切换模型、绑定数据和处理交互，不在运行时生成房间或家具几何。

## 编辑入口

| 要编辑的内容 | 打开的文件或位置 |
|---|---|
| 房间外壳、家具实例、桌面和设备 | scenes/computer/computer_desktop.tscn，展开 Workstation3D |
| 房间外观与家具 | Workstation3D/Room；初始家具位于 Room/Furniture |
| 房间外壳 GLB | assets/models/room/room_shell.glb |
| 家具 GLB | assets/models/room/chair.glb、bookcase.glb、lamp.glb、rug.glb、plant.glb |
| 家具独立场景与拾取范围 | scenes/room/*.tscn |
| 房间模型生成源 | tools/models/build_room.py |
| 设备位置、旋转、相机和灯光 | scenes/computer/computer_desktop.tscn 的 Workstation3D |
| 单件设备及默认 / 升级模型 | scenes/computer/hardware/*.tscn |
| 硬件模型源文件 | tools/models/hardware.blend |
| 设备 ID、bounds、屏幕尺寸与位置 | data/hardware/*.tres |
| 布置控制面板和操作手柄 | ComputerDesktop/HUD/Interface/LayoutPanel、scenes/computer/ui/layout_gizmo.tscn |
| 显示器中的系统、快捷方式和任务栏 | scenes/computer/ui/desktop_screen.tscn |
| 应用标题栏与窗口操作 | scenes/computer/ui/app_window.tscn |
| 平台页面和组件 | scenes/apps/platform/store.tscn、pages/、components/、dialogs/ |
| 购物网页和游玩界面 | scenes/apps/browser/browser.tscn、scenes/apps/game/game_player.tscn |

## 3D 房间与工作台编辑

打开 scenes/computer/computer_desktop.tscn，展开 Workstation3D。workstation_3d.tscn 是可复用的房间、工作台、相机、灯光和默认布局源场景；computer_desktop.tscn 是实际运行入口。

Room/Shell 保存房间墙体、窗和地面；Room/Furniture 保存椅子、书架、灯、地毯和绿植。TableGroup 保存桌子与 Equipment。设备始终位于 Equipment 下，设备坐标相对桌面，移动或旋转桌子时会一起跟随。

KeyLight、FillLight 和 Environment 控制房间光照与背景；Camera 控制默认总览视角。Room 的外观预设由 scripts/room/pixel_room.gd 管理。改变房间几何时，应同步检查 LayoutEditor 的 room_half_size。

## 房间模型重建

房间模型由 tools/models/build_room.py 离线生成，使用 Python 3 和 Pillow：

    python tools/models/build_room.py

脚本会重建 assets/models/room/ 下的 room_shell、chair、bookcase、lamp、rug 和 plant 六个 GLB。它不依赖 Blender；游戏运行也不会执行此脚本。

模型底部中心为原点，Godot 坐标 Y 向上。改动家具几何后，应同步检查 scenes/room/*.tscn 中 room_furniture.bounds，确保碰撞范围覆盖全部可见网格。改动房间尺寸或桌面几何后，应同步检查 LayoutEditor 的 room_half_size、tabletop_half_size、tabletop_height 和 edge_margin。

## 玩家布置与碰撞

玩家点击顶栏“布置房间”进入编辑模式。选择家具或设备后，可拖动平面手柄或轴手柄移动；R 旋转，Q / E 每步旋转 15°。默认吸附为 5 cm / 15°，可在 LayoutEditor 检查器中调整。

实心物件之间通过凸占地检测阻挡。移动检查整个扫掠路径，旋转以不超过 1° 的步长检查中间位置，避免起点和终点都空闲但中途穿过障碍物。地毯允许压在家具下方；设备只能留在桌面范围内。碰撞规则是放置约束，不是刚体推挤模拟。

房间、桌面尺寸和边距由 LayoutEditor 导出属性控制。调整模型后要同步更新 bounds 和占地参数，并运行工作台布置、碰撞和房间专项测试。

草稿只有点击“应用布置”才会写入共享存档。取消 / Esc 会丢弃草稿；后台保存和屏幕操作不会覆盖未确认的编辑。

## 电脑设备模型

hardware.blend 使用 Blender 3.6.23 LTS 编辑。每种设备位于独立 Collection；运行时加载 assets/models/hardware/*.glb。重建命令：

    blender --background --threads 1 --factory-startup --python tools/models/build_hardware.py

该脚本会重建 9 个硬件 GLB 和 Blender 源文件。模型底部原点 Y=0，单位为米，正面 +Z。新增型号时同步修改 scenes/computer/hardware/、data/hardware/_catalog.tres 和 scripts/life/life_data.gd。

## 2D 系统与应用界面

显示器内系统在 1280 × 800 DesktopViewport 中运行。相机射线与 Screen 表面相交后映射到系统坐标；应用、菜单和弹窗都保留在显示器纹理中。切换总览、布置和屏幕操作不会销毁应用或中断会话。

页面预览使用场景中的示例数据，运行时由共享 GameSession 填入钱包、游戏和库存。列表按数据数量实例化已有模板，静态布局保存在场景中。不要随意重命名带 % 唯一标识的节点。

## 验证

    godot --headless --path . --script res://tests/test_editor_scenes.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_view.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_layout.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_collision.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_pixel_room.gd -- --fresh

场景按功能放在 main/、computer/、room/、apps/ 和 shared/；不要在旧目录中另建重复副本。