# 游戏回忆录 · 像素客户端 v0.3

带独立页面的像素游戏平台客户端。保留原创名称、像素美术和游戏内预算，主要参考成熟 Steam 客户端的导航习惯与页面分工。游戏基础资料由 Excel 生成每款游戏的 `.tres`，主商店已经读取这套资源。

## 打开与运行

1. 克隆或下载完整仓库。
2. 使用 Godot 4.6 导入仓库根目录的 `project.godot`。
3. 首次导入完成后按 **F5**。主场景仍然是 `scenes/store.tscn`，按 F6 也会进入新版客户端。

使用 GDScript 和 Compatibility 渲染器，不需要插件、.NET、Steam SDK 或登录。此文件是源工程，不包含独立的 Windows 可执行文件。

## 游戏资料管理

编辑 `tools/catalog/game_catalog.xlsx`，保存并关闭 Excel。Windows 用户可直接双击项目根目录的 **`import_games.bat`**，自动导入并显示结果；发生错误时窗口会保留错误信息。无需手动输入命令，项目路径中含空格或中文也可以使用。

也可以在仓库根目录运行以下命令，再重新启动游戏：

```bash
python tools/catalog/import_games.py --project .
```

需要 Python 3.10 或以上版本，无第三方依赖。Windows 也可以使用 `py -3` 代替 `python`。仓库已包含生成结果，首次运行游戏不需要安装 Python。

表格中的 `enabled` 只控制导出，“游戏原型”只作备注。`CPU`、`GPU` 映射为字符串 `cpu`、`gpu`。游戏类型用 `/` 分隔，例如 `射击/动作/多人`。`capsule` 填素材文件夹，例如 `res://assets/art/CounterSquad`，导入器将 `CounterSquad.png` 作为封面，将 `CounterSquad01.png` 到 `CounterSquad04.png` 作为四张展示图，自动写入 `screenshots`。文件夹和图片名与 game_id 大小写保持一致。旧版直接填写封面图片路径仍可使用。默认游戏顺序跟随表格行序。

| 资料 | 当前来源 |
|---|---|
| 游戏列表、ID、名称、开发商、类型、系列、介绍、封面和展示图、CPU/GPU、原价、预告/上架/下架月份 | `data/games/_catalog.tres` 及其引用的单款游戏资源 |
| 英文名、标签、评价、版本文案、安装大小、现有演示折扣 | `data/catalog.json` 中按相同 ID 查找的补充资料 |
| 所有权、愿望单、购买时实际成交价、安装状态、游玩记录 | 玩家存档 |

资源字段优先于旧 JSON 的同名资料。新增游戏只需加入 Excel，未填写的补充资料使用默认值，不需要在 JSON 再添加一条游戏。现有演示折扣仍由 JSON 提供，例如原价 88、降价 25% 时售价为 66；本次精简表格尚未管理折扣排期。

月份使用 `YYYYMM` 整数。`announce_ym=0` 的未来游戏在上架前不出现在“即将推出”中；填写预告月份后从该月展示。下架月份起停止销售，已购买游戏继续保留在库中并可安装。已发布游戏需要下架时使用 `delist_ym`，保持资源与 ID 存在以关联旧存档；`enabled=0` 会从生成目录移除整款游戏。

只校验，或检查生成文件是否与表格一致：

```bash
python tools/catalog/import_games.py --project . --validate-only
python tools/catalog/import_games.py --project . --check
```

资料在 Excel 修改，然后重新导入到 `data/games/`。`scripts/game.gd` 是单款游戏唯一的 Resource 字段定义，`.tres` 引用该脚本并保存具体值。Python 只写资源数据，不生成或覆盖 GDScript。调整字段结构时，同步修改 `game.gd`、Excel、`schema.json` 和导入器的字段映射。更多填写规则见 [导入工具说明](tools/catalog/README.md)。

## 本次主要变化

| 部分 | 实现 |
|---|---|
| 客户端外壳 | 顶部菜单、商店/库/社区/个人资料、前进后退、固定底栏、钱包与模拟年月 |
| 商店导航 | 您的商店、新品与热门商品、类别下拉菜单；右侧愿望单、购物车、搜索 |
| 首页 | 推荐轮播、截图缩略图、特别优惠、发现队列入口、横向商品列表 |
| 商品页 | 独立可滚动页面、四张独立展示图、类型标签、开发商、评测、购买区域、系统需求 |
| 发现队列 | 最多五款已上架作品，排除已拥有与已忽略项，可加入愿望单、关注、忽略或继续下一款 |
| 搜索结果 | 按名称、英文名、制作组、类型和标签搜索；价格/折扣/名称排序；隐藏已拥有 |
| 愿望单 | 独立横向条目，移到顶部、移除、按价格/折扣排序、添加购物车 |
| 购物车 | 独立页面、移除商品、总价与优惠、预算检查、审核购买、完成回执 |
| 游戏库 | 固定左侧列表、独立右侧滚动内容、全部/已安装/收藏夹分类、搜索、右键菜单 |
| 模拟安装 | 下载队列顺序推进、进度条、底栏状态、取消安装、卸载；购买记录与游戏所有权保留 |
| 模拟游玩 | 已安装游戏可打开游玩窗口，结束后记录一次 45 分钟的模拟体验 |
| 个人资料 | 收藏数量、愿望单数量、游戏收藏和最近游玩记录 |
| 社区与好友 | 游戏世界内的开发者来信和虚构好友信息 |
| 存档 | 自动保存，兼容 v0.2 使用的版本 1 存档 |

