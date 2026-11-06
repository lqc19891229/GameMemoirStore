# 家具制作工作流（GLB → Godot → 商店 → 房间）

适用：GameMemoirStore / 游戏回忆录，Godot 4.6 Compatibility。

**唯一原则：GLB 是带有最终默认外观的成品；Godot 家具场景定义交互；商品目录负责销售；存档按稳定 ID/UID 管理拥有实例。**

> 本规范是新家具的标准流程。老家具可能仍在迁移途中。不要重新启用已移除的 Furniture Material Library、MaterialProfile 或运行时逐部件材质覆盖。

## 0. 给家具建立制作卡

开始制作前固定以下字段，并在 PR 中记录，避免重复名称和修改存档标识：

| 字段 | 示例 | 规则 |
|---|---|---|
| 资源名 / role | `chair_gaming` | 全小写下划线；唯一、长期稳定 |
| GLB | `assets/models/room/seating/chair_gaming.glb` | 成品默认材质已经嵌入 |
| 场景 | `scenes/room/seating/chair_gaming.tscn` | 一件家具对应独立可实例化场景 |
| 商品 ID | `chair_gaming` | 全局唯一；无需强制 `room_` 前缀 |
| 商店分类 | `seating / office_chair` | 五个一级分类之一；二级类型匹配现有 taxonomy |
| 售价 / 中文名 | `1500 / 电竞椅` | 价格大于 0 才出现在普通商店 |
| 放置位置 | `floor` | 普通落地家具；桌面小物先用落地库存，再按承载面规则摆放 |
| 是否可被承载 | `allow_surface_mount=false` | 只有适合摆在桌/书架上的小物品才勾选 |
| 是否提供承载面 | `custom_support_surfaces` | 由家具场景提供，例如书架层板、桌面 |

**区分两个容易混淆的属性**：`allow_surface_mount` 是“该商品能放到别人的承载面上”；`custom_support_surfaces` 是“该家具能够承载其他小物件”。椅子通常两者均不需要；书架通常需要后者；杯子通常需要前者。

### 分类文件结构

```text
assets/models/room/{tables,seating,storage,lighting,decor}/<role>.glb
scenes/room/{tables,seating,storage,lighting,decor}/<role>.tscn
data/items/_catalog.tres  # 唯一正式商品目录
```

| 一级分类 | 示例 |
|---|---|
| `tables` | 书桌、茶几、餐桌 |
| `seating` | 电竞椅、沙发、长凳 |
| `storage` | 书架、柜子、收纳架 |
| `lighting` | 落地灯、壁灯 |
| `decor` | 杯子、摆件、绿植 |

## 1. 在 Blender / 离线工具完成 GLB

1. 使用**米制**、Y 向上、正面 +Z，家具本体以地面中心为原点。导出前应用需要应用的缩放与旋转。
2. 检查正面、侧面、背面；避免悬空、穿模、反法线、UV 错误。为主要材质部件保持清晰稳定的网格名称。
3. 在**源模型阶段**完成 Base Color、Metallic/Roughness、Normal，需要时加入 AO / Emission；导出 **glTF Binary (.glb)**，确保默认外观不依赖游戏运行时材质脚本。
4. 使用 Blender 或独立 glTF 查看器重新打开导出的 GLB，确认贴图已携带、部件完整、尺寸正确；不要只看源工程。
5. 交付来源文件（如 .blend）、正式 GLB；重要源贴图应纳入美术源资源管理。若需离线烘焙，脚本应可重复、可验证，不可依赖已删除的运行时材质库。
6. 不为每件家具机械复用电竞椅烘焙脚本：`tools/models/bake_chair_gaming_materials.py` 是特例/参考实现，并非通用转换器。

参照 `docs/MODEL_QUALITY_STANDARD.md` 的三角面预算、材质和性能建议。新模型的标准以真实房间镜头为最终依据。

## 2. 导入 Godot，创建独立家具场景

