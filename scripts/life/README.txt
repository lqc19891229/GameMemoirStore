生活系统与工作台脚本

game_root.gd：注入共享 GameSession，连接游玩请求与屏幕通知。
game_session.gd：唯一活动时钟，推进下载、游玩、直播、攻略和阅读收益。
life_data.gd：商品、六项能力、游戏类型权重、通用成就、默认生活数据和存档校验。
computer_desktop.gd：切换 3D 总览、布置和屏幕操作；转发输入，更新设备型号，管理应用窗口与任务栏。
workstation_3d.gd：3D 相机、总览旋转缩放、视角保留、设备拾取和屏幕 UV 映射。
workstation_lighting.gd：RGB 发光材质副本、辅助 OmniLight3D、呼吸 / 彩虹灯效与六枚机箱风扇转子。
desktop_device_3d.gd：切换已保存模型、校准拾取范围和 3D 屏幕。
device_model.gd / hardware_catalog.gd：设备模型资源和库存物品映射。
app_window.gd：应用窗口标题栏、拖动、铺满、最小化和关闭。
browser.gd / game_player.gd：购物库存界面、游戏轮播和活动进度。
workstation_layout.gd：房间和桌面布置草稿、选择、移动、旋转、扫掠碰撞、吸附、复制、删除、撤销、应用和取消。
workstation_layout_data.gd：布局存档白名单、数值清理、凸多边形占地重叠判定。
scripts/room/：房间表现层脚本 pixel_room.gd 和 room_furniture.gd，负责墙地配色、空间灯光预设、墙体遮挡与家具拾取。

历史家具库存、旧版 room_layout 和版本 3 的 workstation_layout / room_style 字段继续保留在存档清理逻辑中，不能因为当前布置系统改动而删除。

*.gd.uid 是 Godot 脚本稳定标识，移动脚本时一同保留。
