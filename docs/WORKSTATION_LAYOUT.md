# 现代房间与工作台布置

ComputerDesktop 是主 3D 场景入口，Workstation3D 负责房间、工作台、镜头和摆放。点击顶栏“布置房间”进入编辑；点击物品或列表选择。布置模式下，显示器只被选中，不转发电脑输入。

## 视觉方向

当前房间样板间采用现代轻写实 3D 风格：暖白墙面、浅橡木地板、窗户与亚麻窗帘、现代平板房门、低饱和墙面装饰，以及哑光金属和织物材质。房间保持 8 × 6 米的两面墙展示结构，正面和右侧开放，方便观察和编辑。

房间壳体由 scenes/room/modern_room_shell.tscn 和 scripts/room/modern_room_shell.gd 生成；家具视觉模型由 scripts/room/room_furniture.gd 创建；桌子由 scenes/computer/hardware/modern_desk.tscn 创建。当前样板间不再引用旧的像素风房间 GLB。

## 操作

| 操作 | 行为 |
|---|---|
| 移动 G | 拖动物品、黄色平面手柄或红蓝轴手柄；碰到家具、桌沿、房间边界时停止 |
| 旋转 R | 拖动圆形手柄，或 Q / E 每步旋转 15°；检查旋转经过的完整区域 |
| 吸附 | 默认 5 cm / 15°，可关闭；接触位置优先于吸附 |
| 右键 / 滚轮 | 环绕 / 缩放；不会改变布置 |
| Ctrl + D / 复制家具 | 椅子、书架、灯、地毯、绿植每类最多 8 个副本，自动寻找附近空位 |
| Delete / 删除副本 | 删除选中副本；初始物件保留 |
| Ctrl + Z / Ctrl + Shift + Z 或 Ctrl + Y | 撤销 / 重做移动、旋转、复制、删除、外观和恢复默认；保存最近 80 次操作 |
| 墙面 / 地板 / 空间灯光 | 各三套预设；对副本灯具同样生效 |
| RGB 颜色 / 亮度 / 灯效 | 7 种颜色、0–100% 亮度、常亮 / 呼吸 / 彩虹循环；亮度为 0 时关闭 RGB 发光与辅助灯 |
| 应用布置 | 确认有效草稿并写入共享存档 |
| 取消 / Esc | 丢弃草稿，恢复上次确认的家具、复制物件、外观 |
| 恢复默认布置 | 使用编辑器保存的初始布置与默认外观，仍需应用才保存 |

一个鼠标拖动手势是一条撤销记录。取消编辑、后台保存或编辑中退出都不保存未确认的草稿。

## 房间结构与墙体遮挡

房间固定 8 × 6 米，墙高 3.2 米。左墙包含真实窗洞、窗框、玻璃、窗帘和窗外柔和建筑背景；后墙包含现代房门、门框和抽象装饰画。开放式天花收边保留室内完成度，同时不遮挡斜俯视镜头。

观察到墙外侧时，Left_Wall 或 Back_Wall 整组隐藏，窗户、门、踢脚线和墙面装饰随组一起隐藏；回到室内视角时自动恢复。

房间底板使用浅木色分板表现，墙面、地板和空间灯光各有三套外观预设。更改房间几何后，应同步检查相机遮挡、家具放置边界和墙体切换阈值。

## 放置与碰撞

桌子、椅子、书架、灯和绿植使用地面坐标及凸占地约束。地毯使用相同房间边界，但允许与家具占地重合。设备使用相对桌面的坐标，始终放在桌面上，不能拖到地面；桌子移动和旋转时一起跟随。默认桌面 4.8 × 2.3 米，高 0.78 米。

所有实心物件同层互相阻挡。移动检查起止占地的凸包扫掠；旋转拆成不超过 1° 的区间，二分寻找最后安全位置。接触时框变橙色并提示对象。默认每边外扩 1 cm，含约 2 mm 接触容差。这是摆放约束，不是刚体推挤模拟，椅子不能穿入桌子占地，物件不会掉落。

