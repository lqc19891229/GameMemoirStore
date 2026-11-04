核心运行脚本

client.gd / client_pages.gd / client_ui.gd：游戏平台导航、页面、图片与窗口交互。
store_state.gd：共享玩家状态、交易、时间推进和旧存档校验。
game.gd / game_catalog.gd：游戏 Resource 字段与正式目录。
items/：统一商品目录、库存 UID、家具分类及外观数据。
life/：电脑桌面、活动时钟、玩家成长、设备操作、房间编辑、家具布置和界面，详见 life/README.txt。
room/：房间蓝图与尺寸、自由地板及墙体材质、内外墙壁挂、3D 房间显示和碰撞。没有用途命名的功能分区或区域自动灯光。

主要接口：
- scripts/room/room_blueprint_data.gd：矩形、L 型及自由网格户型；将旧功能区地板颜色迁移为直接绘制材质。
- scripts/life/workstation_layout.gd：家具与墙面挂载、碰撞、撤销/重做及存档。
- scripts/room/room_wall_mount_data.gd：挂画、壁灯位置、亮度、开关与色温数据。

*.gd.uid 是 Godot 的稳定脚本标识，移动/重命名脚本时应一并保留。
