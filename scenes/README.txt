场景目录（按运行职责划分）

main/game_root.tscn：游戏主入口，连接共享 GameSession 和 ComputerDesktop。
computer/：3D 工作台、设备模型场景、电脑内桌面和应用窗口。
room/：房间本体与家具独立场景；家具按 tables、seating、storage、lighting、decor 分类。
apps/platform/：游戏平台商城、游戏库、下载和其他页面。
apps/browser/：购物与库存应用。
apps/game/：游玩、挑战和直播界面。
shared/：共用 UI 场景。

家具场景通常引用 assets/models/room/ 下的 GLB，额外定义拾取和摆放配置；默认材质由 GLB 提供。
新增家具先通过 Furniture Manager 创建 .tscn 并审核，再注册到 data/items/_catalog.tres。
修改模型路径或场景路径时，必须同步检查商品目录和相关测试中的 res:// 引用。

参见 ../EDITOR_WORKFLOW.md、../addons/furniture_manager/README.md 和 ../CLIENT_STRUCTURE.md。
