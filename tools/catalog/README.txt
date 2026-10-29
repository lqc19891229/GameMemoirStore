Excel 游戏资料管理

game_catalog.xlsx：游戏基础资料；编辑后保存，再运行导入。
import_games.py：校验表格，解析类型和素材文件夹，生成 data/games 中的资源及说明文件。
schema.json：字段类型、默认值、必填规则、列名映射和备注列规则。
README.md：详细填写规则、素材命名、命令和文件保护机制。
.gdignore：使 Godot 忽略这个开发工具目录。

Windows：双击项目根目录 import_games.bat；需 Python 3.10 或以上版本。
游戏类型用 / 分隔；capsule 填 res://assets/art/<game_id>。
