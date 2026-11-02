生活系统、房间与工作台回归

test_life_flow.gd：共享钱包、窗口寿命、直播和攻略收入、设备安装、历史家具数据及存档迁移。
test_workstation_view.gd：原生 3D 主视口、总览旋转缩放、设备点击、3D 射线拾取、屏幕镜头切换、设备安装、屏幕 UV 输入、任务栏与弹窗。
test_workstation_layout.gd：真实鼠标输入、布置手柄、吸附、桌沿、碰撞、设备跟随、应用/取消、存档恢复和编辑中退出。
test_workstation_collision.gd：模型边界、快速拖动防穿透、旋转过程碰撞、接触后移开、变换后的桌面和旧布局恢复。
test_pixel_room.gd：家具模型边界、房间与桌面碰撞、地毯、复制/删除/撤销、配色 UI、灯具副本、取消、磁盘读回、墙体遮挡和旧存档校验。
test_audit_regressions.gd：独立网页预览、屏幕投影、显示器背面输入、截图预览和异常存档数值。

测试使用 --fresh 和独立临时存档，不修改正常玩家进度。*.gd.uid 是 Godot 脚本稳定标识。各脚本的完整命令见根目录 README.md。
test_item_system.gd：物品目录、桌面/地面约束、实例库存、家具多份购买与历史数据迁移。

test_room_placement.gd：房间家具目录、原始家具收回、实时摆放预览、取消/确认、单件改色、存档往返及桌面设备约束。