1. 把已完成的 GLB 放入对应 `assets/models/room/<分类>/`，等待 Godot 4.6 导入成功。
2. Godot 编辑器底部打开 **家具导入**；若没有标签，在 **项目 → 项目设置 → 插件** 确认启用 Furniture Manager。
3. 选择/扫描模型目录，选中未创建独立场景的 GLB，点击 **为已选模型生成家具场景**。
4. 导入器会创建 `scenes/room/<分类>/<role>.tscn`，实例化 `Model`，根据几何估算 `bounds`，添加 `PickArea/Hit` 拾取盒，并把模型在家具本地空间中对齐到地面。
5. 打开新建场景，检查根节点脚本 `room_furniture.gd`、`role`、`bounds`、`Model` 和 `PickArea/Hit`。尤其检查 X/Z 占地、Y 高度以及旋转后的范围。
6. 导入器**不覆盖**已存在的场景，也**不注册商品**。若更新已上市家具，只替换对应 GLB，并手动核对旧场景：不要重建新 role 或商品 ID，以免旧存档丢失引用。

注意：`bounds` 是房间摆放阻挡边界；`PickArea/Hit` 用于鼠标拾取；它们并不等于精确物理碰撞网格。几何越界首先检查导出比例、原点和资源是否搞错，禁止仅通过无意义放大边界掩盖模型错误。

## 3. 需要承载功能时配置锚点（可跳过）

- 对书桌、茶几、书架、展柜：打开**独立家具场景**，在编辑器底部 **家具资源** → **承载面编辑**，新增或编辑表面 ID、中心 X/Y/Z、宽 X、深 Z。预览绿色矩形，必要时用拖动手柄微调。
- 点击 **应用并保存当前家具场景** 才真正写入 `use_custom_support_surfaces` / `custom_support_surfaces`；仅编辑绿色预览不会保存。
- 对杯子、书本、手办等小型陈列品：后续注册商品时，审核后启用 `allow_surface_mount`。这只是许可，不会让家具自动获得承载面，也不会绕过边界/碰撞。
- 对普通椅子、沙发、落地灯：一般无需承载面，`allow_surface_mount=false`。
- 若通过自定义配置启用了承载面，保存**空列表**意味着明确取消所有承载面，不是恢复默认自动表面。

## 4. 审核后正式上架商店

1. 编辑器底部打开 **家具注册** → **刷新未注册场景**。
2. 选择刚创建并已检查的 `.tscn`，填写唯一商品 ID、中文商品名、摆放 role、一级/二级商品类型、售价、说明；小物件按需启用 `allow_surface_mount`。
3. 勾选 **我已检查场景、摆放尺寸、角色和商品 ID，确认新增商品**，点击 **确认写入商品目录**。
4. 工具写入唯一的 `data/items/_catalog.tres`；注册前会进行资源校验和备份。保存并审核 Git diff，确保没有重复 ID / 重复 role / 意外序列化改动。
5. 验证商品条目：`category=furniture`、`placement_surface=floor`、`furniture_scene` 指向正确场景，`retired=false`、`price>0`、`catalog_group` 与类型正确。
6. 编辑器底部 **家具资源** 刷新，确认商品预览和模型尺寸可读。

**新增模型与已上架模型的区别**：新模型走“导入 → 注册”；修改已上架模型走“覆盖成品 GLB → 保留原场景/商品 ID → 回归”，不能再次注册同一个 SKU。

## 5. 游戏内验收购买、摆放和存档

1. 启动游戏 → 电脑上的 **回忆生活 · 购物网页** → **购物**；按家具类别筛选或搜索中文名 / ID。
2. 检查商品缩略图、3D 大图、中文名称、类型、尺寸和售价。钱不足时按钮禁用，先确认钱包余额是否达到商品售价；该商品并非注册失败。
3. 点击 **购买**：扣除一次价格，生成一件带唯一 UID 的库存商品；再从 **我的物品** 点击 **摆放**。或点击 **购买并摆放** 直接进入房间编辑器。
4. 测试合法位置与碰撞禁止、移动、旋转、确认摆放、取消、复制（需满足现有库存/购买规则）、重新打开房间和存档恢复。
5. 验证重复购买的同款家具各有自己的 UID；已摆放、可摆放与拥有数量一致。取消未提交的摆放不退回已经完成的购买。
6. 小摆件额外测试桌面/书架/墙面等实际受支持的摆放位置及承载面边界。壁挂交互需遵守独立的墙面规则。
7. 运行正常房间灯光、日落、夜晚等典型环境，对比 Blender 与 Godot 材质表现；截图审核不能被自动 CI 代替。

