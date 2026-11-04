# 游戏回忆录（GameMemoirStore）

一款以**游戏玩家成长、收藏与个人空间布置**为主题的模拟经营游戏。玩家购买与游玩游戏、完成挑战、积累收入，并升级电脑设备、自由装饰自己的房间。项目使用 Godot 4，入口为 `scenes/main/game_root.tscn`。

## 核心循环

**购买游戏 → 游玩与完成成就 → 收入及能力成长 → 升级硬件和装修房间 → 体验更多游戏**

| 系统 | 已有能力 | 仍待完善 |
| --- | --- | --- |
| 游戏与成长 | 商城、下载与安装、游戏库、游玩记录、挑战成就、能力成长、直播和攻略收益 | 游戏内容、成就深度、长期收藏目标 |
| 电脑与设备 | 购买与更换显示器、机箱、键盘、鼠标，3D 桌面展示与布置，部分收益加成 | CPU/GPU/内存等装机细节、兼容性与性能模拟 |
| 房间自由装修 | 矩形／L 型／自由轮廓、墙体和门窗、逐格地板与墙面装修、家具购买/摆放/改色/复制、吸附/对齐/碰撞、桌面及书架陈列、内外墙挂画与壁灯、撤销/重做/存档 | 更多家具与材质、模型与光影品质、装修操作体验 |

### 房间设计原则

**房间是自由布置的空间，不预设用途。** 不划分“工作区、游戏区、休息区”，也不提供阅读／游戏／休息灯光场景预设。家具及装饰的位置由玩家决定；实体内墙可自由隔开空间，但不会给空间赋予系统功能标签。玩家逐件控制壁灯开关、亮度与三档色温。原有分区存档的地板颜色在载入时转为普通逐格地板材质，手动绘制的颜色优先。

## 开发与运行

- 使用项目的 Godot 4 工程文件 `project.godot` 打开仓库。
- 首次运行或资源变更后，用 `godot --headless --path . --editor --import` 导入资源。
- 启动游戏：`godot --path .`。
- 运行一个回归：`godot --headless --path . --script res://tests/life/test_room_zones.gd -- --fresh`。该历史文件名现用于**自由装修与旧分区数据迁移**测试。
- 综合测试入口：`.github/workflows/project-validation.yml`；房间快速回归：`.github/workflows/room-ui-smoke.yml`。
- 游戏资料从 `tools/catalog/game_catalog.xlsx` 导入：`python tools/catalog/import_games.py --project . --check` 或在 Windows 运行 `import_games.bat`。

普通游玩不需要 Blender；模型构建脚本只用于离线资产制作。玩家进度写入 `user://`，不是版本控制中的 `data/`。

## 目录导航

| 目录 | 说明 |
| --- | --- |
| [assets/README.txt](assets/README.txt) | 图片、字体、硬件与房间模型 |
| [data/README.txt](data/README.txt) | 游戏、物品、硬件资源与数据来源 |
| [scenes/README.txt](scenes/README.txt) | 主场景、电脑、房间、应用界面 |
| [scripts/README.txt](scripts/README.txt) | 状态、玩法、房间与交互脚本 |
| [tests/README.txt](tests/README.txt) | Godot 和 Python 回归测试 |
| [tools/README.txt](tools/README.txt) | 游戏资料导入、模型生成、资源审计 |
| [docs/ROOM_SIX_IMPROVEMENTS.md](docs/ROOM_SIX_IMPROVEMENTS.md) | 房间系统迭代与自由装修原则 |
| [docs/WORKSTATION_LAYOUT.md](docs/WORKSTATION_LAYOUT.md) | 设备与家具布置规则 |
| [docs/ROOM_SCENE_FIRST_UI.md](docs/ROOM_SCENE_FIRST_UI.md) | 房间直接交互界面 |
| [docs/MODEL_QUALITY_STANDARD.md](docs/MODEL_QUALITY_STANDARD.md) | 3D 模型质量标准 |

## 当前开发方向

优先扩展家具、装饰素材、自由摆放体验与画面质量；其次深化硬件装机和游戏成就内容。**不重新引入功能区划分或按用途命名的场景预设。**
