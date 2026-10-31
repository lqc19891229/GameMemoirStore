# 游戏资料导入

在仓库根目录运行。导入器需要 Python 3.10 或以上版本，不需要第三方 Python 包。

Windows 可双击项目根目录的 import_games.bat。脚本自动寻找 py -3、python 或 python3，检查版本并定位本项目与默认工作簿；成功或失败都会保留窗口供查看。

常用命令：

    python tools/catalog/import_games.py --project .
    python tools/catalog/import_games.py --project . --validate-only
    python tools/catalog/import_games.py --project . --check
    python tools/catalog/import_games.py "D:/Data/game_catalog.xlsx" --project .

## 文件与职责

- game_catalog.xlsx：游戏基础资料。当前启用 CounterSquad 与 CTA3，其余未启用行作为草稿。
- schema.json：字段类型、默认值、必填规则、CPU/GPU 列名映射和备注列白名单。
- import_games.py：读取 Excel、校验并生成资源。
- .gdignore：使 Godot 忽略开发工具和 Excel 工作簿。
- data/games/<game_id>.tres：每款游戏的正式 Resource。
- data/games/_catalog.tres：全部启用游戏的资源清单。
- data/games/.catalog_manifest.json：生成文件和校验值，保护手工改动。

资源类定义在 scripts/game.gd 和 scripts/game_catalog.gd。Python 导入器只生成游戏数据、目录清单、校验清单和 data/games/README.txt，不生成或复制 GDScript。

## 字段规则

| 表格列 | 规则 |
|---|---|
| enabled | 1=导出；0 或空白=草稿 |
| game_id | 以英文字母开头，可含大小写字母、数字和下划线；保留大小写 |
| title | 游戏显示名称 |
| announce_ym | YYYYMM 整数；空白表示不提前预告 |
| store_release_ym | YYYYMM 整数 |
| delist_ym | YYYYMM 整数；空白表示不下架 |
| base_price | 非负整数 |
| developer | 开发者名称 |
| genres | 多个类型用 / 分隔，例如 射击 / 动作 / 多人 |
| CPU / GPU | 型号文本，展示在商品页 |
| series_id | 可选系列 ID |
| description | 可选商品描述 |
| 游戏原型 | 仅编辑备注，不写入游戏资源 |

参与导出的行必须设置 enabled=1，并填写 game_id、title、store_release_ym、base_price 和 developer。enabled 空白的行作为草稿跳过，其余可选字段允许为空。表头会在工作表前 100 行自动识别；当前工作表名称为“游戏资料”。CPU/GPU 支持大写列名和小写别名。旧 capsule 列若存在会被忽略，其他未知列会报错，避免拼写错误被静默忽略。

月份使用 200309 这样的 YYYYMM 整数，不使用 Excel 日期。genres 的空项会被清理，重复类型会报错；旧英文分号格式仍兼容。game_id 大小写保留，但不允许仅大小写不同的重复 ID，以避免 Windows 文件名冲突。

已发布作品应保留 game_id，通过 delist_ym 下架，避免玩家存档中的所有权关联失效。enabled=0 或空白会从生成目录移除对应旧资源。

## 素材目录约定

每款游戏使用 assets/art/<game_id>/ 目录，包含五张 PNG：

| 文件 | 用途 | 建议尺寸 |
|---|---|---|
| <game_id>.png | 商店封面 | 640 × 256，5:2 |
| <game_id>01.png | 展示图 1 | 640 × 360，16:9 |
| <game_id>02.png | 展示图 2 | 640 × 360，16:9 |
| <game_id>03.png | 展示图 3 | 640 × 360，16:9 |
| <game_id>04.png | 展示图 4 | 640 × 360，16:9 |

文件夹名、图片前缀与 game_id 的大小写必须一致。导入器按 01 至 04 的顺序生成 screenshots 引用；封面写入 capsule。五张素材缺少任意一张时默认停止导入，不会覆盖现有生成结果。尺寸为建议值，不强制缩放。

--skip-asset-check 仅跳过图片存在性检查，仍会按约定生成资源引用；正式运行前必须补齐素材。

## 写入保护与测试

导入器先完整校验，再暂存并替换 data/games/。发现该目录中手工新增或修改的文件时会停止，源脚本及其 .gd.uid 不在写入范围内。说明文件 data/games/README.txt 由 import_games.py 中的 GENERATED_README 模板生成，修改说明时应同步修改模板和生成结果。

新增字段时，应同步更新工作簿、schema.json 和导入器字段映射。data/catalog.json 仅按游戏 ID 补充英文名、标签、评价、安装大小、版本说明和演示折扣，不负责正式游戏目录。

运行测试：

    python -m unittest discover -s tests -p "test_catalog_importer.py" -v
    python tools/catalog/import_games.py --project . --check
    godot --headless --path . --editor --import
    godot --headless --path . --script res://tests/test_catalog_resources.gd -- --fresh
    godot --headless --path . --script res://tests/test_catalog_integration.gd -- --fresh

购买、存档、筛选和旧路径回归使用 tests/fixtures/ 中的固定目录，不会加入正式商店。