# 工作台设备外观

`computer_desktop.tscn` 的四个设备实例决定摆放位置和大小。每件设备使用一个 `MemoirDeviceVisual` 资源：

- `texture`：完整素材，保留宽高比；可使用 AtlasTexture 的 region 选取原图的有效区域，不改写 PNG。
- `screen_rect`：显示器实际内框，Rect2 的位置与大小都是相对 texture 的 0～1 坐标；其他设备留空。

`_catalog.tres` 的 monitors、computers、keyboards、mice 分别将库存物品 ID 对应到外观资源。旧日键鼠和精准键鼠套装分别提供独立键盘、鼠标贴图；购买与加成继续沿用原套装。

新增型号：

1. 将 PNG 放入 assets/art/life/hardware/，创建 MemoirDeviceVisual 资源并指定贴图。显示器还需填写 Screen Rect。
2. 在 scripts/life/life_data.gd 的 ITEMS 增加商品，显示器使用 monitor 槽位，机箱使用 computer，键鼠套装使用 peripheral。
3. 在 _catalog.tres 对应字典中添加相同物品 ID。安装后外观自动更新，已有应用继续运行。

Monitor、Computer、Keyboard、Mouse 的实例锚点可在 2D 编辑器直接调整。默认场景有预览贴图，@tool 只同步素材和屏幕位置，不生成节点。屏幕始终保留完整渲染分辨率，放大和返回不切换会话。
