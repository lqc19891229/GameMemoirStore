房间与电脑场景

player_room.tscn：固定视角的像素房间与电脑、库存、展示柜入口。
computer_desktop.tscn：电脑桌面、任务栏与应用窗口管理。
app_window.tscn：可复用窗口壳，提供拖动、最小化、铺满和关闭。
browser.tscn：购物网页和物品库存。
game_player.tscn：游戏展示图轮播、游玩进度与直播操作。
furniture_item.tscn：可复用的电脑、桌子、外设、台灯和展示架交互物件。
achievement_cabinet.tscn：已获成就的展示 / 收起界面。

这些场景从 GameRoot 获取同一个 GameSession，不各自创建钱包或时钟。
