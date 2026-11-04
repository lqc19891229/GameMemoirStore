游戏数据与资源目录

games/：从 Excel 导入的正式游戏 Resource 与 _catalog.tres，详见 games/README.txt。
items/：统一商品、家具、库存 UID 和商品分类，详见 items/README.md。
hardware/：电脑硬件 3D 模型与库存映射，详见 hardware/README.md。
catalog.json：按 game_id 补充本地化展示信息、标签、评价、安装大小、版本说明和折扣。

基础游戏资料编辑 tools/catalog/game_catalog.xlsx 后，通过 python tools/catalog/import_games.py --project . 导入。
data/games/ 是生成输出，不要直接改动生成的单款游戏 Resource；其 README.txt 模板保存在 tools/catalog/import_games.py 中。

玩家钱包、游戏进度、能力、硬件和自由装修状态存于 user:// 的玩家存档，不存放在仓库的 data/ 中。
房间蓝图保留墙体、门窗、地板材质和逐件家具/壁挂参数；没有工作区、游戏区、休息区等目的标签。旧功能区地板颜色迁移为普通地板材质。
