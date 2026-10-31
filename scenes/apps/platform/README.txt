游戏平台

store.tscn：客户端入口，可单独运行预览，也可由电脑桌面挂载。
pages/：首页、商品、搜索、游戏库、购物车、创作等完整页面。
components/：仅由游戏平台使用的列表行、卡片与评测组件。
dialogs/：设置、消息、重置、游玩弹窗和游戏库右键菜单。

脚本：scripts/client.gd、client_pages.gd、client_ui.gd。
游戏资料来自 data/games/_catalog.tres，购物网页库存组件不放在这里。
