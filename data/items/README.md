# 统一物品目录（第一阶段）
商品、库存和物理摆放不再共用一个 role。 `item_id` 是商品类型，`uid` 是拥有的单件物品，`role` 是旧编辑器中的摆放节点名称。

- `_catalog.tres` 包含现有商品及首批现代家具、独立键鼠；新增物品时编辑资源目录。
- `placement_surface = desk` 的主机、显示器、外设只能在电脑桌面上；桌面局部坐标与碰撞由 `workstation_layout.gd` 负责。
- `placement_surface = floor` 的家具只能放在地面；`pc_case` 的内部组件预留给后续 DIY 装机。
- 旧 `life.items` 与 `equipped.peripheral` 保留以兼容历史存档；新购买与重复家具用 `life.inventory` 的单件 UID 表示。
- 旧 `data/hardware/_catalog.tres` 仍负责 3D 设备外观切换，`visual_id` 用于关联，避免重复复制 GLB 资源。

## 家具商城展示（P15）

- 商城商品卡新增真实家具 3D 缩略图、分类、二级类型与模型尺寸，通过单一 SubViewport 离屏渲染并缓存，避免 27 个常驻 3D 视口。
- 商城可切换 9 种配色试色，试色仅影响商品预览；购买后在房间编辑器对单个家具进行改色。
- 商店与房间编辑器共享 scripts/items/furniture_finishes.gd，保持原存档 0–5 色彩编号，增加深胡桃木、石墨黑和陶土橙色彩涂层。涂层不替换原有木材、金属或织物基底材质。
- tests/life/test_furniture_showcase.gd 验证展示、试色和存档兼容；实际缩略图画质需要图形界面复核。
- 电脑主机、显示器、键鼠仍必须放在专用电脑桌面上。
