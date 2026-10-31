场景目录按运行职责组织

main/：game_root.tscn 是主入口，组合唯一 GameSession 与 ComputerDesktop。
computer/：原生 3D 电脑工作台、设备模型场景、房间实例和电脑内系统界面。
room/：房间外壳、椅子、书架、落地灯、地毯和绿植独立场景。
apps/platform/：游戏平台 store.tscn、页面、专用列表组件和弹窗。
apps/browser/：购物网页 browser.tscn 与库存商品行组件。
apps/game/：游玩、成就和直播界面 game_player.tscn。
shared/：跨应用复用的通用按钮组件。

固定界面和模型由真实 .tscn 节点保存；运行时脚本负责数据绑定、交互和状态更新。不要为同一页面或房间模型复制旧路径场景。

编辑入口见根目录 EDITOR_WORKFLOW.md；房间布置规则见 docs/WORKSTATION_LAYOUT.md；项目结构见 CLIENT_STRUCTURE.md。