# 像素房间与工作台布置

ComputerDesktop 是主 3D 场景，Workstation3D 负责房间、工作台、镜头和摆放。点击顶栏“布置房间”进入编辑；点击物品或列表选择。布置模式下，显示器只被选中，不转发电脑输入。

| 操作 | 行为 |
|---|---|
| 移动 G | 拖动物品、黄色平面手柄或红蓝轴手柄；碰到家具、桌沿、房间边界时停止 |
| 旋转 R | 拖动圆形手柄，或 Q / E 每步旋转 15°；检查旋转经过的完整区域 |
| 吸附 | 默认 5 cm / 15°，可关闭；接触位置优先于吸附 |
| 右键 / 滚轮 | 环绕 / 缩放；不会改变布置 |
| Ctrl + D / 复制家具 | 椅子、书架、灯、地毯、绿植每类最多 8 个副本，自动寻找附近空位 |
| Delete / 删除副本 | 删除选中副本；初始物件保留 |
| Ctrl + Z / Ctrl + Shift + Z 或 Ctrl + Y | 撤销 / 重做移动、旋转、复制、删除、外观和恢复默认；保存最近 80 次操作 |
| 墙面 / 地板 / 灯光 | 各三套预设；对副本灯具同样生效 |
| RGB 颜色 / 亮度 / 灯效 | 7 种颜色、0–100% 亮度、常亮 / 呼吸 / 彩虹循环；亮度为 0 时关闭 RGB 发光与辅助灯 |
| 应用布置 | 确认有效草稿并写入共享存档 |
| 取消 / Esc | 丢弃草稿，恢复上次确认的家具、复制物件、外观 |
| 恢复默认布置 | 使用编辑器保存的初始布置与默认外观，仍需应用才保存 |

一个鼠标拖动手势是一条撤销记录。取消编辑、后台保存或编辑中退出都不保存未确认的草稿。

## 放置与碰撞

房间固定 8 × 6 米，左墙与后墙高 3.2 米；房型绘制、门窗移动、挂画编辑留待后续。默认摄像机为斜俯视，观察到墙外侧时隐藏对应墙、窗与装饰，回到室内方向自动恢复。

桌子、椅子、书架、灯和绿植使用地面坐标及凸占地约束。地毯使用相同房间边界，但允许与家具占地重合。设备使用相对桌面的坐标，始终放在桌面上，不能拖到地面；桌子移动和旋转时一起跟随。默认桌面 4.8 × 2.3 米，高 0.78 米。

所有实心物件同层互相阻挡。移动检查起止占地的凸包扫掠；旋转拆成不超过 1° 的区间，二分寻找最后安全位置。接触时框变橙色并提示对象。默认每边外扩 1 cm，含约 2 mm 接触容差。这是摆放约束，不是刚体推挤模拟，椅子不能穿入桌子占地，物件不会掉落。

`LayoutEditor` 检查器可调整 room_half_size、tabletop_half_size、tabletop_height、edge_margin、grid_step、angle_step、collision_margin。改变场景几何后应同步调整尺寸；设备 appearance.bounds 和家具 bounds 必须覆盖全部可见几何。家具默认仅支持水平移动及绕 Y 轴旋转，不支持玩家缩放。

## 房间外观与 RGB 灯光

墙面、地板各有三套配色，空间灯光提供午后暖阳、清晨冷光和夜间暖灯三种预设。空间预设分别控制主光、补光与落地灯，不改变设备 RGB 设置。

RGB 设置独立于空间灯光：
- **颜色**：冰青、深蓝、紫罗兰、洋红、琥珀、薄荷、玫瑰。
- **亮度**：0–100%；0 会关闭 RGB 发光材质与对应辅助 OmniLight3D。
- **灯效**：常亮、呼吸、彩虹循环。
- **覆盖范围**：桌底灯带、显示器背光，以及已安装进阶型号的机箱、键盘和鼠标灯光。入门型号不会错误显示进阶设备的 RGB 辅助灯。
- **动态部件**：进阶机箱的六枚风扇转子由运行时灯光控制器驱动。

