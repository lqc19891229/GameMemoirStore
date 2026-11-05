生活玩法、电脑桌面与房间布置脚本

game_root.gd：主入口会话接线。
game_session.gd：唯一模拟时钟；推进下载、游玩、直播和攻略制作等活动。
life_data.gd：生活属性、库存、房间数据和存档规范化/兼容。
computer_desktop.gd：3D 总览、布置、电脑屏幕模式及应用窗口生命周期。
workstation_3d.gd：相机、3D 拾取与显示器 UV 输入。
workstation_lighting.gd：设备 RGB 灯光、风扇等特效。
workstation_layout.gd：家具/设备布置、碰撞、吸附、复制、撤销/重做和应用/取消。
workstation_layout_data.gd：布局数据、边界及碰撞辅助。
browser.gd / game_player.gd：购物库存与游玩 UI。

家具默认外观来自 GLB；旧的按部件材质覆盖及 furniture_materials 字段已从运行时清理。
现存的家具整体改色 furniture_colors 与设备 RGB 灯效是不同功能，仍可正常使用。
旧存档、原有摆放、购买和 UID 映射必须保持兼容。

具体场景见 ../../scenes/README.txt，测试见 ../../tests/life/README.txt。
