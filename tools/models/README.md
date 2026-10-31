# 模型制作与导出

本目录保存电脑硬件模型源文件、Blender 导出脚本和房间模型生成脚本。游戏运行只加载 assets/models/ 中已提交的 GLB，不会执行制作脚本。

## 电脑硬件与电脑桌展示资产

hardware.blend 是可编辑的 Blender 模型库。每个型号位于独立 Collection。制作脚本 build_hardware.py 使用 Blender 3.6 LTS，固定随机种子，可重复生成 9 个电脑硬件 GLB 和 1 个电竞椅 GLB：

    blender --background --threads 1 --factory-startup --python tools/models/build_hardware.py

输出：
- assets/models/hardware/：case_beige、case_charcoal、monitor_crt、monitor_lcd、keyboard_beige、keyboard_charcoal、mouse_beige、mouse_charcoal、desk。
- assets/models/room/chair.glb：电竞椅，作为房间可布置家具。

脚本会覆盖上述 GLB 和 hardware.blend。修改源模型后再执行；手工调整过的源文件或导出模型应先备份。

模型按材质合并网格。键帽、散热口、按钮和结构细节为真实几何；木纹使用打包在 GLB 内的 64 像素材质。高阶机箱、键盘和鼠标包含独立 Emissive 材质。机箱风扇的环与轮毂保留在 GLB 中，旋转叶片由 Godot 的 workstation_lighting.gd 独立生成和驱动，避免把动画部件合并进静态网格。电竞椅的坐垫、靠背、头枕、腰靠、扶手、气压杆、五星脚和滚轮分别建模。

## 像素房间模型

build_room.py 是独立的离线房间模型生成器，使用 Python 3 和 Pillow：

    python tools/models/build_room.py

脚本输出 assets/models/room/ 下的 5 个 GLB：room_shell、bookcase、lamp、rug、plant。电竞椅由 build_hardware.py 生成，避免两套脚本互相覆盖椅子模型。

房间使用 Godot 原生 Y 向上坐标，家具底部中心为原点。对应场景位于 scenes/room/。修改模型后应同步检查 room_furniture.bounds；修改房间或桌面几何后应检查 LayoutEditor 的尺寸与占地参数。

## 统一制作规范

- docs/MODEL_QUALITY_STANDARD.md：全项目模型精细化规范。
- docs/DESKTOP_SHOWCASE_V1.md：第一批电脑桌区域资产、尺寸和验收范围。

## 导入设置与保留规则

Godot 通过每个 GLB 旁边的 .import 文件保存导入设置。这些文件应与 GLB 一起提交，不要加入 .gitignore。工具源目录中的 .gdignore 防止 Godot 自动导入 .blend 和 Excel 等开发文件。

模型生成脚本只用于离线制作；正常运行只依赖已提交的 GLB 和场景。
