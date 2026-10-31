# 3D 设备目录与库存映射

_catalog.tres 将库存 ID 映射到 MemoirDeviceModel 资源，分别管理显示器、机箱、键盘和鼠标。精准键鼠套装同时映射键盘和鼠标，沿用原有套装价格和效率加成。

## 资源字段

- model：已导出的 GLB PackedScene。
- bounds：用于拾取、布置占地阻挡和选择框的包围尺寸，单位为米。模型底部原点 Y=0，X/Z 方向应以原点为中心覆盖全部可见网格，包括按钮、接口和玻璃等凸出部分。
- screen_size：显示器表面的宽和高，单位为米；非显示器设备留空。
- screen_position：显示器表面中心的局部位置。屏幕正面为 +Z，上方为 +Y。

碰撞检测会在模型 bounds 外增加 LayoutEditor 的 collision_margin。调整模型几何或尺寸时，应同步检查 bounds 和桌面可放置区域。

## 新增设备型号

1. 编辑 tools/models/hardware.blend，或准备符合项目坐标约定的 GLB；单位为米、Y 向上、+Z 为正面、底部为原点。
2. 将 GLB 导出到 assets/models/hardware/。
3. 在相应 scenes/computer/hardware/*.tscn 的 Models 节点下添加型号实例，并设置为初始隐藏。
4. 创建 MemoirDeviceModel 资源，填写 model 和 bounds；显示器还需校准 screen_size 与 screen_position。
5. 在 scripts/life/life_data.gd 的 ITEMS 增加库存商品，并在本目录的 _catalog.tres 对应设备映射中加入相同物品 ID。

显示器使用 monitor 槽位，机箱使用 computer 槽位，键盘和鼠标使用各自独立模型映射；库存中的 peripheral 套装可同时切换键盘和鼠标。

## 场景与保存

设备默认位置位于 scenes/computer/workstation_3d.tscn 的 TableGroup/Equipment 下。运行时切换型号只替换模型，不改变设备槽位；总览、布置和屏幕操作之间切换会保留位置。

设备位置、旋转、大小和相机可以在 scenes/computer/computer_desktop.tscn 的 Workstation3D 子树编辑。模型制作说明见 tools/models/README.md。游戏运行只加载 GLB，不需要 Blender。