购买成功后会从愿望单中移除已购买作品；同一游戏不会重复购买。下载队列同时只推进一个任务。

## 操作

- 点击推荐封面或游戏条目：进入商品页面。
- 全局搜索输入后按回车；库侧栏搜索也使用回车提交。
- 添加至购物车后，从右上角购物车继续购买并审核订单。
- 在库中点击“安装”，完成后按钮变为“开始游戏”。
- 游戏库左侧条目可以右键：安装/开始、收藏夹、商店页、卸载。
- 点击底栏“下载”查看任务，“年月 > 下个月”增加预算并开放后续作品。
- 顶部前进后退、Alt+左右方向键、鼠标侧键支持页面历史；Esc 返回上一页。
- Ctrl+F 搜索；F11 切换全屏；设置菜单可重置回忆录。

## 当前范围

当前工作簿仅启用 CounterSquad 测试游戏，生成目录与商店只包含这一款。原 12 款演示作品保存在 tests/fixtures，用于固定回归测试。模拟时间从 2003 年 9 月至 2004 年 2 月。采用玩家熟悉的成熟客户端布局，目前不按年代重建每一版历史客户端界面。

所有作品资料、价格、评价和上架时间都是演示数据，尚未替换为核实后的发行年表。支持每款游戏独立的四张展示图；旧版只有封面的资源继续使用封面取景。社区、好友与游玩记录属于游戏世界，不连接现实账号，不下载或启动外部游戏。成就系统后续按设计年表开放。

## 文件与编辑位置

| 文件 | 职责 |
|---|---|
| `scenes/store.tscn` | 新版主场景，保留客户端头部、商店导航、内容滚动区、固定底栏和通知层 |
| `scripts/client.gd` | 客户端外壳、路由与历史、菜单、下载计时、模拟游玩和提示 |
| `scripts/client_pages.gd` | 分别构建首页、搜索、商品、愿望单、购物车、库、下载、资料和社区页面 |
| `scripts/client_ui.gd` | 原生 Control 与 Container 工厂、主题样式、封面和商品行 |
| `scripts/store_state.gd` | 钱包、购买、愿望单、收藏夹、安装、游玩和存档 |
| `data/games/_catalog.tres` | 当前游戏资源清单，主商店通过 preload 引用 |
| `data/games/` | 每款游戏各自的 `.tres` 与总清单 |
| `scripts/game.gd` | GameDefinition，单款游戏的字段定义和上架状态查询 |
| `scripts/game_catalog.gd` | GameCatalog，管理游戏资源列表及查询 |
| `tools/catalog/` | 原始 Excel、Python 导入器和字段规范 |
| `data/catalog.json` | 评价、标签、折扣等尚未进入表格的补充展示资料 |
| `assets/client_theme.tres` | 新版默认字体和主题 |
| `scenes/legacy_store.tscn` | 保留 v0.2 原场景，便于对照 |
| `previews/` | 本次实际运行截图 |
| `CLIENT_STRUCTURE.md` | 新版节点与页面运行机制 |

页面中的可变部分在运行时由原生 Godot Container 节点构建。运行后在 Scene 面板切换到 Remote，可查看完整页面节点。主场景不再沿用 v0.2 的 116 节点平铺布局。`tools/build_scene.py` 仅生成旧版 `legacy_store.tscn`，新版页面通过原生 Container 构建，不依赖生成器。

存档路径仍为 `user://memoir_store_v01.json`。程序会读取版本 1 并用版本 2 格式保存，保留旧预算、购物车、收藏与愿望单。新增加的安装与游玩字段初始化为空。

## 验证

Godot 4.6 stable 官方版本运行检查：

- 导入器：类型分隔、素材目录解析、大小写 ID、备注列、缺图阻止写入、旧图片路径与文件保护。
- 资源与页面：封面及四张展示图加载、缩略图切换、上架/下架、成交价与库保留。
- 固定样例回归：客户端导航、购买、存档、原生窗口与旧版商店。

命令行验证：

```bash
python -m unittest discover -s tests -p "test_catalog_importer.py" -v
python tools/catalog/import_games.py --project . --check
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/test_catalog_resources.gd
godot --headless --path . --script res://tests/test_catalog_integration.gd -- --fresh
godot --headless --path . --script res://tests/test_client.gd -- --fresh
godot --headless --path . --script res://tests/test_store.gd -- --fresh
# 原生窗口检查需要图形显示环境：
godot --path . --script res://tests/test_client_windows.gd -- --fresh
```

`--fresh` 使用不保存的初始状态，测试单独使用临时存档，不覆盖玩家的正常存档。

## 资料与素材

字体：Ark Pixel，SIL Open Font License 1.1，详见 `assets/fonts/OFL.txt` 与 `ASSET_CREDITS.md`。

页面结构参考：
- Steam 商店：https://store.steampowered.com/
- Steam 游戏页面：https://store.steampowered.com/app/220/HalfLife_2/
- Steam 游戏库介绍：https://store.steampowered.com/libraryupdate/

像素插画随工程打包，运行时不加载网络素材。