发光材质与实际照明分开控制。RGB 材质使用运行时副本，不会改写导入的 GLB 资源。相关逻辑见 `scripts/life/workstation_lighting.gd`，预设和材质约定见 `docs/WORKSTATION_LIGHTING.md`。

## 场景与素材组织

| 目录 / 文件 | 职责 |
|---|---|
| `scenes/computer/computer_desktop.tscn` | 模式入口、清晰 HUD、桌面系统纹理与应用窗口 |
| `scenes/computer/workstation_3d.tscn` | 主视口 3D 世界、Room、TableGroup、Equipment、灯光、相机、摆放工具、像素滤镜 |
| `scenes/room/room.tscn` | 已保存的房间外壳与五件初始家具实例 |
| `scenes/room/{chair,bookcase,lamp,rug,plant}.tscn` | 每件一个完整 GLB 模型、一个拾取区域；灯包括光源 |
| `assets/models/room/` | 完整房间与家具 GLB，纹理嵌入；无需额外 PNG |
| `scripts/room/pixel_room.gd` | 外观预设、空间灯光、按观察方向隐藏墙 |
| `scripts/life/workstation_lighting.gd` | RGB 发光材质、辅助灯、风扇转子与灯效 |
| `scripts/life/workstation_layout.gd` | 草稿、碰撞、复制、撤销、确认与取消 |
| `scripts/life/workstation_layout_data.gd` | 存档白名单、有限数值检查及凸多边形重叠判定 |
| `tools/models/build_room.py` | 离线模型制作源；Python 3 + Pillow，可重建全部房间 GLB |

初始房间、家具、设备在编辑器中已经存在；游戏不在运行时拼几何。玩家复制时只实例化现成家具场景。设备仍由原有 Blender 模型库导出。

滤镜位于 Workstation3D/PixelPass，使用主视口颜色做最近邻 400 像素高采样和 32 级颜色量化。HUD 位于更高 CanvasLayer，保持清晰；进入电脑屏幕时关闭房间滤镜，游戏平台和购物网页仍以 1280 × 800 显示。Godot 3D 编辑器预览原始网格，运行时才叠加最终像素采样。

## 保存与兼容

继续使用版本 3 存档。\`life.workstation_layout\` 保存原来的五个工作台角色、五类房间家具，以及 \`plant_1\` 这类副本的 \`{x,z,yaw}\`。副本编号仅接受 1–8，不允许复制设备。初始物件相对其原有父节点；副本相对 Room/Furniture。高度与缩放由场景提供。

\`life.room_style\` 保存六项外观设置：wall、floor、light（各为 0–2）、rgb（0–6）、brightness（0–100）和 effect（0–2）。旧存档缺少 RGB 字段时使用默认值：冰青、70% 亮度、常亮。房间配色、空间灯光与 RGB 设置都参与预览、撤销、重做、取消和应用。

装备型号变化导致设备相交时先恢复默认设备摆放并尽量保留桌子；若整套布局仍与墙或新家具冲突，则恢复完整默认房间，避免载入穿模。应用实例和 GameSession 不重建，现有钱包、进度及旧家具库存保持兼容。\`--fresh\` 使用场景默认布局并禁止正常存档写入，适合预览和回归。

## 验证

- `tests/life/test_pixel_room.gd` 覆盖家具模型边界、默认镜头、真实指针拖动、房间与桌子碰撞、地毯、整套跟随、复制/删除/撤销、外观与 RGB UI、灯具副本、取消、磁盘读回、会话恢复、屏幕清晰度模式、墙体遮挡与旧存档校验。
- `tests/life/test_workstation_lighting.gd` 覆盖 RGB 材质发现、六枚风扇转子、实际灯光、颜色/亮度/灯效变化和进阶设备可见性。
- 资源审计、模型 GLB 检查、Godot Headless 回归和图形环境测试由 GitHub Actions 执行；以对应提交的工作流结果作为验证状态，不在文档中硬编码历史测试总数。

```bash
godot --headless --path . --script res://tests/life/test_pixel_room.gd -- --fresh
godot --headless --path . --script res://tests/life/test_workstation_lighting.gd -- --fresh
python tools/project_audit.py
```

![布置房间实际运行画面](previews/pixel_room_layout.png)
