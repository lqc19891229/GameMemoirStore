# Desktop Showcase v1：现代 3D 电脑桌区域样板间

## 目标

建立一个现代、温馨、整洁的轻写实 3D 电脑桌展示区。房间和桌搭是玩家最常观察的空间，电脑设备应是视觉重点。保持现有房间结构、相机、设备 ID、存档格式和布置系统稳定，按阶段替换程序化占位模型与旧资产。

美术方向以 docs/ART_STYLE_GUIDE.md 为准，模型制作要求以 docs/MODEL_QUALITY_STANDARD.md 为准。My Dream Setup 仅作为空间氛围和桌搭展示方向参考，不复制其具体模型或视觉资产。

## 当前样板间实现

| 部分 | 当前资源 | 当前职责 |
|---|---|---|
| 房间外壳 | scenes/room/modern_room_shell.tscn、scripts/room/modern_room_shell.gd | 暖白墙、浅橡木分板地面、真实窗洞、窗框、玻璃、窗帘、窗外背景、现代房门、踢脚线、墙面装饰和开放式天花收边 |
| 房间外观 | scripts/room/room_view.gd | 墙面、地板和空间灯光预设，墙体切换遮挡 |
| 桌子 | scenes/computer/hardware/modern_desk.tscn、scripts/life/modern_desk.gd | 木质桌板、桌板边缘、金属桌腿、横梁、理线槽和桌底灯光锚点 |
| 椅子 | scenes/room/chair.tscn、scripts/room/room_furniture.gd | 坐垫、靠背、扶手、气压杆、五星脚和脚轮的程序化占位模型 |
| 书架 | scenes/room/bookcase.tscn、scripts/room/room_furniture.gd | 木质侧板、背板、层板和书籍占位模型 |
| 落地灯 | scenes/room/lamp.tscn、scripts/room/room_furniture.gd | 金属底座和灯杆、陶瓷灯罩、扩散罩及辅助灯 |
| 地毯 | scenes/room/rug.tscn、scripts/room/room_furniture.gd | 织物底面、包边和简化图案 |
| 绿植 | scenes/room/plant.tscn、scripts/room/room_furniture.gd | 花盆、盆沿、土壤和叶片占位模型 |

当前房间、桌子和五类家具模型由 Godot 场景脚本生成，用于先验证房间结构、镜头、比例、碰撞、布置和灯光。它们不是最终精细化资产；通过真实游戏画面验收后，再按模型规范制作正式 GLB。

## 第一批电脑设备资产

电脑设备仍使用独立 GLB 模型和设备场景，保留购买、安装、卸载与存档接口。

| 资产 | 当前资源 | 视觉重点 | 兼容边界 |
|---|---|---|---|
| CRT 显示器 | assets/models/hardware/monitor_crt.glb | 厚实后壳、音箱孔、控制键、散热区、支架和底座 | 1.58 × 1.365 × 0.71 m；保留实时屏幕区域 |
| LCD 显示器 | assets/models/hardware/monitor_lcd.glb | 窄边框、摄像头、金属支架、背部散热和接口 | 1.60 × 1.35 × 0.44 m；保留实时屏幕区域 |
| 入门机箱 | assets/models/hardware/case_beige.glb | 复古光驱、前面板、接口、散热孔和脚垫 | 0.47 × 1.00 × 0.95 m |
| 进阶机箱 | assets/models/hardware/case_charcoal.glb | 侧透、内部主板、显卡、散热器、风扇和 RGB | 0.47 × 1.00 × 0.95 m |
| 入门键盘 | assets/models/hardware/keyboard_beige.glb | 独立键帽、功能区、键帽字符和状态灯 | 1.25 × 0.10 × 0.48 m |
| 进阶键盘 | assets/models/hardware/keyboard_charcoal.glb | 深色键帽、RGB 底光、独立旋钮和细节分区 | 1.25 × 0.10 × 0.48 m |
| 入门鼠标 | assets/models/hardware/mouse_beige.glb | 人体工学外壳、滚轮、侧键、传感器和脚贴 | 0.19 × 0.13 × 0.31 m |
| 进阶鼠标 | assets/models/hardware/mouse_charcoal.glb | 曲面外壳、RGB 装饰、DPI 键和侧键 | 0.19 × 0.13 × 0.31 m |

