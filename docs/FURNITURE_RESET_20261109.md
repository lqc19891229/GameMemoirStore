# 家具重制：空白资源分支

此分支是**2026-11-09 家具美术重制起点**，不应直接当作已验收、可发布的游戏版本。

## 已清空

- `assets/models/room/{tables,seating,storage,lighting,decor}/` 的旧 GLB、对应 `.import` 和旧家具专属贴图；
- `scenes/room/{tables,seating,storage,lighting,decor}/` 的旧家具场景；
- `data/items/_catalog.tres` 中指向上述独立家具场景的 37 个商品定义（包括旧电竞椅）；
- 房间 `scenes/room/room.tscn` 的五个旧样板家具实例。

## 明确保留

- 房间壳体 `modern_room_shell.tscn`、原有房间建筑系统和布局代码；
- 电脑工作台及设备 GLB（`assets/models/hardware/`、`scenes/computer/`），否则启动和电脑操作会断裂；
- 未使用独立家具场景的 starter / legacy 商品数据（例如 `starter_desk`、`oak_desk`），用于防止旧存档和游戏机制立即失效；
- 原家具导入器、发布器、商品目录和购物/库存逻辑；
- Git 历史：旧资产可由基线提交 `f5da6cdc23096d1e9b891a256097058ba14c6b77` 恢复。

## 已知未完成的迁移

多项 Godot 回归测试仍引用旧家具 GLB / 场景和旧 SKU；旧存档也可能含对应商品 ID。**本清理分支只用于隔离美术资产，不承诺当前游戏或 CI 通过。禁止在完成测试迁移与存档清理策略前合并 main。**

新家具采用 1 Godot 单位 = 1 米，按 `docs/REAL_SCALE_FURNITURE.md` 统一尺寸，经 GLB → Godot 场景 → 商品注册 → 商城购买 / 房间摆放验收后逐件重新加入。

制作下一件家具时，先使用**全新商品 ID**，以避免旧玩家存档的库存 UID 产生语义冲突。
