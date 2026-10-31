电脑与应用场景

computer_desktop.tscn：默认展示四件独立设备，点击屏幕放大，Esc 返回；管理设备可进入库存。
desktop_device.tscn：完整设备贴图与点击区域的通用模板，显示器额外嵌入实时屏幕。
desktop_screen.tscn：显示器内部的桌面、快捷方式、任务栏和通知。
app_window.tscn：可复用窗口壳，提供拖动、最小化、铺满和关闭。
browser.tscn：购物网页和物品库存。
game_player.tscn：游戏展示图轮播、游玩进度与直播操作。

房间、家具及展示柜场景已移除。这些应用从 GameRoot 获取同一个 GameSession，不各自创建钱包或时钟。
