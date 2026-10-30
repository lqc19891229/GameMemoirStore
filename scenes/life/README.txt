电脑与应用场景

computer_desktop.tscn：主入口默认显示的电脑近景，保留工作台贴图和实时屏幕。
desktop_screen.tscn：显示器内部的桌面、快捷方式、任务栏和通知。
app_window.tscn：可复用窗口壳，提供拖动、最小化、铺满和关闭。
browser.tscn：购物网页和物品库存。
game_player.tscn：游戏展示图轮播、游玩进度与直播操作。

房间、家具及展示柜场景已移除。这些应用从 GameRoot 获取同一个 GameSession，不各自创建钱包或时钟。
