# 家具 GLB 资源（P16）

本批 20 款新家具的正式独立模型存放在 `assets/models/room/catalog/`，每款家具都有一个对应的 `<role>.glb`。这些模型以 GLB 二进制形式保存，可直接通过 Blender 的“Import > glTF 2.0”载入、编辑网格与材质并重新导出。

Godot 场景 `scenes/room/<role>.tscn` 不再通过脚本生成模型。它们只保留 `role`（存档稳定标识）、`bounds`（模型尺寸）、`PickArea` / `Hit`（交互碰撞）和灯具的灯光组件。场景里的 `Model` 节点直接实例化对应的 `assets/models/room/catalog/<role>.glb`。

`data/items/_catalog.tres` 仍维护商品 ID、分类、价格及场景引用，购买与库存 UID 不变。旧七款家具仍使用 `scripts/room/room_furniture.gd` 的兼容程序化模型，新 20 款不再调用程序化建模。

## 如何使用 Blender 修改

1. 在 Blender 中选择 File > Import > glTF 2.0 (.glb)，打开目标文件。
2. 模型原点保持地面中心；模型单位按米计算，Y 轴向上。
3. 修改网格、UV 和 PBR 材质，导出为 glTF Binary (.glb)。
4. 如果改变模型宽高深，务必同步调整对应 `.tscn` 文件中的 `bounds` 与 `PickArea/Hit` 的碰撞盒尺寸。
5. 在 Godot 中执行重新导入，运行 `tests/life/test_furniture_expansion.gd` 和完整 CI。

每款 GLB 都是模型模板，多个实例可以共享同一 GLB。同款 GLB 可以实例化任意多个库存中已购买的家具；新实例使用 `家具角色__instance__item_N` 作为固定标识（N 为独立库存 UID），不再有九件固定上限。旧存档的 `chair`、`chair_1` 至 `chair_8` 等历史角色仍原样加载；每件家具仍拥有独立 UID、位姿、材质和撤销重做状态。实际可摆放数量仍受房间面积与碰撞规则约束。

电脑主机、显示器、键鼠等仍只能使用专用电脑桌面，不会因普通桌类商品导入 GLB 而获得新的设备摆放面。
