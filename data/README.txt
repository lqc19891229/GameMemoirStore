游戏与硬件数据

games/：Excel 导入生成的单款游戏 Resource 和 _catalog.tres，是游戏平台正式游戏列表的来源。
hardware/：电脑设备模型映射、占地尺寸、显示器屏幕尺寸和位置校准。
catalog.json：按 game_id 补充英文名、标签、评价、安装大小、版本说明和演示折扣。

游戏基础资料在 tools/catalog/game_catalog.xlsx 修改，再运行 tools/catalog/import_games.py 导入。data/games/ 由导入器维护，不要手工修改生成的游戏资源。

玩家钱包、游戏进度、能力、设备安装、房间布局和活动状态保存在 user://memoir_store_v01.json，不保存在本目录。