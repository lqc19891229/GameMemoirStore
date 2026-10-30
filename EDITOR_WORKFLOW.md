# 在 Godot 2D 编辑器中编辑界面

固定界面已保存在 `.tscn` 场景中，不需要运行项目或开启 `@tool` 才能看到。主入口 `scenes/game_root.tscn` 中直接放置房间、桌面、展示柜和共享会话；默认显示房间。

## 从哪里开始

| 想编辑的内容 | 打开的场景 |
|---|---|
| 整体入口和房间 / 桌面层级 | `scenes/game_root.tscn` |
| 房间、窗户、地板、海报、家具位置 | `scenes/life/player_room.tscn` |
| 桌子、电脑、外设、展示柜、台灯的外观 | `scenes/life/furniture/*.tscn` |
| 电脑桌面、快捷方式、任务栏 | `scenes/life/computer_desktop.tscn` |
| 应用标题栏、最小化 / 最大化 / 关闭按钮 | `scenes/life/app_window.tscn` |
| 商店顶栏、导航栏和状态栏 | `scenes/store.tscn` |
| 首页、商品、搜索、愿望单、购物车、库、下载、个人资料、创作页 | `scenes/client/pages/*.tscn` |
| 商品列表行、游戏卡片、库存、成就、攻略等重复组件 | `scenes/client/components/*.tscn` |
| 购物网页、游戏画面、成就陈列室 | `scenes/life/browser.tscn`、`game_player.tscn`、`achievement_cabinet.tscn` |
| 设置和单独运行平台时的弹窗 | `scenes/client/*_dialog.tscn` |

双击场景，在上方选择 **2D**。如果画面在视野外，选择场景树的可视节点，按 **F** 居中。主场景中桌面与成就陈列室默认隐藏；编辑它们时直接打开对应子场景。

实例节点可以双击进入源场景。需要在父场景内调整实例内部的节点时，右键该实例，启用 **可编辑子节点（Editable Children）**。重复组件请优先修改它们的源场景，所有列表实例会同步采用新布局。

## 布局与美术

- `PlayerRoom/RoomCanvas` 下的墙面、地板、窗框等都是 `ColorRect` 节点。家具是独立 `Button` 场景实例，内部同样有可选择的美术节点，没有 `_draw()` 绘图。
- 家具位置、大小通过锚点和偏移编辑。默认布置使用编辑器保存的位置；“换个布置”只叠加一个相对位移，不再每次刷新用硬编码坐标覆盖它们。
- 家具的 `Part*` 节点可修改颜色；带 `upgraded_color` 元数据的节点会在设备升级时切换到该颜色。麦克风与三个奖杯是已有的节点，脚本只切换可见性。正式贴图可加入相同家具场景内。
- UI 使用 `Container` 布局。容器内控件的位置由父容器计算，调整 `Custom Minimum Size`、`Size Flags`、容器间距或外边距；自由放置的房间家具可以直接移动和缩放。
- 按钮样式位于 `assets/client_theme.tres`，有 `NormalButton`、`BlueButton`、`GreenButton`、`FlatButton`、`DarkButton`、`DangerButton` 变体。布局脚本不再创建控件或覆盖这些静态样式。
- 不要随意删除或重命名带 `%` 唯一名称的节点；脚本通过这些名称绑定交互。可以编辑其外观、布局、文字样式并添加装饰节点。

## 数据和预览

页面中的示例图片、标题和列表行保存在场景内，供编辑时预览。运行时会用当前游戏、钱包、库存等数据填充；预览行会替换为 `components/` 中相同模板的实例，不会写回资源或存档。

脚本仍负责业务数据、交易、信号连接、窗口开关、页面切换和列表数量。**运行时会实例化已有场景**（例如不同数量的游戏卡片、打开应用窗口），但不会用 `Button.new()`、`Label.new()` 或绘图代码拼装界面。静态页面在刷新时复用，编辑器设置的布局会保留。

游戏资料和图片仍由 `data/games/*.tres` 提供，Excel 导入方式不变。场景里的占位文字不是正式商品资料。

## 检查

`godot --headless --path . --script res://tests/test_editor_scenes.gd -- --fresh`

检查场景在 `_ready()` 之前就有节点，并验证家具位置、客户端布局和首页实例在运行 / 刷新后保持。原有客户端、资源接入、生活流程及原生窗口检查继续覆盖运行行为。
