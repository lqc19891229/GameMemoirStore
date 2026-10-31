# 游戏资料导入

在仓库根目录运行。使用 Python 3.10 或以上版本，无第三方依赖。

Windows 可直接双击项目根目录的 `import_games.bat`。它自动寻找可用的 `py -3`、`python` 或 `python3`，检查版本并定位本项目与默认表格，成功或失败都会保留窗口供查看。未安装 Python 时会显示安装提示。请保留此文件在项目根目录。

```bash
# 编辑并保存 tools/catalog/game_catalog.xlsx 后生成资源：
python tools/catalog/import_games.py --project .

# 只检查表格、字段关联和五张素材路径：
python tools/catalog/import_games.py --project . --validate-only

# 检查提交的资源是否与 Excel 一致：
python tools/catalog/import_games.py --project . --check

# 指定另一份表格：
python tools/catalog/import_games.py "D:/Data/game_catalog.xlsx" --project .
```

Windows 可将 `python` 换成 `py -3`。停止正在运行的游戏，保存并关闭 Excel，执行导入，再等待 Godot 扫描完成后运行主场景。

## 文件

- `game_catalog.xlsx`：当前测试表，当前启用 CounterSquad 与 CTA3，其余未填 enabled 的行作为草稿；“游戏原型”列仅作编辑备注。
- `schema.json`：字段类型、默认值、必填规则、CPU/GPU 列名映射和备注列白名单。
- `import_games.py`：读取 Excel、校验并生成资源。
- `.gdignore`：使 Godot 忽略开发工具与 Excel 文件。

单款游戏资源保存在 `data/games/<game_id>.tres`，`data/games/_catalog.tres` 引用全部启用游戏，默认商店顺序跟随表格行序。总清单以下划线开头，避免和游戏 ID 重名。

资源类直接使用 `scripts/game.gd`（GameDefinition）和 `scripts/game_catalog.gd`（GameCatalog）。`game.gd` 定义字段，`.tres` 引用它并保存具体值。Python 生成 `.tres` 数据、校验清单和 `README.txt` 目录说明，不生成或复制脚本，工具目录不再保留资源类模板。

## 字段

| 表格列 | 资源字段与类型 |
|---|---|
| enabled | 1=导出，0/空白=草稿，不写入游戏资源 |
| game_id | game_id: StringName |
| title | title: String |
| announce_ym | announce_ym: int |
| store_release_ym | store_release_ym: int |
| delist_ym | delist_ym: int |
| base_price | base_price: int |
| developer | developer: String |
| genres | genres: PackedStringArray |
| CPU | cpu: String |
| GPU | gpu: String |
| series_id | series_id: StringName |
| description | description: String |
| （自动生成，无需表格列） | capsule: Texture2D、screenshots: Array[Texture2D] |
| 游戏原型 | 编辑备注，不写入游戏资源 |

参与导出的行必须填 enabled=1，以及 game_id、title、store_release_ym、base_price、developer。enabled 空白的草稿行跳过，其余可选字段可以为空。表头在前 100 行中自动识别，当前原表位于第 3 行；保留工作表“游戏资料”和表头最后一行的英文字段。CPU/GPU 大写列名或小写 cpu/gpu 都支持。“游戏原型”列可有可无，不参与导出。旧表中的 capsule 列若存在也会忽略，所有图片路径统一由 game_id 生成；其他未知列仍会报错，防止拼写错误被忽略。

月份填 `200309` 这样的 YYYYMM 整数，不使用 Excel 日期。announce_ym 和 delist_ym 空白按 0 处理，表示不提前预告、不下架。genres 多个类型用 `/` 分隔，例如 `射击 / 动作 / 多人`，会去掉每项两侧空格与空项；重复类型会报错，旧表的英文分号 `;` 继续兼容。CPU/GPU 是型号文本。

enabled=0 或空白不会导出，对应的旧生成资源会被清理。已有玩家存档关联的游戏应保留 ID 并通过 delist_ym 下架，以保留库中的所有权关联。game_id 以英文字母开头，可含大小写英文字母、数字和下划线。ID 大小写原样保留，但同表不能同时出现仅大小写不同的 ID，以免 Windows 文件名冲突。

## 素材文件夹约定

表格只需填 `game_id=CounterSquad`。导入器自动定位 `res://assets/art/CounterSquad/`，不再需要封面或素材路径列。文件夹名、图片名与 ID 的大小写必须一致。文件夹中按以下规则放置五张 PNG：

| 相对素材文件夹的文件名 | 用途 | 建议尺寸 |
|---|---|---|
| `CounterSquad.png` | 商店封面 | 640×256，5:2 |
| `CounterSquad01.png` | 展示图 1 | 640×360，16:9 |
| `CounterSquad02.png` | 展示图 2 | 640×360，16:9 |
| `CounterSquad03.png` | 展示图 3 | 640×360，16:9 |
| `CounterSquad04.png` | 展示图 4 | 640×360，16:9 |

其他游戏将文件名中的 `CounterSquad` 换成它的 game_id。无需在 Excel 填写任何图片路径。导入器按 01→04 的固定顺序写入 `screenshots`，封面写入 `capsule`；这些是 Texture2D 资源引用，不是运行时扫描文件夹。

默认检查五张文件是否全部存在，缺少任一张就停止，不更新已有生成结果。尺寸是建议值，不强制缩放或修改原图。当前 CounterSquad 封面实际为 1983×793，四张展示图为 640×360，均可直接加载。

兼容旧表：仍有 capsule 列时会忽略其内容，统一按 game_id 查找五张 PNG；旧列中的路径不再覆盖自动路径。`--skip-asset-check` 仅跳过图片存在性检查，仍按约定生成引用，实际运行前必须补齐素材。

商品页主展示区按 16:9 保持完整画面，四个缩略图可以切换独立展示图；商品卡片与右侧简介区继续使用封面。首页推荐区的四个缩略图也使用独立展示图。

## 写入与保护

先完整校验，再暂存并替换 `data/games/`。校验失败时保留已有结果；发现该目录中手工新增或修改的文件时停止。源脚本与 `.gd.uid` 位于 scripts 中，不属于导入器的写入范围。

游戏资料在 Excel 编辑，字段结构在 `scripts/game.gd` 编辑。新增字段时，需要同步更新 Excel、`schema.json` 和导入器的字段映射。Python 工具不直接修改 Excel 或源脚本。

主商店已读取资源。data/catalog.json 目前只补充英文名、标签、评价、安装大小、版本说明和原有演示折扣。首发原价以 Excel 为准，实际成交价仍会套用该演示折扣；新增游戏默认没有折扣。后续可独立加入促销排期数据。

## 测试

```bash
python -m unittest discover -s tests -p "test_catalog_importer.py" -v
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/test_catalog_resources.gd
godot --headless --path . --script res://tests/test_catalog_integration.gd -- --fresh
```

资源加载检查会遍历当前启用目录，校验每款作品的 ID、字段和图片引用，不固定游戏数量或截图分辨率；导入器检查同时确认生成资源与表格一致。购买、存档、筛选与旧路径回归使用 tests/fixtures 中固定的旧目录，不影响正式商店。
