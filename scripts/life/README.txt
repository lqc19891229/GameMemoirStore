生活系统脚本

game_root.gd：注入共享会话，连接游玩请求与屏幕通知。
game_session.gd：统一活动时钟、购物、设备安装、游玩、直播和攻略。
life_data.gd：商品与平衡数值、六项能力、通用成就、默认数据和存档校验。
computer_desktop.gd：创建、复用、隐藏和关闭应用窗口，更新任务栏。
monitor_screen.gd：将屏幕区域内的输入传递给桌面视口。
app_window.gd：窗口标题栏、拖动、铺满、最小化和关闭信号。
browser.gd：购物与库存界面；game_player.gd：轮播画面和进度显示。
*.gd.uid：Godot 脚本稳定标识，移动脚本时一同保留。

房间表现层已删除；life_data 仍校验和保留历史家具与展示存档，避免丢失已购记录。
