场景入口

game_root.tscn：主入口，包含房间、桌面、展示柜和共享会话。
store.tscn：游戏平台，含顶栏、导航、状态栏及首页实例。
life/：生活界面与五种独立家具场景。
client/pages/：各平台页面，可直接在 2D 编辑器查看和编辑。
client/components/：列表行、卡片等可复用场景。
client/*_dialog.tscn：原生弹窗。

全部固定布局由场景节点保存，脚本绑定数据和交互。详见项目根目录 EDITOR_WORKFLOW.md。
