# 统一物品与家具商品目录

`_catalog.tres` 是当前商城物品定义来源。区分三个身份：

- **`item_id`**：某类商品的稳定标识。
- **库存 `uid`**：玩家实际拥有的单件物品标识，可重复购买同款家具。
- **摆放 `role`**：场景中的摆放角色/实例节点标识，不应当替代 UID。

`MemoirItemDefinition.furniture_scene` 关联可实例化的家具 `.tscn`，而不是直接引用商品贴图。家具模型归档在 `assets/models/room/` 分类目录，场景在 `scenes/room/` 对应目录。

## 家具导入与注册

在 Blender 完成 GLB 的默认外观（网格、UV、法线、PBR 贴图），导入项目后通过编辑器底部的 **家具导入 → 家具注册 → 家具资源** 流程审核。注册时检查商品 ID 唯一性、价格、分类、场景路径、角色及摆放许可。具体操作见 [家具管理器说明](../../addons/furniture_manager/README.md)。

## 摆放与库存

- `placement_surface=desk` 的电脑、显示器和外设只能放置在适合的工作台区域。
- `placement_surface=floor` 的家具按地面占地、碰撞和承载面许可检查。
- 家具支持购买多份，位置与独立库存 UID 保持关联。
- 历史的 `life.items` 与旧外设字段通过存档校验逻辑兼容。

## 外观与商城预览

商城家具缩略图使用真实场景的 3D 离屏渲染并进行缓存。原有 **整件换色** 功能与 `furniture_colors` 存档仍然保留。此前的共享家具材质库、单部件材质替换、UV 调节和 `furniture_materials` 运行时存档功能已经移除。

**默认材质应随 GLB 本身制作完成。** 只有完成模型材质、法线和尺寸检查的资产才应作为正式家具注册；现有部分旧 GLB 仍需要单独美术精修。

参见：[家具资源管理](../../addons/furniture_manager/README.md)、[模型制作](../../tools/models/README.md)、[房间布置](../../docs/WORKSTATION_LAYOUT.md)。
