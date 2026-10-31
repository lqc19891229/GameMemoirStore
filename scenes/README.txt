按功能整理的场景目录

main/：主入口 game_root.tscn，组合电脑工作台与共享会话。
computer/：原生 3D 电脑工作台、设备模型场景与电脑内的系统界面。
apps/platform/：游戏平台 store.tscn；pages/ 页面、components/ 专用列表、dialogs/ 弹窗。
apps/browser/：购物网页 browser.tscn 与库存列表组件。
apps/game/：游玩与直播界面 game_player.tscn。
shared/：跨应用复用的 text_button.tscn。

固定布局由真实场景节点保存。主入口已在 project.godot 中更新；不保留旧路径副本。
编辑入口与操作说明见项目根目录 EDITOR_WORKFLOW.md，检查结果见 docs/PROJECT_AUDIT.md。