LayoutEditor 检查器可调整 room_half_size、tabletop_half_size、tabletop_height、edge_margin、grid_step、angle_step、collision_margin。改变场景几何后应同步调整尺寸；设备 appearance.bounds 和家具 bounds 必须覆盖全部可见几何。家具默认仅支持水平移动及绕 Y 轴旋转，不支持玩家缩放。

## 房间外观与 RGB 灯光

墙面、地板各有三套配色，空间灯光提供午后暖阳、清晨冷光和夜间暖灯三种预设。空间预设分别控制主光、补光、天花辅助光与落地灯，不改变设备 RGB 设置。

RGB 设置独立于空间灯光：
- **颜色**：冰青、深蓝、紫罗兰、洋红、琥珀、薄荷、玫瑰。
- **亮度**：0–100%；0 会关闭 RGB 发光材质与对应辅助 OmniLight3D。
- **灯效**：常亮、呼吸、彩虹循环。
- **覆盖范围**：桌底灯带、显示器背光，以及已安装进阶型号的机箱、键盘和鼠标灯光。入门型号不会错误显示进阶设备的 RGB 辅助灯。
- **动态部件**：进阶机箱的六枚风扇转子由运行时灯光控制器驱动。

发光材质与实际照明分开控制。RGB 材质使用运行时副本，不会改写导入的 GLB 资源。相关逻辑见 scripts/life/workstation_lighting.gd，预设和材质约定见 docs/WORKSTATION_LIGHTING.md。

## 场景与素材组织

| 目录 / 文件 | 职责 |
|---|---|
| scenes/computer/computer_desktop.tscn | 模式入口、清晰 HUD、桌面系统纹理与应用窗口 |
| scenes/computer/workstation_3d.tscn | 主视口 3D 世界、房间、工作台、设备、环境、灯光、相机和摆放工具 |
| scenes/room/room.tscn | 房间外壳与五件初始家具实例 |
| scenes/room/modern_room_shell.tscn | 现代房间壳体场景 |
| scenes/room/{chair,bookcase,lamp,rug,plant}.tscn | 家具场景、碰撞尺寸与拾取区域 |
| scripts/room/modern_room_shell.gd | 房间墙体、窗户、窗帘、门、地板和墙面装饰 |
| scripts/room/room_view.gd | 外观预设、空间灯光、墙体遮挡 |
| scripts/room/room_furniture.gd | 现代家具视觉模型与拾取尺寸 |
| scripts/life/modern_desk.gd | 现代木质桌面与金属桌架 |
| scripts/life/workstation_lighting.gd | RGB 发光材质、辅助灯、风扇转子与灯效 |
| scripts/life/workstation_layout.gd | 草稿、碰撞、复制、撤销、确认与取消 |
| scripts/life/workstation_layout_data.gd | 存档白名单、有限数值检查及凸多边形重叠判定 |

电脑设备仍使用 assets/models/hardware/ 中的 GLB。旧的 assets/models/room/ 与 tools/models/build_room.py 暂时保留作历史资产和后续重制参考，当前样板间不再引用它们。

## 保存与兼容

继续使用版本 3 存档。life.workstation_layout 保存原来的五个工作台角色、五类房间家具，以及 plant_1 这类副本的 {x,z,yaw}。副本编号仅接受 1–8，不允许复制设备。初始物件相对其原有父节点；副本相对 Room/Furniture。高度与缩放由场景提供。

life.room_style 保存六项外观设置：wall、floor、light（各为 0–2）、rgb（0–6）、brightness（0–100）和 effect（0–2）。旧存档缺少 RGB 字段时使用默认值，不需要迁移或重置。

## 验证

样板间和房间编辑回归：

    godot --headless --path . --script res://tests/life/test_modern_room.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_layout.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_collision.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_lighting.gd -- --fresh
    godot --headless --path . --script res://tests/life/test_workstation_view.gd -- --fresh

当前仍使用 Godot Compatibility 渲染器。此阶段不切换 Forward+，也不修改存档结构。新的材质、墙体结构和家具模型必须先通过 Godot 资源导入、房间回归和图形测试，再作为后续家具制作的视觉基准。
