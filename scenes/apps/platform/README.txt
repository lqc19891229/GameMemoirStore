游戏平台场景

store.tscn：客户端入口，可单独运行预览，也可由电脑桌面应用窗口挂载。
pages/：首页、商品、搜索、游戏库、下载、愿望单、购物车、个人资料和创作页面。
components/：游戏平台专用的列表行、卡片和评测组件。
dialogs/：设置、消息、重置、游玩弹窗和游戏库右键菜单。

脚本：scripts/client.gd、scripts/client_pages.gd、scripts/client_ui.gd。
游戏资料来自 data/games/_catalog.tres；补充展示信息来自 data/catalog.json。购物网页的库存组件属于 scenes/apps/browser/，不放在游戏平台目录。