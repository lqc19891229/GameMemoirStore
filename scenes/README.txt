场景目录按运行职责组织

main/game_root.tscn：游戏入口，组合 GameSession 与 ComputerDesktop。
computer/：3D 电脑工作台、硬件槽位、房间实例、HUD 和电脑内部桌面。
room/：外壳、家具、装饰品与壁灯等独立 3D 场景；购买、摆放、收纳时使用真实场景实例。
apps/platform/：游戏平台页面、列表组件和弹窗。
apps/browser/：商品购物网页及库存商品行。
apps/game/：游玩、成就、直播界面。
shared/：跨界面共用的组件。

房间场景不包含“工作区／游戏区／休息区”逻辑。实体墙体、门窗、自由地板和家具在 3D 中自由布置；独立壁灯挂载后才发光，支持开关、亮度与色温。
固定节点存于 *.tscn，运行时脚本处理数据、操作与存档。
房间说明：docs/ROOM_SCENE_FIRST_UI.md、docs/WORKSTATION_LAYOUT.md；总体结构见根目录 README.md。
