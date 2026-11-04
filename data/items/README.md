# 统一物品目录与房间库存

`item_id` 表示商店商品种类；`uid` 标识玩家拥有的每一件实物；`role` 标识场景中对应的可交互实例。重复购买同款家具也拥有独立 UID，不能把商品类型当作摆放实例。

## 商品与摆放

- `_catalog.tres`：商品与家具定义、分类、价格、场景、表面类型。
- `placement_surface = desk`：显示器、主机和键鼠等电脑设备只能摆放在对应桌面。
- `placement_surface = floor`：可购买家具从地面放置流程进入房间；可陈列的家具随后可移动到桌面、书架或指定墙面（如画框和壁灯）。
- 物体选择、碰撞、吸附、移动、旋转、复制、收纳、撤销和存档由 `scripts/life/workstation_layout.gd` 处理；承载表面由 `scripts/room/furniture_mount_data.gd` 及相应数据辅助脚本管理。
- 内外墙挂画与 `room_wall_sconce` 壁灯受墙面尺寸、门窗和其他挂载物约束。壁灯独立保存开关、三级亮度和三档色温，不使用房间用途或场景灯光预设。
- `life.inventory` 保存实物 UID；旧 `life.items` 和 `equipped.peripheral` 仍按兼容逻辑处理。旧硬件型号目录 `data/hardware/_catalog.tres` 继续管理设备 3D 外观。

## 商城预览与外观

家具卡片使用共享 3D 缩略图缓存，支持分类筛选和试色。购买前的预览配色不直接更改玩家房间内的家具。具体颜色处理见 `scripts/items/furniture_finishes.gd` 和 `tests/life/test_furniture_showcase.gd`。

房间不设置“工作区／游戏区／休息区”；所有家具位置和颜色由玩家自由决定。

## 开发检查

增加商品需要确保：稳定的 `item_id`、合法的 `subcategory`/摆放角色、场景或模型、包围尺寸、价格和库存关联。核心回归见 `tests/life/test_item_system.gd`、`tests/life/test_furniture_catalog.gd`、`tests/life/test_room_wall_sconce.gd`。
