# 电脑设备模型制作

hardware.blend 是可编辑的 Blender 模型库。每个型号位于独立 Collection，默认只显示 case_beige；切换 Collection 可编辑其他设备。模型以 Blender 原生几何和材质制作，不是贴图平面。屏幕内的系统界面由 Godot 接入。

制作脚本 build_hardware.py 已在 Blender 3.6.23 LTS 验证；固定随机种子，可重复重建整套模型。

```bash
blender --background --threads 1 --factory-startup --python tools/models/build_hardware.py
```

脚本覆盖本目录 hardware.blend 与 assets/models/hardware/*.glb。修改源模型后请自行导出，或先修改脚本再重建，避免覆盖手工改动。运行游戏不执行脚本，不需要 Blender。

九个模型为：case_beige、case_charcoal、monitor_crt、monitor_lcd、keyboard_beige、keyboard_charcoal、mouse_beige、mouse_charcoal、desk。

设备底部原点 Y=0，Godot 单位为米，正面 +Z。建模函数使用 Godot 坐标，再转换到 Blender；glTF 导出恢复为 Y 向上。模型按材质合并网格，键帽、散热口和按钮为真实几何；木纹使用打包的 64 像素材质。文件在 Godot 中作为现成场景加载，家具几何不在运行时生成。

Godot 布局入口：scenes/life/workstation_3d.tscn。库存映射与屏幕尺寸在 data/hardware/，参见该目录 README.md。

.gdignore 防止 Godot 自动导入 .blend 并要求本地 Blender；游戏只导入已提交的 GLB。
