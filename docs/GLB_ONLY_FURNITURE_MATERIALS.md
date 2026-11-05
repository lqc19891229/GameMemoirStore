# 家具材质系统清理（GLB 自带材质）

项目改用 GLB 自带的默认材质作为家具的原始外观。

移除：Furniture Material Library 编辑器插件、共享家具材质库、
游戏内按部件选择材质/UV 编辑、家具表面覆盖和对应存档逻辑，
以及 chair_gaming 专用的 MaterialProfile 节点与脚本。

保留：Furniture Manager 家具资源/导入/注册工具、原有整件家具换色、
摆放预览临时透明材质、库存及摆放、模型/UV/法线/碰撞、GLB 自带材质。

当前 chair_gaming.glb 尚未烘焙新 PBR 材质贴图，因此显示的将是
GLB 原本内嵌的材质，外观可能与之前脚本配置版本有所不同。

旧存档的 furniture_materials 数据不再读取、写入。旧家具仍然保留，
只是过去逐部件的自定义材质会失效。furniture_colors 仍然保留。

验证命令：
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/life/test_chair_gaming_uv.gd
godot --headless --path . --script res://tests/life/test_furniture_model_import.gd
godot --headless --path . --script res://tests/life/test_workstation_layout.gd
