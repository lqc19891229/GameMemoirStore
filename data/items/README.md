# 统一物品目录（第一阶段）
商品、库存和物理摆放不再共用一个 role。 `item_id` 是商品类型，`uid` 是拥有的单件物品，`role` 是旧编辑器中的摆放节点名称。

- `_catalog.tres` 包含现有商品及首批现代家具、独立键鼠；新增物品时编辑资源目录。
- `placement_surface = desk` 的主机、显示器、外设只能在电脑桌面上；桌面局部坐标与碰撞由 `workstation_layout.gd` 负责。
- `placement_surface = floor` 的家具只能放在地面；`pc_case` 的内部组件预留给后续 DIY 装机。
- 旧 `life.items` 与 `equipped.peripheral` 保留以兼容历史存档；新购买与重复家具用 `life.inventory` 的单件 UID 表示。
- 旧 `data/hardware/_catalog.tres` 仍负责 3D 设备外观切换，`visual_id` 用于关联，避免重复复制 GLB 资源。
