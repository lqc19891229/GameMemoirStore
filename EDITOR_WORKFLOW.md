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

## 可更换设备工作台

`computer_desktop.tscn` 顶层只有 Background、Equipment、Interface 三组。Background 是空桌面和墙面；Equipment 下有 Monitor、Computer、Keyboard、Mouse 四个独立实例，每个设备由一张整图表现。位置和尺寸通过各实例锚点调整，刷新库存不会重置摆放。

Monitor 内的 MonitorScreen 保留同一个实时桌面视口。默认展示全部设备，点击屏幕或“使用电脑”平滑放大；Esc /“查看设备”返回展示。弹窗存在时 Esc 优先关闭弹窗。切换只调整展示变换，不销毁应用、下载和游玩会话。右上“管理设备”进入放大屏幕中的物品栏。

外观资源在 `data/hardware/*.tres`：Texture 是完整素材（键盘用 AtlasTexture 选取有效区域），Screen Rect 是屏幕内框相对素材的归一化坐标。`_catalog.tres` 将库存物品 ID 对应到显示器、机箱、键盘、鼠标外观；精准键鼠套装使用两张独立贴图。新增型号时先添加外观资源，再配置商品与目录。详细步骤见 `data/hardware/README.md`。

`desktop_device.gd` 的 @tool 只同步已保存的贴图与屏幕区域，节点全部保存在场景中，编辑器可见。更换 Texture、Screen Rect 或设备尺寸时，屏幕区域会更新。

系统界面源场景仍为 `desktop_screen.tscn`。实时位置是 `Equipment/Monitor/MonitorScreen/ScreenViewport/DesktopViewport/DesktopScreen`。SubViewport 始终以 1280 × 800 渲染，容器匹配显示器屏幕尺寸；工作台放大不会沿用低分辨率缓存。设置、菜单等弹窗启用 gui_embed_subwindows，仍保留在屏幕内部。

九张独立 PNG 位于 `assets/art/life/hardware/`，使用内置 ImageGen 生成，完整提示词在同目录 `ASSET_PROMPTS.md`。原来包含全部设备的 workstation.png 已替换并移除。

输入检查：`godot --headless --path . --script res://tests/life/test_workstation_view.gd -- --fresh`，覆盖两种显示器、两种窗口尺寸、放大与返回、设备安装、屏幕点击、弹窗和存档。
