项目数据资源

games/：由 tools/catalog/game_catalog.xlsx 和导入器生成的游戏 Resource 与正式游戏目录。
items/：统一物品与家具商品目录；家具和设备按商品 ID / 库存 UID 管理，详见 items/README.md。
hardware/：设备模型映射、尺寸与显示器表面参数，详见 hardware/README.md。
catalog.json：按 game_id 补充游戏介绍与展示字段。

修改游戏基础数据请从 Excel 经 tools/catalog/import_games.py 导入；不要直接维护生成的 games/*.tres。
家具商品定义以 items/_catalog.tres 为准。玩家状态及房间布局保存在 user://memoir_store_v01.json，不在 data/ 下。
旧家具按部件材质字段 furniture_materials 已停用，原有 furniture_colors 整件换色仍可使用。