电竞椅实例：`chair_gaming`，`seating / office_chair`，售价 1500 点，场景 `scenes/room/seating/chair_gaming.tscn`，尺寸 `0.81 × 1.25 × 0.71 m`，当前正式模型来自先前 GLB-first 烘焙/验收工作。

## 6. 自动验收与 PR

在项目根目录执行：

```bash
godot --headless --path . --editor --import
python tools/project_audit.py
godot --headless --path . --script res://tests/life/test_furniture_model_import.gd -- --fresh
godot --headless --path . --script res://tests/life/test_furniture_catalog_registration.gd -- --fresh
godot --headless --path . --script res://tests/life/test_furniture_catalog.gd -- --fresh
godot --headless --path . --script res://tests/life/test_shop_room_flow.gd -- --fresh
godot --headless --path . --script res://tests/life/test_workstation_collision.gd -- --fresh
godot --headless --path . --script res://tests/life/test_room_save_recovery.gd -- --fresh
```

承载面资产另外执行 `test_furniture_support_authoring.gd`、`test_room_support_surfaces.gd`、`test_room_surface_mounts.gd`。电竞椅相关资产另有 `test_chair_gaming_uv.gd`、`test_chair_gaming_pbr.gd` 和对应烘焙 Python 测试；这些是针对电竞椅的专项，不是所有家具的通用约束。

新资产的 PR 应附带：GLB 路径、场景路径、商品元数据、真实 Godot 前/后视角截图、可购买/摆放/存档验证结果。**房间 UI smoke checks 与 Project validation 均通过**，再合并；视觉验收仍需手工确认。

## 7. 出厂验收清单

- [ ] GLB 独立打开有最终材质，无遗失贴图。
- [ ] 米制/Y 向上/+Z 正面/地面中心/尺寸正确。
- [ ] UV、法线、纹理、模型前后侧面经过视觉审查。
- [ ] `Model` 正确引用成品 GLB，`bounds`、`PickArea/Hit` 与可见几何一致。
- [ ] 若有承载面，锚点已应用并保存；小物件的摆放许可经过审核。
- [ ] 商品 ID 与 role 唯一且稳定，售价、分类、显示名称正确。
- [ ] 商店可见、可购买、可重复购买、可从库存摆放。
- [ ] 拖动、旋转、碰撞、取消、保存、退出重载均通过。
- [ ] CI 通过、截图审核、PR 文件清单没有覆盖无关家具。

## 故障排查

| 现象 | 首先检查 |
|---|---|
| GLB 在 Godot 丢材质 | GLB 是否包含纹理，UV/法线是否有效；不要寻找已删除的材质库 |
| 导入后尺寸不对 | Blender 单位/应用缩放、模型原点、场景根 `bounds` |
| 家具导入按钮不可用 | 是否已有同名独立 `.tscn`；该工具禁止覆盖 |
| 不出现在商店 | `_catalog.tres` 是否注册、`price>0`、`retired=false`、过滤条件 |
| 出现在商店但购买按钮不可点 | 钱包是否小于价格；查看按钮提示，确认是否被禁用 |
| 购买后无法摆放 | 库存是否有未使用 UID、placement_surface、碰撞和房间可用空间 |
| 小物件放不上书架 | 小物件 `allow_surface_mount` 与书架 `custom_support_surfaces` 是否同时满足 |
| 原有房间物件读档消失 | 是否改了商品 ID、role、场景资源路径，检查数据清洗与存档恢复测试 |

相关文档：`addons/furniture_manager/README.md`、`docs/MODEL_QUALITY_STANDARD.md`、`docs/SHOP_ROOM_FLOW.md`、`docs/GLB_ONLY_FURNITURE_MATERIALS.md`。