桌子和椅子的旧 GLB 资源目前保留在 assets/models/hardware/desk.glb 和 assets/models/room/chair.glb 等历史路径中，但当前现代样板间使用上表的场景脚本模型，不应把旧文件误认为当前运行时模型。

## 视觉关系

- 墙面采用暖白、米白或淡灰绿；地板以浅橡木和自然木色为主。
- 桌面与家具以暖木色、石墨灰、低饱和布艺色和哑光金属为基础。
- 入门设备保留复古米色识别度；进阶设备使用石墨灰、银色和少量青蓝 / 洋红 RGB。
- RGB 只强调风扇、键盘底光、鼠标装饰、显示器背光和桌底灯带，不把整个模型做成发光物。
- CRT 与 LCD 的轮廓差异必须明显。
- 电竞椅应表现布料、塑料和金属底座的材质区别，避免塑料方块感。
- 房间自然光、空间灯光和设备 RGB 独立控制。

## 灯光与 RGB

- 房间空间预设控制主光、补光、天花辅助光和落地灯，当前提供午后暖光、清晨冷光和夜间暖光三种方案。
- RGB 颜色、亮度和灯效通过房间布置面板调整，并随房间外观一起保存、撤销和重做。
- RGB 支持七种颜色、0–100% 亮度、常亮 / 呼吸 / 彩虹循环。
- RGB 发光材质与实际照明分开控制；辅助 OmniLight3D 仅用于少量局部照明。
- 入门设备不会错误显示进阶设备的 RGB 灯光；机箱、键盘和鼠标升级后才启用对应灯光。
- 六个机箱风扇转子由运行时灯光控制器驱动。

## 不改动的接口

- starter_pc、workstation、starter_monitor、lcd_monitor、starter_mouse、precise_mouse 等 ID 不变。
- 保持 data/hardware/*.tres 的资源路径、屏幕尺寸和屏幕位置。
- 保持 scenes/computer/hardware/*.tscn 的节点结构、角色和拾取逻辑。
- 保持 scenes/room/*.tscn 的家具 role、bounds 和 PickArea 接口。
- 保持 workstation_layout_data.gd 与玩家存档格式不变。
- 不改房间尺寸、桌面尺寸、设备默认位置和玩家存档迁移逻辑。
- 继续使用 Godot Compatibility 渲染器；不把升级 Forward+ 作为美术替换前提。

## 后续精细化顺序

1. 房间壳体、窗户、窗帘和墙面装饰的正式模型。
2. 桌子和椅子的正式模型。
3. 显示器与机箱的细节、材质和近景质量。
4. 键盘和鼠标的独立零件、材质分区和 RGB 区域。
5. 书架、落地灯、地毯和绿植。
6. 墙面挂画、壁架、书籍、手办、耳机架和桌面摆件。
7. 房型、墙面材质和地板材质扩展。

每个资产先在总览和近景镜头验收，再加入可购买或可布置目录。程序化占位模型不应未经检查直接升级为正式收藏资产。

## 验收步骤

1. Blender 中检查主体比例、结构、倒角、材质、法线和 bounds。
2. 导出 GLB，确认贴图嵌入且无外部依赖。
3. 检查 Godot 4.6 Compatibility 渲染器中的透明度、反射和发光。
4. 在房间总览、桌面近景、设备特写和三种空间灯光下检查。
5. 运行资源审计、工作台视图、布局、碰撞、灯光和房间存档测试。
6. 确认移动、旋转、吸附、复制、删除、撤销、重做和取消编辑正常。
7. 确认旧存档能正常加载、保存和恢复。
8. 通过实际游戏画面验收后，再将同一品质标准扩展到其他家具。
