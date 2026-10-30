# 在 Godot 2D 编辑器中编辑界面

固定界面已保存在 `.tscn` 场景中，不需要运行项目或开启 `@tool` 才能看到。主入口 `scenes/game_root.tscn` 中只放置电脑桌面和共享会话；默认显示电脑桌面。

## 从哪里开始

| 想编辑的内容 | 打开的场景 |
|---|---|
| 整体入口和桌面层级 | `scenes/game_root.tscn` |
| 显示器、主机、键盘、鼠标的电脑近景 | `scenes/life/computer_desktop.tscn` |
| 显示器内部的桌面、快捷方式、任务栏 | `scenes/life/desktop_screen.tscn` |
| 应用标题栏、最小化 / 最大化 / 关闭按钮 | `scenes/life/app_window.tscn` |
| 商店顶栏、导航栏和状态栏 | `scenes/store.tscn` |
| 首页、商品、搜索、愿望单、购物车、库、下载、个人资料、创作页 | `scenes/client/pages/*.tscn` |
| 商品列表行、游戏卡片、库存、成就、攻略等重复组件 | `scenes/client/components/*.tscn` |
| 购物网页、游戏画面 | `scenes/life/browser.tscn`、`game_player.tscn` |
| 设置和单独运行平台时的弹窗 | `scenes/client/*_dialog.tscn` |

双击场景，在上方选择 **2D**。如果画面在视野外，选择场景树的可视节点，按 **F** 居中。主场景中电脑桌面默认可见；编辑屏幕内的系统界面时，直接打开 `desktop_screen.tscn`。

实例节点可以双击进入源场景。需要在父场景内调整实例内部的节点时，右键该实例，启用 **可编辑子节点（Editable Children）**。重复组件请优先修改它们的源场景，所有列表实例会同步采用新布局。

## 布局与美术

- UI 使用 `Container` 布局。容器内控件的位置由父容器计算，调整 `Custom Minimum Size`、`Size Flags`、容器间距或外边距。
- 按钮样式位于 `assets/client_theme.tres`，有 `NormalButton`、`BlueButton`、`GreenButton`、`FlatButton`、`DarkButton`、`DangerButton` 变体。布局脚本不再创建控件或覆盖这些静态样式。
- 不要随意删除或重命名带 `%` 唯一名称的节点；脚本通过这些名称绑定交互。可以编辑其外观、布局、文字样式并添加装饰节点。

## 数据和预览

页面中的示例图片、标题和列表行保存在场景内，供编辑时预览。运行时会用当前游戏、钱包、库存等数据填充；预览行会替换为 `components/` 中相同模板的实例，不会写回资源或存档。

脚本仍负责业务数据、交易、信号连接、窗口开关、页面切换和列表数量。**运行时会实例化已有场景**（例如不同数量的游戏卡片、打开应用窗口），但不会用 `Button.new()`、`Label.new()` 或绘图代码拼装界面。静态页面在刷新时复用，编辑器设置的布局会保留。

游戏资料和图片仍由 `data/games/*.tres` 提供，Excel 导入方式不变。场景里的占位文字不是正式商品资料。

## 检查

`godot --headless --path . --script res://tests/test_editor_scenes.gd -- --fresh`

检查场景在 `_ready()` 之前就有节点，并验证电脑默认可见、客户端布局和首页实例在运行 / 刷新后保持。原有客户端、资源接入、生活流程及原生窗口检查继续覆盖运行行为。

## 电脑近景

- `computer_desktop.tscn` 的 `WorkstationArt` 用一张完整的 `workstation.png` 表现显示器、主机、桌面、键盘和鼠标；场景根节点只有 `WorkstationArt` 和 `MonitorScreen` 两个直接子节点。选中 `MonitorScreen` 调整实际屏幕位置与尺寸，更换背景图时让它对齐新图的屏幕内框。
- `MonitorScreen/ScreenViewport/DesktopViewport/DesktopScreen` 是真正的电脑系统界面，源场景为 `desktop_screen.tscn`；应用、快捷方式、任务栏和通知均在里面。要编辑系统界面，直接打开这个源场景。
- `SubViewportContainer` 自动传递屏幕内的鼠标与键盘输入。逻辑分辨率固定为 1280 × 800，由 `size_2d_override` 和 `size_2d_override_stretch` 适配实际屏幕；缩放时不要手动修改容器的 `scale`。
- 设置、菜单等弹窗启用 `gui_embed_subwindows`，保留在显示器屏幕内。物理主机、键盘和鼠标是装饰，点击这些区域不会打开应用。
- 游戏直接进入电脑近景。在屏幕中点击图标、任务栏和窗口操作应用；任务栏已移除房间按钮，Esc 不再切换到其他场景。最小化应用不会停止游玩或下载。
- 新增检查：`godot --headless --path . --script res://tests/life/test_workstation_view.gd -- --fresh`，覆盖两种尺寸下的屏幕点击、外壳点击、应用与任务栏操作以及内嵌设置弹窗。

## 当前电脑素材

`assets/art/life/workstation.png` 是完整电脑近景背景。生成提示词与方式记录在同目录 `ASSET_PROMPTS.md`。房间和家具专用场景、脚本及贴图已移除。

显示器点击使用容器本地事件坐标；测试以 viewport 本地坐标注入输入，支持无界面环境。
