运行脚本目录

client.gd / client_pages.gd / client_ui.gd：游戏平台导航、页面数据绑定与 UI 辅助。
store_state.gd：共享玩家状态、交易和存档入口。
game.gd / game_catalog.gd：游戏 Resource 与查询。
life/：活动时钟、电脑桌面、应用窗口、库存、房间布置和交互。
room/：墙体、户型、房间表现、家具拾取和承载面。
items/：商品、库存、分类、家具整体换色等通用数据逻辑。

家具部件材质槽与共享 PBR 资源系统已移除；默认材质应写入 GLB。
整件家具颜色、工作台设备灯效和布置预览材质属于其他独立功能，不在此次移除范围。

移动或改名 GDScript 时保留相应 *.gd.uid 文件，避免场景资源引用失效。
参见 life/README.txt 和 ../CLIENT_STRUCTURE.md。
