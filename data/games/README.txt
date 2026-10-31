游戏资源目录（自动生成）

<game_id>.tres：单款游戏资料，引用 scripts/game.gd，保存名称、开发者、类型、价格、时间线、CPU/GPU 文本、封面和展示图。
_catalog.tres：全部启用游戏的资源清单，游戏平台从这里读取正式游戏目录。
.catalog_manifest.json：生成文件清单和校验值，用于保护手工修改及识别过期输出。
README.txt：本目录说明，由导入器一同生成。

请在 tools/catalog/game_catalog.xlsx 修改资料，然后运行项目根目录的 import_games.bat，或执行 python tools/catalog/import_games.py --project .。

封面和四张展示图自动从 assets/art/<game_id>/ 读取。表格不需要填写图片路径。enabled=1 才导出；0 或空白保留为草稿。

本目录由导入器统一维护。说明文字模板位于 tools/catalog/import_games.py 的 GENERATED_README；不要只修改本文件，否则下一次导入会覆盖说明。