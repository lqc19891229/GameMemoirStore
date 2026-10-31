# 游戏回忆录 v0.5 · 场景与运行机制

## 主场景与共享数据

scenes/main/game_root.tscn 是唯一主入口。GameRoot 只持有 GameSession 和 ComputerDesktop；启动后直接显示像素 3D 房间与电脑工作台。

GameSession 持有唯一 MemoirStoreState 实例。游戏平台、购物网页和游玩界面通过 ComputerDesktop 注入的 session/state 访问同一份玩家数据。钱包、收藏、安装设备、生活属性、房间布局和活动进度不会因为切换窗口而创建副本。

    GameRoot
    ├── GameSession
    │   └── SimulationTimer
    └── ComputerDesktop
        ├── Workstation3D
        │   ├── Room
        │   │   ├── Shell
        │   │   └── Furniture
        │   ├── TableGroup
        │   │   └── Equipment
        │   ├── LayoutEditor
        │   ├── Camera / Lights
        │   └── PixelPass
        ├── DesktopViewport / DesktopScreen
        └── HUD / Interface

## 场景与脚本职责

| 场景或目录 | 主要职责 |
|---|---|
| scenes/main/game_root.tscn | 主入口，注入共享会话并连接游玩请求 |
| scenes/computer/computer_desktop.tscn | Node3D 电脑桌面宿主，管理 3D 总览、布置、屏幕操作和应用窗口 |
| scenes/computer/workstation_3d.tscn | 房间、工作台、相机、灯光、摆放工具和像素滤镜的复用源场景 |
| scenes/room/ | 房间外壳与五类家具场景 |
| scenes/computer/hardware/ | 显示器、机箱、键盘、鼠标设备槽位 |
| scenes/computer/ui/ | 显示器系统、应用窗口壳和布置手柄 |
| scenes/apps/platform/ | 游戏平台页面、组件、弹窗和右键菜单 |
| scenes/apps/browser/ | 购物网页与库存商品行 |
| scenes/apps/game/ | 游玩画面、成就和直播操作 |
| scenes/shared/ | 跨应用共用组件 |
| scripts/life/ | GameSession、桌面、窗口、活动、设备和工作台布置逻辑 |
| scripts/room/ | 房间外观、灯光、墙体遮挡和家具拾取 |

ComputerDesktop 是原生 Node3D 场景，Workstation3D 直接渲染到主视口，HUD 单独放在 CanvasLayer。DesktopViewport 只负责显示器内的 1280 × 800 系统纹理，不承载 3D 房间。

## 输入、相机与窗口

总览中左键或右键拖动可环绕工作台并调整俯仰，滚轮缩放。短距离单击用于拾取设备或点击显示器；拖动超过阈值后不会误触屏幕。返回房间时保留总览相机，重置视角恢复编辑器保存的默认相机。

屏幕输入通过相机射线与显示器表面相交，映射到实时纹理 UV，再转发给 DesktopViewport。显示器背面不接受屏幕输入。布置模式与屏幕操作互斥；在布置模式中点击显示器只会选中设备。

应用窗口使用 app_window.tscn。最小化会隐藏窗口并保留实例；关闭游戏平台不会停止游戏或直播；关闭游玩窗口或点击结束游玩才结束当前游玩活动。

## 房间与工作台布置

Room/Shell 保存房间外壳，Room/Furniture 保存五件初始家具。Room 负责墙面、地板和灯光预设，以及根据观察方向隐藏挡住视线的墙体。家具 GLB 和拾取区域保存在 scenes/room/。

TableGroup 承载桌子与 Equipment。设备使用桌面相对坐标，始终留在桌面；移动或旋转桌子时设备一起跟随。椅子、书架、灯、地毯和绿植使用房间地面坐标，支持有限数量复制。地毯允许与其他家具占地重合。

LayoutEditor 管理草稿、选择、移动、旋转、吸附、复制、删除、撤销、重做、应用和取消。移动检查扫掠占地，旋转检查中间路径，阻止快速拖动穿过物件。接触时显示阻挡对象；这属于放置约束，不是刚体推挤模拟。

PixelPass 将房间画面进行最近邻采样和颜色量化。进入显示器操作时关闭房间滤镜，避免影响电脑系统文字；HUD 始终保持清晰。

详细操作、尺寸和碰撞规则见 docs/WORKSTATION_LAYOUT.md。

## 活动、属性与收入

GameSession 的 1 秒 Timer 推进 1 分钟模拟活动，并统一处理下载、游玩、直播、攻略制作和阅读收益。life.active 同时只允许一项主要活动：play 或 guide。直播是 play 的附加状态；攻略制作与游玩互斥。

当前代码实现六项能力：反应、操作、思考、探索、规划、协作。游戏 genres 决定能力权重，多人 / 合作标签增加协作占比。游玩提升相关能力，能力与已安装主机、外设共同影响挑战进度倍率。

每款游戏初版共用 10、60、180 点挑战里程碑。直播每 5 分钟结算一次收入；攻略至少需要 10 分钟游玩时间，制作 20 分钟，每款游戏只能发布一次，后续阅读收益最多 60 次。

## 游戏目录与存档

游戏基础资料由 tools/catalog/game_catalog.xlsx 生成 data/games/*.tres 和 _catalog.tres。scripts/game.gd 定义单款游戏 Resource，scripts/game_catalog.gd 提供目录查询。封面和四张展示图由导入器根据 game_id 自动生成引用。

玩家存档位于 user://memoir_store_v01.json，当前格式版本 3，兼容读取版本 1、2。存档包含钱包、游戏所有权、安装、游玩记录和 life 数据。life 数据包括物品、装备、六项能力、挑战进度、成就、展示内容、攻略、活动、收入、workstation_layout 和 room_style。

历史家具库存和旧版字段仍由 life_data.gd 清理与保留；不得仅因当前房间系统调整而删除这些兼容代码。保存采用临时文件后替换的方式，--fresh 用于测试时禁用正常存档读写。

## 验证

Python 导入器、Godot Headless 测试和图形环境窗口测试由 tests/ 与 GitHub Actions 管理。测试目录说明和命令见 tests/README.txt、tests/life/README.txt 及根目录 README.md。