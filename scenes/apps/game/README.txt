游玩与直播界面

game_player.tscn：游戏展示图轮播、游玩时间、成就挑战进度、直播状态和结束游玩操作。
脚本：scripts/life/game_player.gd，由 ComputerDesktop 的应用窗口挂载并接收共享 GameSession。

游玩、直播和攻略制作由 GameSession 统一计时。最小化游戏窗口或返回房间不会中断活动；结束游玩才结算本次记录。