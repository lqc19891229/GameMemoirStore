Excel 游戏资料管理

game_catalog.xlsx：游戏基础资料；编辑后保存，再运行导入。
import_games.py：校验表格、解析类型、按 game_id 定位五张图片，并生成 data/games 中的资源、清单和目录说明。
schema.json：字段类型、默认值、必填规则、列名映射和备注列规则。
README.md：完整填写规则、素材命名、命令和写入保护机制。
.gdignore：使 Godot 忽略开发工具目录。

Windows：双击项目根目录 import_games.bat；需要 Python 3.10 或以上版本。
游戏类型用 / 分隔；图片放在 assets/art/<game_id>/，不需要 capsule 路径列。
enabled=1 才导出，0 或空白保留为草稿。

常用命令：
    python tools/catalog/import_games.py --project .
    python tools/catalog/import_games.py --project . --validate-only
    python tools/catalog/import_games.py --project . --check

data/games/README.txt 由导入器生成，修改目录说明时请同步修改 import_games.py 的 GENERATED_README。