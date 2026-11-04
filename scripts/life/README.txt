生活系统、电脑桌面与房间编辑

game_root.gd / game_session.gd：共享会话、游戏时间、商店、游玩、直播和攻略结算。
life_data.gd：玩家数据、能力、默认值和存档校验。
computer_desktop.gd：3D 总览与编辑模式切换、电脑桌面应用、蓝图绘制、设备型号管理。
workstation_3d.gd：相机、总览视角、设备拾取、屏幕 UV 输入和切换。
workstation_layout.gd / workstation_layout_data.gd：布置草稿、库存实例、选择/多选、自由摆放、碰撞、吸附、复制、撤销/重做、提交/取消及保存。
room_minimal_ui.gd / room_scene_actions.gd：装修模式、家具目录和选中物体的上下文工具。
workstation_lighting.gd：电脑硬件 RGB 灯效、材质发光、OmniLight3D、机箱风扇动画。
desktop_device_3d.gd / device_model.gd / hardware_catalog.gd：设备型号与几何映射。
app_window.gd / browser.gd / game_player.gd：应用窗口、购物/库存、游玩界面。

房间相关脚本还包括：
- scripts/room/room_blueprint_data.gd：自由轮廓、墙体、地板、门窗与旧存档迁移。
- scripts/room/room_view.gd 和 modern_room_shell.gd：房间场景、材质和外观。
- scripts/room/furniture_mount_data.gd：桌面和书架陈列物。
- scripts/room/room_wall_mount_data.gd：内外墙画框及壁灯位置、电源、三级亮度、三档色温。

**自由装修规则**：不划分游戏区、工作区或休息区；不创建随区域用途变化的灯光场景。旧 `zone_cells` 的地板配色只在读档时迁移为普通逐格材质。真实内墙或门洞形成的空间连通关系依旧用于建造约束。

旧版房间布局、设备槽位和物品存档的兼容处理继续保留。*.gd.uid 为 Godot 稳定资源 ID，移动或重命名脚本时一并保留。
