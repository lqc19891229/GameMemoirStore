# 模型制作与导出

本目录保存电脑硬件模型源文件、导出脚本和房间模型生成脚本。游戏运行只加载 assets/models/ 中已经提交的 GLB，不会执行制作脚本，也不需要在玩家电脑上安装 Blender 或 Python。

## 电脑硬件模型

hardware.blend 是可编辑的 Blender 模型库。每个型号位于独立 Collection，模型由 Blender 原生几何和材质制作，不是贴图平面；显示器内的操作系统由 Godot 实时纹理提供。

制作脚本 build_hardware.py 已在 Blender 3.6.23 LTS 验证。固定随机种子，可重复重建 9 个硬件 GLB：

    blender --background --threads 1 --factory-startup --python tools/models/build_hardware.py

脚本会覆盖 hardware.blend 和 assets/models/hardware/*.glb。修改源模型后再执行；手工调整过的源文件或导出模型应先备份。

9 个模型：case_beige、case_charcoal、monitor_crt、monitor_lcd、keyboard_beige、keyboard_charcoal、mouse_beige、mouse_charcoal、desk。

设备底部原点 Y=0，Godot 单位为米，正面 +Z。模型按材质合并网格；键帽、散热口和按钮为真实几何；木纹使用打包在 GLB 内的 64 像素材质。设备库存映射、bounds 和屏幕尺寸位于 data/hardware/。

Godot 编辑入口为 scenes/computer/computer_desktop.tscn，展开 Workstation3D；复用源场景为 workstation_3d.tscn。新增型号时还需同步检查 scenes/computer/hardware/、data/hardware/ 和 scripts/life/life_data.gd。

## 像素房间模型

build_room.py 是独立的离线房间模型生成器，使用 Python 3 和 Pillow。运行：

    python tools/models/build_room.py

脚本输出 assets/models/room/ 下的 6 个完整 GLB：room_shell、chair、bookcase、lamp、rug、plant。纹理嵌入 GLB，并使用最近邻采样器；不依赖 Blender。需要安装 Pillow 才能重建房间模型。

房间使用 Godot 原生 Y 向上坐标，家具底部中心为原点。对应场景位于 scenes/room/，拾取范围和默认位置由各场景与 scripts/life/workstation_layout.gd 管理。修改模型后应同步检查 room_furniture.bounds；修改房间或桌面几何后应同步检查 LayoutEditor 的 room_half_size、tabletop_half_size 和 tabletop_height。

## 导入设置与保留规则

Godot 通过各 GLB 旁边的 .import 文件保存导入设置。这些文件应与 GLB 一起提交，不要加入 .gitignore。工具源目录中的 .gdignore 防止 Godot 自动导入 .blend 和 Excel 等开发文件。

模型生成脚本只用于离线制作；正常运行只依赖已提交的 GLB 和场景。详细编辑入口见根目录 EDITOR_WORKFLOW.md。