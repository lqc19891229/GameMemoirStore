游戏资源目录（自动生成）

<game_id>.tres：每款游戏的资料，引用 scripts/game.gd，保存封面、展示图、价格和上架时间等。
_catalog.tres：全部启用游戏的资源清单，商店通过它加载游戏。
.catalog_manifest.json：记录生成文件及校验值，防止导入时覆盖手工改动。
README.txt：本目录说明，由导入器一同生成。

请在 tools/catalog/game_catalog.xlsx 修改资料，然后双击项目根目录 import_games.bat。
封面与四张展示图自动从 assets/art/<game_id>/ 读取，无需在表格填写路径。
本目录由导入器统一维护；说明文字在 tools/catalog/import_games.py 的 GENERATED_README 中修改。
