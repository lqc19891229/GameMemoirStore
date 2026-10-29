# 游戏资料导入

在仓库根目录运行。使用 Python 3.10 或以上版本，无第三方依赖。

```bash
# 编辑并保存 tools/catalog/game_catalog.xlsx 后生成资源：
python tools/catalog/import_games.py --project .

# 只检查表格、字段关联和封面路径：
python tools/catalog/import_games.py --project . --validate-only

# 检查提交的生成资源是否与 Excel、模板一致：
python tools/catalog/import_games.py --project . --check

# 指定另一份表格：
python tools/catalog/import_games.py "D:/Data/game_catalog.xlsx" --project .
```

Windows 可将 `python` 换成 `py -3`。停止正在运行的游戏，保存并关闭 Excel，执行导入，再等待 Godot 扫描完成后运行主场景。

## 文件

- `game_catalog.xlsx`：精简游戏资料表，14 列，包含 12 款示例游戏。
- `schema.json`：字段类型、默认值、必填规则、CPU/GPU 列名映射。
- `import_games.py`：读取 Excel、校验并生成资源。
- `resource_types/`：生成器使用的两个资源类模板。
- `.gdignore`：使 Godot 忽略工具目录，避免模板与运行时类重复注册。

生成结果位于 `generated/game_catalog/`。每款游戏一份 `.tres`；`catalog.tres` 引用全部启用游戏，默认商店顺序跟随表格行序。模板更新后重新执行导入命令。

## 字段

| 表格列 | 资源字段与类型 |
|---|---|
| enabled | 导入控制，0/1，不写入游戏资源 |
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
| capsule | capsule: Texture2D |

必填：enabled、game_id、title、store_release_ym、base_price、developer。其他字段可以为空。表头在前 100 行中自动识别，当前原表位于第 3 行；保留工作表“游戏资料”和表头最后一行的英文字段。CPU/GPU 大写列名或小写 cpu/gpu 都支持。

月份填 `200309` 这样的 YYYYMM 整数，不使用 Excel 日期。announce_ym 和 delist_ym 空白按 0 处理，表示不提前预告、不下架。genres 多个类型用英文分号分隔。CPU/GPU 是型号文本；capsule 填 `res://` 开头的项目图片路径，空白则导出空图片引用。

enabled=0 会清理对应游戏的生成资源。已有玩家存档关联的游戏应保留 ID 并通过 delist_ym 下架，以保留库中的所有权关联。game_id 以小写字母开头，仅用小写字母、数字和下划线。

## 写入与保护

先完整校验，再暂存并替换整个生成目录。校验失败时保留已有结果；发现生成目录中手工新增或修改的文件时停止。Godot 自动创建的 `.gd.uid` 会保留，避免重新导入产生无关的 UID 变化。

表格与模板是编辑入口，生成目录是输出。Python 工具不直接修改 Excel。

主商店已读取资源。data/catalog.json 目前只补充英文名、标签、评价、安装大小、版本说明和原有演示折扣。首发原价以 Excel 为准，实际成交价仍会套用该演示折扣；新增游戏默认没有折扣。后续可独立加入促销排期数据。

## 测试

```bash
python -m unittest discover -s tests -p "test_catalog_importer.py" -v
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/test_catalog_resources.gd
godot --headless --path . --script res://tests/test_catalog_integration.gd -- --fresh
```

资源字段检查针对原表 12 款示例游戏。改动数量、月份和硬件型号后，需要相应调整该示例测试的预期。通用 Python 校验与导入规则可继续用于新增数据。
