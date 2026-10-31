游戏数据

games/：Excel 导入生成的单款游戏资源与总清单，是商店游戏列表的来源。
hardware/：可更换电脑设备的外观和屏幕校准配置，不由 Excel 导入器生成。
catalog.json：按相同游戏 ID 补充英文名、标签、评价、安装大小、版本说明和演示折扣。

游戏基础资料在 tools/catalog/game_catalog.xlsx 修改，再执行导入。
玩家进度另存于 user://memoir_store_v01.json，不保存在本目录。
