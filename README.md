# 游戏回忆录 · 房间与电脑 v0.4

Godot 4.6 像素风游戏收藏经营原型。玩家在房间里使用电脑，通过游戏平台购买和游玩作品，直播、制作攻略赚取游戏内点数，再购买设备和家具，并将成就放进展示柜。

## 打开与运行

1. 使用 Godot 4.6 导入根目录 `project.godot`。
2. 等待首次导入完成，按 **F5** 进入玩家房间。主场景为 `scenes/game_root.tscn`。
3. 点击房间电脑或“使用电脑”，打开桌面，再进入游戏平台或购物网页。

使用 GDScript 与 Compatibility 渲染器，无需 .NET 或插件。单独运行 `scenes/store.tscn` 可预览客户端；完整生活系统请从主场景运行。

## 首次体验

- 在游戏平台中购买 CounterSquad，然后到“库”安装，约 5 秒后可以启动。
- 游玩窗口循环播放四张独立展示图，自动积累游玩时间、玩家能力和成就挑战进度。
- 点击“开始直播”，每 5 分钟模拟游玩结算收入；最小化或返回房间后仍继续运行。
- 打开购物网页，购买外设、主机、家具或装饰；在“我的物品”点击“安装 / 摆放”。
- 游玩满 10 分钟后，结束游戏，到平台“创作”页制作攻略。20 分钟模拟时间后获得稿费，之后还有有限的阅读收益。
- 获得成就后，回房间打开“成就展示柜”，选择展示或收起奖杯。

初始钱包 160 点。房间、平台、网页共用同一个钱包和存档。

## 时间、窗口与活动

默认 **1 秒现实时间 = 1 分钟模拟活动时间**。`GameSession` 独立于窗口运行，统一推进下载、游玩、直播、攻略制作和阅读收益。发行月份沿用原型的手动“下个月”按钮，时间范围为 2003 年 9 月至 2004 年 2 月。

| 操作 | 行为 |
|---|---|
| 最小化应用 | 隐藏窗口，从任务栏再次打开 |
| 返回房间 / Esc | 切换房间与桌面，活动继续 |
| 关闭游戏平台 | 游戏与直播继续；重新打开仍保留所有权和进度 |
| 关闭游戏窗口 / 结束游玩 | 结束当前游玩和直播，只结算一次游玩记录 |
| 制作攻略 | 占用主要活动，期间不能另开一局游戏；可以购物或查看房间 |
| 退出程序 | 保存当前活动与进度；下次进入后继续。离线时间不计收益 |

应用窗口标题栏支持拖动、最小化、恢复铺满和关闭。桌面“继续游玩”可打开存档中正在运行的游戏。

## 玩家成长与收入

六项能力为反应、操作、思考、探索、规划、协作。游戏类型决定初版能力权重，多人 / 合作标签增加协作占比。游玩会逐步提高相关能力；能力和已安装主机、外设共同影响挑战进度倍率。

当前每款游戏使用三个通用里程碑模板：10、60、180 点挑战进度。直播每 5 分钟基础获得 2 点，安装麦克风或进阶主机后增加收入。每款游戏可制作一篇攻略，已解锁成就影响稿费；发布后每 10 分钟获得 1 点阅读收益，最多 60 次。

商品与数值定义在 `scripts/life/life_data.gd`。首版房间使用固定物品位置和两种布置，支持更换书桌、主机、外设、麦克风、台灯与成就柜。硬件暂提供效率加成，尚未根据 Excel 的 CPU/GPU 型号设置运行门槛；每款游戏独立的成就条件、直播热度和自由家具摆放可后续扩展。

## 游戏资料管理

编辑并保存 `tools/catalog/game_catalog.xlsx`。Windows 双击根目录 **`import_games.bat`**，或在根目录运行：

```bash
python tools/catalog/import_games.py --project .
```

导入需要 Python 3.10 或以上版本，无第三方依赖。游戏运行不需要 Python。当前工作簿保留用户的 CounterSquad 测试数据。

| 表格字段 | 填写方式 |
|---|---|
| game_id | 稳定 ID，保留大小写，例如 `CounterSquad` |
| genres | 用 `/` 分隔，例如 `射击/动作/多人` |
| capsule | 素材目录，例如 `res://assets/art/CounterSquad` |
| announce_ym / store_release_ym / delist_ym | YYYYMM 整数，分别控制预告、上架、下架 |
| CPU / GPU | 型号文本，显示在商品页 |
| enabled | 是否参与导出；“游戏原型”列只作备注 |

素材目录包含 `<game_id>.png` 封面和 `<game_id>01.png`～`04.png` 展示图。Python 生成 `data/games/<game_id>.tres`、`_catalog.tres`、目录说明和校验清单，不覆盖源脚本。详细规则见 [导入说明](tools/catalog/README.md)。

`data/catalog.json` 仍用于按相同 ID 补充英文名、标签、评价、安装大小和演示折扣。新增游戏没有补充资料时使用默认值。已发布游戏应保留 ID，以 `delist_ym` 下架；`enabled=0` 会移出生成目录。

```bash
python tools/catalog/import_games.py --project . --check
```

## 场景与职责

| 位置 | 用途 |
|---|---|
| `scenes/game_root.tscn` | 主入口，组合共享会话、房间和桌面 |
| `scenes/life/` | 房间、桌面、应用窗口、网页、游戏画面、家具和展示柜 |
| `scenes/store.tscn` | 可嵌入桌面的游戏平台客户端 |
| `scripts/life/` | 生活系统、统一时钟、设备、创作收入和成就逻辑 |
| `scripts/client*.gd` | 平台导航、页面与通用界面控件 |
| `scripts/store_state.gd` | 唯一玩家状态、游戏目录、交易和存档 |
| `scripts/game.gd` | 单款游戏 Resource 定义 |
| `data/games/` | Excel 导入生成的正式游戏目录 |
| `tests/fixtures/` | 固定测试样本，不加入正式商店 |

运行时可在 Godot 的 Remote 场景树查看窗口和页面节点。各文件夹有简短 `README.txt`；详细运行机制见 [客户端与场景结构](CLIENT_STRUCTURE.md)。

## 存档与验证

继续使用 `user://memoir_store_v01.json`，保存格式升级为版本 3，兼容读取版本 1、2。旧版钱包、购买、愿望单、安装与游玩记录保留；没有生活数据的旧存档会获得初始家具和设备。

```bash
python -m unittest discover -s tests -p "test_catalog_importer.py" -q
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/test_catalog_resources.gd -- --fresh
godot --headless --path . --script res://tests/test_catalog_integration.gd -- --fresh
godot --headless --path . --script res://tests/test_client.gd -- --fresh
godot --headless --path . --script res://tests/test_store.gd -- --fresh
godot --headless --path . --script res://tests/life/test_life_flow.gd -- --fresh
# 以下检查需要图形环境：
godot --path . --script res://tests/test_client_windows.gd -- --fresh
```

`--fresh` 禁用正常存档读写；存档测试使用独立临时文件。房间与创作内容属于游戏世界，不连接现实直播、购物或游戏平台账号。素材与字体说明见 `ASSET_CREDITS.md`。
