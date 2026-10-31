# 3D 设备与库存映射

`_catalog.tres` 的 monitors、computers、keyboards、mice 将库存 ID 对应到 MemoirDeviceModel 资源。精准键鼠套装同时映射键盘和鼠标，购买及加成沿用原套装。

资源字段：

- model：已导出的 GLB PackedScene。
- bounds：用于拾取和检视取景的包围尺寸，单位为米，模型底部原点 Y=0。
- screen_size：显示器表面的宽和高，米；其他设备留空。
- screen_position：显示器表面中心的局部位置。表面正面为 +Z，上方为 +Y。

新增型号：

1. 编辑 tools/models/hardware.blend 或提供其他 GLB，保持单位米、Y 向上、+Z 正面、底部原点。导出到 assets/models/hardware/。
2. 在相应 scenes/computer/hardware/*.tscn 的 Models 下添加该 GLB 实例，初始隐藏。现有默认 / 升级型号已保存在场景中，可直接在编辑器查看。
3. 创建 MemoirDeviceModel 资源，指定 model 和 bounds；显示器需校准 screen_size 与 screen_position。
4. 在 life_data.gd 的 ITEMS 增加商品，在 _catalog.tres 对应字典加入相同物品 ID。显示器为 monitor、机箱为 computer、键鼠为 peripheral 槽位。

空间布局在 workstation_3d.tscn 的 Equipment 下编辑。刷新库存只切换模型；检视结束恢复编辑器保存的位置。GLB 独立于 Blender 源文件，运行游戏无需 Blender。
