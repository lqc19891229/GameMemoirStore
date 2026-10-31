生活系统脚本

game_root.gd：注入共享会话，连接游玩请求与屏幕通知。
game_session.gd：统一活动时钟、购物、设备安装、游玩、直播和攻略。
life_data.gd：商品与平衡数值、六项能力、通用成就、默认数据和存档校验。
computer_desktop.gd：切换 3D 总览、布置与屏幕操作、转发键鼠和弹窗输入、更新设备型号，管理应用窗口和任务栏。
workstation_3d.gd：3D 相机、总览旋转缩放、视角保留与重置、设备拾取及屏幕 UV 映射。
desktop_device_3d.gd：切换已保存模型、校准拾取范围与 3D 屏幕。
device_model.gd / hardware_catalog.gd：3D 模型资源与库存物品映射。
app_window.gd：窗口标题栏、拖动、铺满、最小化和关闭信号。
browser.gd：购物与库存界面；game_player.gd：轮播画面和进度显示。
*.gd.uid：Godot 脚本稳定标识，移动脚本时一同保留。

房间表现层已删除；life_data 仍校验和保留历史家具与展示存档，避免丢失已购记录。

workstation_layout.gd：玩家布置的草稿/确认布局、物品选择、拖动与旋转扫掠阻挡、吸附、桌沿约束及旧布局重叠恢复。
workstation_layout_data.gd：布置存档字段校验与凸多边形占地碰撞。
