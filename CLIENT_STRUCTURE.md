# 游戏回忆录：场景架构与状态流

## 运行入口

`scenes/main/game_root.tscn` 是主入口；`GameSession` 持有共享状态，`ComputerDesktop` 提供 3D 工作台、房间与应用窗口。游戏使用 Godot 4.6 GL Compatibility 渲染器。

```text
GameRoot
├── GameSession（共享存档、时间、交易与活动）
└── ComputerDesktop（模式切换、HUD、窗口）
    ├── Workstation3D
    │   ├── Room（户型、墙体、装修、Furniture）
    │   ├── TableGroup / Equipment
    │   ├── LayoutEditor
    │   └── Camera / Lights
    ├── DesktopViewport / DesktopScreen（电脑内系统纹理）
    └── HUD / Interface
```

## 主要目录

| 路径 | 职责 |
|---|---|
| `scenes/apps/platform/` | 游戏商城、游戏库、下载与社区等页面 |
| `scenes/apps/browser/` | 购买硬件/家具和库存界面 |
| `scenes/apps/game/` | 游玩、成就挑战、直播相关窗口 |
| `scenes/computer/` | 工作台、电脑屏幕纹理、设备槽位 |
| `scenes/room/` | 房间本体及按类型分类的家具场景 |
| `scripts/life/` | 生活活动、窗口、状态接线、布置和交互 |
| `scripts/room/` | 墙体、户型、家具拾取及承载面 |
| `data/items/` | 商店物品和家具定义 |
| `assets/models/room/` | 已导入的完整默认外观 GLB |
| `addons/furniture_manager/` | 编辑器家具浏览、导入、注册 |

## 玩家输入与布局

总览相机可旋转、缩放；在工作台内点击显示器通过射线和 UV 坐标映射输入到 `DesktopViewport`。电脑内 UI 和 3D 房间独立渲染。布置模式中可以移动、旋转、复制、收纳家具，使用吸附和碰撞约束；草稿可以撤销、重做、应用或取消。

家具商品以稳定 `item_id` 标识类型，每件购买家具拥有独立库存 `uid`。商品对应独立 `.tscn` 场景，场景引用 GLB 并定义碰撞/拾取等信息；默认视觉材质直接来自 GLB。原有整件家具换色继续由 `furniture_colors` 记录。

先前的按部件材质编辑、共享家具 `.tres` 材质库和 `furniture_materials` 运行时覆盖已删除。旧存档中的相关字段不再应用，不影响家具的正常持有和摆放。

## 玩法与存档

`GameSession` 的模拟时钟协调下载、游玩、直播、攻略与收入等状态；游戏商城、浏览器和游戏窗口使用同一份玩家数据。电脑硬件模型、房间外观和家具摆放通过共享状态同步。

正常存档在 `user://memoir_store_v01.json`；`--fresh` 供测试隔离。游戏数据 `data/games/` 由 `tools/catalog/import_games.py` 从工作簿生成。所有编辑器和运行时功能应避免在读取历史存档时丢失商品所有权、UID 与布局。

## 验证参考

- `README.md`：启动与整体说明
- `EDITOR_WORKFLOW.md`：模型制作、家具注册和编辑器操作
- `addons/furniture_manager/README.md`：家具编辑器工具
- `docs/WORKSTATION_LAYOUT.md`：布置与碰撞
- `tests/README.txt` 与 `.github/workflows/`：回归测试与 CI
